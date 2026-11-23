package com.fley

import android.content.ContentValues
import android.content.Intent
import android.media.RingtoneManager
import android.media.audiofx.AudioEffect
import android.media.audiofx.Equalizer
import android.net.Uri
import android.os.BatteryManager
import android.os.Build
import android.provider.MediaStore
import android.provider.Settings
import androidx.annotation.NonNull
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import android.webkit.WebView

class MainActivity : AudioServiceActivity() {
    private val CHANNEL = "com.fley.audio/equalizer"
    private var equalizer: Equalizer? = null
    private var activeSessionId: Int = 0
    private var pendingLyricsResult: MethodChannel.Result? = null
    private val REQUEST_CODE_PICK_LYRICS = 1001

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "openEqualizer" -> {
                    val sessionId = call.argument<Int>("audioSessionId") ?: 0
                    try {
                        val intent = Intent(AudioEffect.ACTION_DISPLAY_AUDIO_EFFECT_CONTROL_PANEL)
                        intent.putExtra(AudioEffect.EXTRA_PACKAGE_NAME, packageName)
                        if (sessionId != 0) {
                            intent.putExtra(AudioEffect.EXTRA_AUDIO_SESSION, sessionId)
                        }
                        intent.putExtra(AudioEffect.EXTRA_CONTENT_TYPE, AudioEffect.CONTENT_TYPE_MUSIC)
                        
                        startActivityForResult(intent, 999)
                        result.success(true)
                    } catch (e: Exception) {
                        try {
                            val fallbackIntent = Intent(Settings.ACTION_SOUND_SETTINGS)
                            fallbackIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(fallbackIntent)
                            result.success(true)
                        } catch (ex: Exception) {
                            result.error("EQ_ERROR", ex.message, null)
                        }
                    }
                }
                "openAccessibilitySettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ACCESSIBILITY_ERROR", e.message, null)
                    }
                }
                "toggleMonoAudio" -> {
                    val enable = call.argument<Boolean>("enable") ?: false
                    try {
                        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
                            if (Settings.System.canWrite(this)) {
                                val valInt = if (enable) 1 else 0
                                try { Settings.System.putInt(contentResolver, "master_mono", valInt) } catch (_: Exception) {}
                                try { Settings.System.putInt(contentResolver, "mono_audio", valInt) } catch (_: Exception) {}
                                try { Settings.Global.putInt(contentResolver, "master_mono", valInt) } catch (_: Exception) {}
                                result.success(true)
                            } else {
                                try {
                                    val intent = Intent(Settings.ACTION_MANAGE_WRITE_SETTINGS)
                                    intent.data = android.net.Uri.parse("package:$packageName")
                                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                    startActivity(intent)
                                } catch (_: Exception) {
                                    val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                    startActivity(intent)
                                }
                                result.error("PERMISSION_DENIED", "Write settings permission not granted", null)
                            }
                        } else {
                            val valInt = if (enable) 1 else 0
                            try { Settings.System.putInt(contentResolver, "master_mono", valInt) } catch (_: Exception) {}
                            try { Settings.System.putInt(contentResolver, "mono_audio", valInt) } catch (_: Exception) {}
                            result.success(true)
                        }
                    } catch (e: Exception) {
                        result.success(true)
                    }
                }
                "getMonoAudioStatus" -> {
                    try {
                        val isMono = Settings.System.getInt(contentResolver, "master_mono", 0) == 1
                        result.success(isMono)
                    } catch (e: Exception) {
                        result.error("MONO_ERROR", e.message, null)
                    }
                }
                "checkWriteSettingsPermission" -> {
                    try {
                        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
                            result.success(Settings.System.canWrite(this))
                        } else {
                            result.success(true)
                        }
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "getBatteryStatus" -> {
                    try {
                        val batteryStatus: Intent? = registerReceiver(null, android.content.IntentFilter(Intent.ACTION_BATTERY_CHANGED))
                        val level: Int = batteryStatus?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
                        val scale: Int = batteryStatus?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1
                        val status: Int = batteryStatus?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: -1
                        val isCharging = status == BatteryManager.BATTERY_STATUS_CHARGING ||
                                         status == BatteryManager.BATTERY_STATUS_FULL
                        
                        if (level != -1 && scale != -1) {
                            val pct = (level * 100 / scale.toFloat()).toInt()
                            result.success(mapOf("level" to pct, "isCharging" to isCharging))
                        } else {
                            result.success(mapOf("level" to -1, "isCharging" to false))
                        }
                    } catch (e: Exception) {
                        result.error("BATTERY_ERROR", e.message, null)
                    }
                }
                "initEqualizer" -> {
                    val sessionId = call.argument<Int>("audioSessionId") ?: 0
                    try {
                        if (sessionId != 0) {
                            if (equalizer == null || activeSessionId != sessionId) {
                                try {
                                    equalizer?.release()
                                } catch (e: Exception) {}
                                equalizer = try {
                                    Equalizer(0, sessionId)
                                } catch (_: Exception) {
                                    null
                                }
                                activeSessionId = sessionId
                            }
                            
                            val bands = equalizer?.numberOfBands?.toInt() ?: 0
                            val range = equalizer?.bandLevelRange
                            val minLevel = range?.get(0)?.toInt() ?: -1500
                            val maxLevel = range?.get(1)?.toInt() ?: 1500
                            
                            val frequencies = mutableListOf<Int>()
                            val levels = mutableListOf<Int>()
                            for (i in 0 until bands) {
                                frequencies.add((equalizer?.getCenterFreq(i.toShort()) ?: 0) / 1000)
                                levels.add(equalizer?.getBandLevel(i.toShort())?.toInt() ?: 0)
                            }
                            
                            val isEnabled = equalizer?.enabled ?: false
                            result.success(mapOf(
                                "bands" to bands,
                                "minLevel" to minLevel,
                                "maxLevel" to maxLevel,
                                "frequencies" to frequencies,
                                "levels" to levels,
                                "enabled" to isEnabled
                            ))
                        } else {
                            result.error("EQ_ERROR", "Invalid session ID", null)
                        }
                    } catch (e: Exception) {
                        result.error("EQ_INIT_ERROR", e.message, null)
                    }
                }
                "setBandLevel" -> {
                    val band = call.argument<Int>("band") ?: 0
                    val level = call.argument<Int>("level") ?: 0
                    try {
                        equalizer?.setBandLevel(band.toShort(), level.toShort())
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("EQ_SET_ERROR", e.message, null)
                    }
                }
                "setEqualizerEnabled" -> {
                    val enable = call.argument<Boolean>("enable") ?: false
                    try {
                        equalizer?.setEnabled(enable)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("EQ_TOGGLE_ERROR", e.message, null)
                    }
                }
                "pickLyricsFile" -> {
                    try {
                        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "*/*"
                            putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("text/*", "application/octet-stream", "*/*"))
                        }
                        pendingLyricsResult = result
                        startActivityForResult(intent, REQUEST_CODE_PICK_LYRICS)
                    } catch (e: Exception) {
                        result.error("PICK_ERROR", e.message, null)
                    }
                }
                "trimAudio" -> {
                    val srcPath = call.argument<String>("srcPath") ?: ""
                    val destPath = call.argument<String>("destPath") ?: ""
                    val startMs = (call.argument<Number>("startMs")?.toLong() ?: 0L)
                    val endMs = (call.argument<Number>("endMs")?.toLong() ?: 0L)
                    Thread {
                        val success = AudioTrimmer.trimAudio(srcPath, destPath, startMs, endMs)
                        runOnUiThread {
                            result.success(success)
                        }
                    }.start()
                }
                "setAsRingtone" -> {
                    val filePath = call.argument<String>("filePath") ?: ""
                    val title = call.argument<String>("title") ?: "Ringtone"
                    val setAsDefault = call.argument<Boolean>("setAsDefault") ?: true
                    try {
                        if (setAsDefault && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.System.canWrite(this)) {
                            val intent = Intent(Settings.ACTION_MANAGE_WRITE_SETTINGS).apply {
                                data = Uri.parse("package:$packageName")
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            result.success("PERMISSION_REQUIRED")
                            return@setMethodCallHandler
                        }

                        val file = File(filePath)
                        if (!file.exists()) {
                            result.error("FILE_NOT_FOUND", "File not found", null)
                            return@setMethodCallHandler
                        }

                        val mimeType = if (filePath.endsWith(".m4a", true) || filePath.endsWith(".aac", true)) "audio/mp4" else "audio/mpeg"
                        val contentValues = ContentValues().apply {
                            put(MediaStore.Audio.Media.TITLE, title)
                            put(MediaStore.Audio.Media.MIME_TYPE, mimeType)
                            put(MediaStore.Audio.Media.IS_RINGTONE, true)
                            put(MediaStore.Audio.Media.IS_NOTIFICATION, true)
                            put(MediaStore.Audio.Media.IS_ALARM, true)
                            put(MediaStore.Audio.Media.IS_MUSIC, false)
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                                put(MediaStore.Audio.Media.DISPLAY_NAME, file.name)
                                put(MediaStore.Audio.Media.RELATIVE_PATH, "Ringtones/")
                                put(MediaStore.Audio.Media.IS_PENDING, 1)
                            } else {
                                put(MediaStore.MediaColumns.DATA, file.absolutePath)
                            }
                        }

                        val ringtoneCollection = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                            MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
                        } else {
                            MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
                        }

                        try {
                            contentResolver.delete(ringtoneCollection, "${MediaStore.Audio.Media.TITLE}=?", arrayOf(title))
                        } catch (_: Exception) {}

                        val newUri = contentResolver.insert(ringtoneCollection, contentValues)
                        if (newUri != null) {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                                contentResolver.openOutputStream(newUri)?.use { outStream ->
                                    file.inputStream().use { inStream ->
                                        inStream.copyTo(outStream)
                                    }
                                }
                                val updateValues = ContentValues().apply {
                                    put(MediaStore.Audio.Media.IS_PENDING, 0)
                                }
                                contentResolver.update(newUri, updateValues, null, null)
                            }

                            if (setAsDefault) {
                                RingtoneManager.setActualDefaultRingtoneUri(
                                    this,
                                    RingtoneManager.TYPE_RINGTONE,
                                    newUri
                                )
                            }
                            result.success("SUCCESS")
                        } else {
                            result.error("URI_ERROR", "Cannot insert ringtone into MediaStore", null)
                        }
                    } catch (e: Exception) {
                        result.error("RINGTONE_ERROR", e.message, null)
                    }
                }
                "clearWebViewCache" -> {
                    try {
                        runOnUiThread {
                            try {
                                WebView(this).clearCache(true)
                            } catch (_: Exception) {}
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun releaseEqualizer() {
        activeSessionId = 0
        try {
            equalizer?.enabled = false
        } catch (_: Exception) {}
        try {
            equalizer?.release()
        } catch (_: Exception) {}
        equalizer = null
    }

    override fun onDestroy() {
        if (!isChangingConfigurations) {
            releaseEqualizer()
        }
        super.onDestroy()
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_CODE_PICK_LYRICS) {
            if (resultCode == RESULT_OK && data?.data != null) {
                try {
                    val text = contentResolver.openInputStream(data.data!!)?.bufferedReader()?.use { it.readText() }
                    pendingLyricsResult?.success(text ?: "")
                } catch (e: Exception) {
                    pendingLyricsResult?.error("READ_ERROR", e.message, null)
                }
            } else {
                pendingLyricsResult?.success(null)
            }
            pendingLyricsResult = null
        }
    }
}
