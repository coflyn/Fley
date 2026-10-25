package com.fley

import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.nio.ByteBuffer

object AudioTrimmer {

    fun trimAudio(srcPath: String, destPath: String, startMs: Long, endMs: Long): Boolean {
        val srcFile = File(srcPath)
        val destFile = File(destPath)
        if (!srcFile.exists()) return false

        destFile.parentFile?.mkdirs()

        val lower = srcPath.lowercase()
        return when {
            lower.endsWith(".mp3") -> trimMp3(srcFile, destFile, startMs, endMs)
            lower.endsWith(".m4a") || lower.endsWith(".aac") || lower.endsWith(".mp4") -> trimM4a(srcFile, destFile, startMs, endMs)
            lower.endsWith(".wav") -> trimWav(srcFile, destFile, startMs, endMs)
            else -> {
                try {
                    trimM4a(srcFile, destFile, startMs, endMs)
                } catch (_: Exception) {
                    srcFile.copyTo(destFile, overwrite = true)
                    true
                }
            }
        }
    }

    private fun trimM4a(srcFile: File, destFile: File, startMs: Long, endMs: Long): Boolean {
        val extractor = MediaExtractor()
        var muxer: MediaMuxer? = null
        try {
            extractor.setDataSource(srcFile.absolutePath)
            var trackIndex = -1
            for (i in 0 until extractor.trackCount) {
                val format = extractor.getTrackFormat(i)
                val mime = format.getString(MediaFormat.KEY_MIME) ?: ""
                if (mime.startsWith("audio/")) {
                    trackIndex = i
                    break
                }
            }
            if (trackIndex < 0) return false

            extractor.selectTrack(trackIndex)
            val format = extractor.getTrackFormat(trackIndex)
            
            val startUs = startMs * 1000L
            val endUs = endMs * 1000L
            extractor.seekTo(startUs, MediaExtractor.SEEK_TO_CLOSEST_SYNC)

            muxer = MediaMuxer(destFile.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
            val muxerTrackIndex = muxer.addTrack(format)
            muxer.start()

            val maxBufferSize = if (format.containsKey(MediaFormat.KEY_MAX_INPUT_SIZE)) {
                format.getInteger(MediaFormat.KEY_MAX_INPUT_SIZE).coerceAtLeast(64 * 1024)
            } else {
                256 * 1024
            }
            val buffer = ByteBuffer.allocate(maxBufferSize)
            val bufferInfo = MediaCodec.BufferInfo()

            while (true) {
                bufferInfo.offset = 0
                bufferInfo.size = extractor.readSampleData(buffer, 0)
                if (bufferInfo.size < 0) break

                val sampleTime = extractor.sampleTime
                if (sampleTime > endUs) break

                if (sampleTime >= startUs) {
                    bufferInfo.presentationTimeUs = sampleTime - startUs
                    bufferInfo.flags = extractor.sampleFlags
                    muxer.writeSampleData(muxerTrackIndex, buffer, bufferInfo)
                }
                extractor.advance()
            }
            return true
        } catch (_: Exception) {
            return false
        } finally {
            try { muxer?.stop() } catch (_: Exception) {}
            try { muxer?.release() } catch (_: Exception) {}
            try { extractor.release() } catch (_: Exception) {}
        }
    }

    private val mp3Bitrates = intArrayOf(
        0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320
    )
    private val mp3SampleRates = intArrayOf(
        44100, 48000, 32000
    )

    private fun trimMp3(srcFile: File, destFile: File, startMs: Long, endMs: Long): Boolean {
        return try {
            FileInputStream(srcFile).use { fis ->
                FileOutputStream(destFile).use { fos ->
                    val id3 = ByteArray(10)
                    val readId3 = fis.read(id3)
                    if (readId3 == 10 && id3[0] == 'I'.code.toByte() && id3[1] == 'D'.code.toByte() && id3[2] == '3'.code.toByte()) {
                        val tagSize = ((id3[6].toInt() and 0x7F) shl 21) or
                                ((id3[7].toInt() and 0x7F) shl 14) or
                                ((id3[8].toInt() and 0x7F) shl 7) or
                                (id3[9].toInt() and 0x7F)
                        var skipped = 0L
                        while (skipped < tagSize) {
                            val s = fis.skip(tagSize - skipped)
                            if (s <= 0) break
                            skipped += s
                        }
                    } else {
                        fis.close()
                        return FileInputStream(srcFile).use { fis2 ->
                            parseAndWriteMp3Frames(fis2, fos, startMs, endMs)
                        }
                    }
                    parseAndWriteMp3Frames(fis, fos, startMs, endMs)
                }
            }
        } catch (_: Exception) {
            false
        }
    }

    private fun parseAndWriteMp3Frames(fis: FileInputStream, fos: FileOutputStream, startMs: Long, endMs: Long): Boolean {
        val header = ByteArray(4)
        var currentMs = 0.0
        val frameBuffer = ByteArray(8192)

        while (true) {
            val b = fis.read()
            if (b == -1) break
            if (b != 0xFF) continue

            val b2 = fis.read()
            if (b2 == -1) break
            if ((b2 and 0xE0) != 0xE0) continue

            val b3 = fis.read()
            if (b3 == -1) break
            val b4 = fis.read()
            if (b4 == -1) break

            header[0] = b.toByte()
            header[1] = b2.toByte()
            header[2] = b3.toByte()
            header[3] = b4.toByte()

            val layer = (b2 shr 1) and 0x03
            val bitrateIndex = (b3 shr 4) and 0x0F
            val sampleRateIndex = (b3 shr 2) and 0x03
            val padding = (b3 shr 1) and 0x01

            if (bitrateIndex == 0 || bitrateIndex == 15 || sampleRateIndex >= 3 || layer != 1) {
                continue
            }

            val bitrate = mp3Bitrates[bitrateIndex] * 1000
            val sampleRate = mp3SampleRates[sampleRateIndex]
            val frameSize = (144 * bitrate / sampleRate) + padding
            if (frameSize <= 4 || frameSize > frameBuffer.size) continue

            val restSize = frameSize - 4
            var bytesRead = 0
            while (bytesRead < restSize) {
                val r = fis.read(frameBuffer, bytesRead, restSize - bytesRead)
                if (r == -1) break
                bytesRead += r
            }
            if (bytesRead < restSize) break

            val frameDurationMs = 1152.0 * 1000.0 / sampleRate.toDouble()
            if (currentMs >= startMs && currentMs <= endMs) {
                fos.write(header)
                fos.write(frameBuffer, 0, restSize)
            } else if (currentMs > endMs) {
                break
            }
            currentMs += frameDurationMs
        }
        return true
    }

    private fun trimWav(srcFile: File, destFile: File, startMs: Long, endMs: Long): Boolean {
        return try {
            FileInputStream(srcFile).use { fis ->
                FileOutputStream(destFile).use { fos ->
                    val header = ByteArray(44)
                    if (fis.read(header) != 44) return false

                    val byteRate = ByteBuffer.wrap(header, 28, 4).order(java.nio.ByteOrder.LITTLE_ENDIAN).int
                    if (byteRate <= 0) return false

                    val startByte = (startMs * byteRate / 1000L).coerceAtLeast(0L)
                    val endByte = (endMs * byteRate / 1000L)
                    val targetDataLen = (endByte - startByte).coerceAtLeast(0L).toInt()

                    val buffer4 = ByteBuffer.allocate(4).order(java.nio.ByteOrder.LITTLE_ENDIAN)
                    buffer4.putInt(targetDataLen + 36)
                    System.arraycopy(buffer4.array(), 0, header, 4, 4)

                    val bufferData = ByteBuffer.allocate(4).order(java.nio.ByteOrder.LITTLE_ENDIAN)
                    bufferData.putInt(targetDataLen)
                    System.arraycopy(bufferData.array(), 0, header, 40, 4)

                    fos.write(header)

                    var skipped = 0L
                    while (skipped < startByte) {
                        val s = fis.skip(startByte - skipped)
                        if (s <= 0) break
                        skipped += s
                    }

                    val buf = ByteArray(8192)
                    var written = 0
                    while (written < targetDataLen) {
                        val toRead = (targetDataLen - written).coerceAtMost(buf.size)
                        val r = fis.read(buf, 0, toRead)
                        if (r <= 0) break
                        fos.write(buf, 0, r)
                        written += r
                    }
                    true
                }
            }
        } catch (_: Exception) {
            false
        }
    }
}
