import 'dart:io';
import 'dart:typed_data';

/// Parser ringan native tanpa dependensi eksternal untuk mengekstrak durasi
/// file audio (MP3, WAV, FLAC, M4A/AAC, OGG) langsung dari header file.
class AudioDurationParser {
  static int? getDurationMs(File file) {
    try {
      final ext = file.path.toLowerCase();
      if (ext.endsWith('.mp3')) {
        return parseMp3(file);
      } else if (ext.endsWith('.wav')) {
        return parseWav(file);
      } else if (ext.endsWith('.flac')) {
        return parseFlac(file);
      } else if (ext.endsWith('.m4a') ||
          ext.endsWith('.aac') ||
          ext.endsWith('.mp4')) {
        return parseM4a(file);
      } else if (ext.endsWith('.ogg')) {
        return parseOgg(file);
      }
    } catch (_) {}
    return null;
  }

  /// Ekstraksi durasi MP3 via Xing/Info header atau estimasi MPEG bitrate
  static int? parseMp3(File file) {
    RandomAccessFile? raf;
    try {
      raf = file.openSync();
      final fileSize = raf.lengthSync();
      if (fileSize < 128) return null;

      final header = Uint8List(10);
      raf.readIntoSync(header, 0, 10);

      int audioStart = 0;
      if (header[0] == 0x49 && header[1] == 0x44 && header[2] == 0x33) {
        final tagSize = ((header[6] & 0x7F) << 21) |
            ((header[7] & 0x7F) << 14) |
            ((header[8] & 0x7F) << 7) |
            (header[9] & 0x7F);
        audioStart = 10 + tagSize;
      }

      if (audioStart >= fileSize) return null;

      raf.setPositionSync(audioStart);
      final buffer = Uint8List(8192);
      final bytesRead = raf.readIntoSync(buffer);
      if (bytesRead < 4) return null;

      for (int i = 0; i < bytesRead - 4; i++) {
        if (buffer[i] == 0xFF && (buffer[i + 1] & 0xE0) == 0xE0) {
          final b1 = buffer[i + 1];
          final b2 = buffer[i + 2];
          final b3 = buffer[i + 3];

          final mpegVersion = (b1 >> 3) & 0x03; // 3 = MPEG-1, 2 = MPEG-2, 0 = MPEG-2.5
          final layer = (b1 >> 1) & 0x03; // 1 = Layer III
          final bitrateIndex = (b2 >> 4) & 0x0F;
          final sampleRateIndex = (b2 >> 2) & 0x03;
          final channelMode = (b3 >> 6) & 0x03;

          if (mpegVersion == 1 ||
              layer == 0 ||
              bitrateIndex == 0 ||
              bitrateIndex == 15 ||
              sampleRateIndex == 3) {
            continue;
          }

          int sampleRate = 44100;
          if (mpegVersion == 3) {
            sampleRate = [44100, 48000, 32000][sampleRateIndex];
          } else if (mpegVersion == 2) {
            sampleRate = [22050, 24000, 16000][sampleRateIndex];
          } else {
            sampleRate = [11025, 12000, 8000][sampleRateIndex];
          }

          final samplesPerFrame = (layer == 1 && mpegVersion != 3) ? 576 : 1152;

          final sideInfoSize = (mpegVersion == 3)
              ? (channelMode == 3 ? 17 : 32)
              : (channelMode == 3 ? 9 : 17);
          final xingOffset = i + 4 + sideInfoSize;

          if (xingOffset + 12 <= bytesRead) {
            final xingSig =
                String.fromCharCodes(buffer.sublist(xingOffset, xingOffset + 4));
            if (xingSig == 'Xing' || xingSig == 'Info') {
              final flags = (buffer[xingOffset + 4] << 24) |
                  (buffer[xingOffset + 5] << 16) |
                  (buffer[xingOffset + 6] << 8) |
                  buffer[xingOffset + 7];
              if ((flags & 0x0001) != 0) {
                final frames = (buffer[xingOffset + 8] << 24) |
                    (buffer[xingOffset + 9] << 16) |
                    (buffer[xingOffset + 10] << 8) |
                    buffer[xingOffset + 11];
                if (frames > 0 && sampleRate > 0) {
                  return (frames * samplesPerFrame * 1000) ~/ sampleRate;
                }
              }
            }
          }

          const mpeg1Layer3Bitrates = [
            0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, 0
          ];
          const mpeg2Layer3Bitrates = [
            0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160, 0
          ];

          final bitrate = (mpegVersion == 3)
              ? mpeg1Layer3Bitrates[bitrateIndex]
              : mpeg2Layer3Bitrates[bitrateIndex];

          if (bitrate > 0) {
            final audioPayloadBytes = fileSize - audioStart;
            return ((audioPayloadBytes * 8 * 1000) ~/ (bitrate * 1000));
          }
        }
      }
    } catch (_) {
    } finally {
      try {
        raf?.closeSync();
      } catch (_) {}
    }
    return null;
  }

