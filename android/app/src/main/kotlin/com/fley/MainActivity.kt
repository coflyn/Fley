package com.fley

import android.content.Intent
import android.media.audiofx.AudioEffect
import android.media.audiofx.Equalizer
import android.os.BatteryManager
import android.provider.Settings
import androidx.annotation.NonNull
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    private val CHANNEL = "com.fley.audio/equalizer"
    private var equalizer: Equalizer? = null
    private var activeSessionId: Int = 0

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
                                equalizer = Equalizer(0, sessionId)
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
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
