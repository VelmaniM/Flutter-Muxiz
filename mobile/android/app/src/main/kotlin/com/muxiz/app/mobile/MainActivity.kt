package com.muxiz.app.mobile

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioDeviceCallback
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Build
import android.provider.Settings
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    private val CHANNEL = "com.muxiz.app/audio_route"
    private var methodChannel: MethodChannel? = null
    private var audioManager: AudioManager? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getAvailableRoutes" -> {
                    result.success(fetchAudioRoutes())
                }
                "selectRoute" -> {
                    val id = call.argument<String>("id")
                    val type = call.argument<String>("type")
                    val success = routeAudio(id, type)
                    result.success(success)
                }
                "showSystemRoutePicker" -> {
                    openSystemRoutePicker()
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        registerRouteListeners()
    }

    private fun registerRouteListeners() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            audioManager?.registerAudioDeviceCallback(object : AudioDeviceCallback() {
                override fun onAudioDevicesAdded(addedDevices: Array<out AudioDeviceInfo>?) {
                    notifyRouteChanged()
                }

                override fun onAudioDevicesRemoved(removedDevices: Array<out AudioDeviceInfo>?) {
                    notifyRouteChanged()
                }
            }, null)
        }

        val filter = IntentFilter().apply {
            addAction(AudioManager.ACTION_AUDIO_BECOMING_NOISY)
            addAction(AudioManager.ACTION_HEADSET_PLUG)
        }
        registerReceiver(object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                notifyRouteChanged()
            }
        }, filter)
    }

    private fun notifyRouteChanged() {
        runOnUiThread {
            methodChannel?.invokeMethod("onRouteChange", fetchAudioRoutes())
        }
    }

    private fun fetchAudioRoutes(): Map<String, Any> {
        val am = audioManager ?: return emptyMap()
        val routesMap = mutableMapOf<String, Map<String, Any>>()

        // 1. Built-in Speaker (Always available)
        val isSpeakerOn = am.isSpeakerphoneOn
        val speakerRoute = mapOf(
            "id" to "speaker",
            "name" to "Phone Speaker",
            "type" to "speaker",
            "isSelected" to isSpeakerOn,
            "isAvailable" to true
        )
        routesMap["speaker"] = speakerRoute

        var activeId = if (isSpeakerOn) "speaker" else "speaker"
        var activeName = if (isSpeakerOn) "Phone Speaker" else "Phone Speaker"
        var activeType = "speaker"

        // 2. Query hardware audio output devices on Android 6.0+ (API 23+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val devices = am.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
            for (device in devices) {
                val devType = mapDeviceType(device.type)
                val isSelected = !isSpeakerOn && (devType != "speaker")
                val devId = "device_${device.id}"
                val devName = if (device.productName.isNotEmpty()) device.productName.toString() else "Audio Device"

                if (isSelected) {
                    activeId = devId
                    activeName = devName
                    activeType = devType
                }

                routesMap[devId] = mapOf(
                    "id" to devId,
                    "name" to devName,
                    "type" to devType,
                    "isSelected" to isSelected,
                    "isAvailable" to true
                )
            }
        }

        val currentRoute = mapOf(
            "id" to activeId,
            "name" to activeName,
            "type" to activeType,
            "isSelected" to true,
            "isAvailable" to true
        )

        return mapOf(
            "currentRoute" to currentRoute,
            "availableRoutes" to routesMap.values.toList()
        )
    }

    private fun mapDeviceType(type: Int): String {
        return when (type) {
            AudioDeviceInfo.TYPE_BUILTIN_SPEAKER, AudioDeviceInfo.TYPE_BUILTIN_EARPIECE -> "speaker"
            AudioDeviceInfo.TYPE_BLUETOOTH_A2DP, AudioDeviceInfo.TYPE_BLUETOOTH_SCO, AudioDeviceInfo.TYPE_BLE_HEADSET, AudioDeviceInfo.TYPE_BLE_SPEAKER -> "bluetooth"
            AudioDeviceInfo.TYPE_WIRED_HEADPHONES, AudioDeviceInfo.TYPE_WIRED_HEADSET -> "headphones"
            AudioDeviceInfo.TYPE_USB_DEVICE, AudioDeviceInfo.TYPE_USB_HEADSET -> "usb"
            AudioDeviceInfo.TYPE_AUX_LINE -> "car"
            else -> "bluetooth"
        }
    }

    private fun routeAudio(id: String?, type: String?): Boolean {
        val am = audioManager ?: return false
        return try {
            if (type == "speaker") {
                am.isSpeakerphoneOn = true
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    am.clearCommunicationDevice()
                }
            } else {
                am.isSpeakerphoneOn = false
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    val devices = am.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
                    val targetDevice = devices.firstOrNull { 
                        it.type == AudioDeviceInfo.TYPE_BLUETOOTH_A2DP || 
                        it.type == AudioDeviceInfo.TYPE_BLE_HEADSET ||
                        it.type == AudioDeviceInfo.TYPE_WIRED_HEADSET
                    }
                    if (targetDevice != null) {
                        am.setCommunicationDevice(targetDevice)
                    }
                }
            }
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun openSystemRoutePicker() {
        try {
            val intent = Intent(Settings.ACTION_SOUND_SETTINGS).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            startActivity(intent)
        } catch (_: Exception) {}
    }
}