  /// Ekstraksi durasi WAV (RIFF Header)
  static int? parseWav(File file) {
    RandomAccessFile? raf;
    try {
      raf = file.openSync();
      final header = Uint8List(128);
      final read = raf.readIntoSync(header);
      if (read < 44) return null;

      if (header[0] == 0x52 &&
          header[1] == 0x49 &&
          header[2] == 0x46 &&
          header[3] == 0x46 &&
          header[8] == 0x57 &&
          header[9] == 0x41 &&
          header[10] == 0x56 &&
          header[11] == 0x45) {
        int byteRate = 0;
        int dataSize = 0;

        // Scan chunk
        int offset = 12;
        while (offset + 8 <= read) {
          final chunkId = String.fromCharCodes(header.sublist(offset, offset + 4));
          final chunkSize = header[offset + 4] |
              (header[offset + 5] << 8) |
              (header[offset + 6] << 16) |
              (header[offset + 7] << 24);

          if (chunkId == 'fmt ' && offset + 16 <= read) {
            byteRate = header[offset + 16] |
                (header[offset + 17] << 8) |
                (header[offset + 18] << 16) |
                (header[offset + 19] << 24);
          } else if (chunkId == 'data') {
            dataSize = chunkSize;
            break;
          }
          offset += 8 + chunkSize;
        }

        if (byteRate > 0) {
          if (dataSize <= 0) {
            dataSize = raf.lengthSync() - offset - 8;
          }
          if (dataSize > 0) {
            return (dataSize * 1000) ~/ byteRate;
          }
        }
      }
    } catch (_) {
    } finally {
      try {
        raf?.closeSync();
      } catch (_) {}
    }
    return null;
  }

  /// Ekstraksi durasi FLAC (STREAMINFO metadata block)
  static int? parseFlac(File file) {
    RandomAccessFile? raf;
    try {
      raf = file.openSync();
      final header = Uint8List(42);
      final read = raf.readIntoSync(header);
      if (read < 42) return null;

      if (header[0] == 0x66 &&
          header[1] == 0x4C &&
          header[2] == 0x61 &&
          header[3] == 0x43) {
        final sampleRate =
            ((header[18] << 12) | (header[19] << 4) | (header[20] >> 4));
        final totalSamples = ((header[21] & 0x0F) << 32) |
            (header[22] << 24) |
            (header[23] << 16) |
            (header[24] << 8) |
            header[25];
        if (sampleRate > 0 && totalSamples > 0) {
          return (totalSamples * 1000) ~/ sampleRate;
        }
      }
    } catch (_) {
    } finally {
      try {
        raf?.closeSync();
      } catch (_) {}
    }
    return null;
  }

  /// Ekstraksi durasi M4A / AAC / MP4 (mvhd atom)
  static int? parseM4a(File file) {
    RandomAccessFile? raf;
    try {
      raf = file.openSync();
      final fileSize = raf.lengthSync();
      int offset = 0;
      final buffer = Uint8List(8);

      while (offset < fileSize && offset < 5000000) {
        raf.setPositionSync(offset);
        if (raf.readIntoSync(buffer, 0, 8) < 8) break;
        final size =
            (buffer[0] << 24) | (buffer[1] << 16) | (buffer[2] << 8) | buffer[3];
        final type = String.fromCharCodes(buffer.sublist(4, 8));

        if (type == 'moov') {
          final moovSize = size > 8 ? size - 8 : 65536;
          final readLen = moovSize > 65536 ? 65536 : moovSize;
          final moovData = Uint8List(readLen);
          final bytesRead = raf.readIntoSync(moovData);

          for (int i = 0; i < bytesRead - 24; i++) {
            if (moovData[i] == 0x6D &&
                moovData[i + 1] == 0x76 &&
                moovData[i + 2] == 0x68 &&
                moovData[i + 3] == 0x64) {
              final mvhdPayload = i + 4;
              final version = moovData[mvhdPayload];
              if (version == 0) {
                final timescale = (moovData[mvhdPayload + 12] << 24) |
                    (moovData[mvhdPayload + 13] << 16) |
                    (moovData[mvhdPayload + 14] << 8) |
                    moovData[mvhdPayload + 15];
                final duration = (moovData[mvhdPayload + 16] << 24) |
                    (moovData[mvhdPayload + 17] << 16) |
                    (moovData[mvhdPayload + 18] << 8) |
                    moovData[mvhdPayload + 19];
                if (timescale > 0 && duration > 0) {
                  return (duration * 1000) ~/ timescale;
                }
              } else if (version == 1) {
                final timescale = (moovData[mvhdPayload + 20] << 24) |
                    (moovData[mvhdPayload + 21] << 16) |
                    (moovData[mvhdPayload + 22] << 8) |
                    moovData[mvhdPayload + 23];
                final duration = (moovData[mvhdPayload + 28] << 24) |
                    (moovData[mvhdPayload + 29] << 16) |
                    (moovData[mvhdPayload + 30] << 8) |
                    moovData[mvhdPayload + 31];
                if (timescale > 0 && duration > 0) {
                  return (duration * 1000) ~/ timescale;
                }
              }
            }
          }
        }

        if (size <= 0) break;
        offset += size;
      }
    } catch (_) {
    } finally {
      try {
        raf?.closeSync();
      } catch (_) {}
    }
    return null;
  }

  /// Ekstraksi durasi Ogg Vorbis/Opus
  static int? parseOgg(File file) {
    RandomAccessFile? raf;
    try {
      raf = file.openSync();
      final fileSize = raf.lengthSync();
      if (fileSize < 500) return null;

      // Baca 8192 bytes terakhir untuk mencari last OggS page
      final readSize = fileSize > 8192 ? 8192 : fileSize;
      raf.setPositionSync(fileSize - readSize);
      final buffer = Uint8List(readSize);
      raf.readIntoSync(buffer);

      for (int i = buffer.length - 14; i >= 0; i--) {
        if (buffer[i] == 0x4F &&
            buffer[i + 1] == 0x67 &&
            buffer[i + 2] == 0x67 &&
            buffer[i + 3] == 0x53) {
          // OggS
          final granulePos = buffer[i + 6] |
              (buffer[i + 7] << 8) |
              (buffer[i + 8] << 16) |
              (buffer[i + 9] << 24) |
              (buffer[i + 10] << 32) |
              (buffer[i + 11] << 40) |
              (buffer[i + 12] << 48) |
              (buffer[i + 13] << 56);
          if (granulePos > 0) {
            // Default sample rate 44100 / 48000
            const sampleRate = 44100;
            return (granulePos * 1000) ~/ sampleRate;
          }
        }
      }
    } catch (_) {
    } finally {
      try {
        raf?.closeSync();
      } catch (_) {}
    }
    return null;
  }
}
