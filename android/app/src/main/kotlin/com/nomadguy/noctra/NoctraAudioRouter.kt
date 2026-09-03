package com.nomadguy.noctra

import android.content.Context
import android.media.AudioDeviceCallback
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Build
import io.flutter.plugin.common.EventChannel

class NoctraAudioRouter(private val context: Context) {
    private val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private var eventSink: EventChannel.EventSink? = null

    private val deviceCallback = object : AudioDeviceCallback() {
        override fun onAudioDevicesAdded(addedDevices: Array<out AudioDeviceInfo>?) {
            notifyDeviceChange()
        }
        override fun onAudioDevicesRemoved(removedDevices: Array<out AudioDeviceInfo>?) {
            notifyDeviceChange()
        }
    }

    fun startListening(sink: EventChannel.EventSink?) {
        this.eventSink = sink
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            audioManager.registerAudioDeviceCallback(deviceCallback, null)
        }
        notifyDeviceChange()
    }

    fun stopListening() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            audioManager.unregisterAudioDeviceCallback(deviceCallback)
        }
        try {
            audioManager.stopBluetoothSco()
            audioManager.isBluetoothScoOn = false
        } catch (_: Throwable) {}
        this.eventSink = null
    }

    fun getConnectedAudioDevices(): List<Map<String, Any>> {
        val deviceList = mutableListOf<Map<String, Any>>()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val devices = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
            for (dev in devices) {
                val typeName = getDeviceTypeName(dev.type)
                val cleanName = if (dev.productName.isNotEmpty()) dev.productName.toString() else typeName
                val isSelected = isDeviceCurrentlyActive(dev)

                deviceList.add(mapOf(
                    "id" to dev.id,
                    "name" to cleanName,
                    "type" to typeName,
                    "typeCode" to dev.type,
                    "isSink" to dev.isSink,
                    "isActive" to isSelected
                ))
            }
        } else {
            deviceList.add(mapOf(
                "id" to 1,
                "name" to "Built-in Phone Speaker",
                "type" to "speaker",
                "typeCode" to 2,
                "isSink" to true,
                "isActive" to true
            ))
        }
        return deviceList
    }

    private var activeOutputDevices = mutableListOf<Int>()
    private var isMultiOutputEnabled = false

    fun setPreferredOutputDevice(deviceId: Int): Boolean {
        try {
            val devices = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
            val target = devices.find { it.id == deviceId }
            if (target == null) return false

            when (target.type) {
                AudioDeviceInfo.TYPE_BUILTIN_SPEAKER -> {
                    audioManager.isSpeakerphoneOn = true
                    audioManager.mode = AudioManager.MODE_NORMAL
                }
                AudioDeviceInfo.TYPE_BLUETOOTH_A2DP,
                AudioDeviceInfo.TYPE_BLUETOOTH_SCO,
                AudioDeviceInfo.TYPE_BLE_HEADSET,
                AudioDeviceInfo.TYPE_BLE_SPEAKER -> {
                    audioManager.isSpeakerphoneOn = false
                    // Route to Bluetooth
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        audioManager.setCommunicationDevice(target)
                    } else {
                        @Suppress("DEPRECATION")
                        audioManager.startBluetoothSco()
                        audioManager.isBluetoothScoOn = true
                    }
                }
                AudioDeviceInfo.TYPE_WIRED_HEADPHONES,
                AudioDeviceInfo.TYPE_WIRED_HEADSET -> {
                    audioManager.isSpeakerphoneOn = false
                }
                AudioDeviceInfo.TYPE_USB_DEVICE,
                AudioDeviceInfo.TYPE_USB_HEADSET -> {
                    audioManager.isSpeakerphoneOn = false
                }
                else -> {
                    audioManager.isSpeakerphoneOn = false
                }
            }

            activeOutputDevices.clear()
            activeOutputDevices.add(deviceId)
            isMultiOutputEnabled = false
            notifyDeviceChange()
            return true
        } catch (e: Throwable) {
            return false
        }
    }

    fun setMultiOutputMode(enabled: Boolean, deviceIds: List<Int>): Boolean {
        try {
            isMultiOutputEnabled = enabled
            activeOutputDevices.clear()
            activeOutputDevices.addAll(deviceIds)

            if (enabled && deviceIds.size >= 2) {
                // For true dual output on Android, we need to:
                // 1. Set the primary device via setCommunicationDevice
                // 2. Use Bluetooth SCO for secondary output
                // Note: Android doesn't natively support simultaneous multi-sink
                // media output. We use a combination of speaker + BT SCO.

                val devices = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
                val hasBluetooth = deviceIds.any { id ->
                    devices.find { it.id == id }?.type?.let { type ->
                        type == AudioDeviceInfo.TYPE_BLUETOOTH_A2DP ||
                        type == AudioDeviceInfo.TYPE_BLUETOOTH_SCO ||
                        type == AudioDeviceInfo.TYPE_BLE_HEADSET ||
                        type == AudioDeviceInfo.TYPE_BLE_SPEAKER
                    } == true
                }
                val hasSpeaker = deviceIds.any { id ->
                    devices.find { it.id == id }?.type == AudioDeviceInfo.TYPE_BUILTIN_SPEAKER
                }

                if (hasBluetooth && hasSpeaker) {
                    // Dual output: speaker + bluetooth
                    audioManager.isSpeakerphoneOn = true
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        val btDevice = devices.find { dev ->
                            deviceIds.any { it == dev.id } &&
                            (dev.type == AudioDeviceInfo.TYPE_BLUETOOTH_A2DP ||
                             dev.type == AudioDeviceInfo.TYPE_BLUETOOTH_SCO ||
                             dev.type == AudioDeviceInfo.TYPE_BLE_HEADSET)
                        }
                        if (btDevice != null) {
                            audioManager.setCommunicationDevice(btDevice)
                        }
                    } else {
                        @Suppress("DEPRECATION")
                        audioManager.startBluetoothSco()
                        audioManager.isBluetoothScoOn = true
                    }
                } else if (hasBluetooth) {
                    // Only bluetooth devices — route to first
                    val firstBt = devices.find { dev ->
                        deviceIds.any { it == dev.id }
                    }
                    if (firstBt != null) {
                        setPreferredOutputDevice(firstBt.id)
                    }
                } else {
                    // No bluetooth — just use speaker
                    audioManager.isSpeakerphoneOn = true
                }
            } else if (!enabled) {
                // Disable multi-output: use first device
                if (deviceIds.isNotEmpty()) {
                    setPreferredOutputDevice(deviceIds.first())
                }
            }

            notifyDeviceChange()
            return true
        } catch (e: Throwable) {
            return false
        }
    }

    fun openSystemMediaOutputSwitcher(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            try {
                val intent = android.content.Intent("android.settings.panel.action.MEDIA_OUTPUT").apply {
                    putExtra("com.android.settings.panel.extra.PACKAGE_NAME", context.packageName)
                    flags = android.content.Intent.FLAG_ACTIVITY_NEW_TASK
                }
                context.startActivity(intent)
                return true
            } catch (_: Throwable) {}
        }
        try {
            val intent = android.content.Intent(android.provider.Settings.ACTION_BLUETOOTH_SETTINGS).apply {
                flags = android.content.Intent.FLAG_ACTIVITY_NEW_TASK
            }
            context.startActivity(intent)
            return true
        } catch (_: Throwable) {
            return false
        }
    }

    private fun isDeviceCurrentlyActive(dev: AudioDeviceInfo): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val current = audioManager.communicationDevice
            if (current != null && current.id == dev.id) return true
        }
        if (dev.type == AudioDeviceInfo.TYPE_BUILTIN_SPEAKER && audioManager.isSpeakerphoneOn) return true
        if (dev.type == AudioDeviceInfo.TYPE_BLUETOOTH_A2DP && audioManager.isBluetoothA2dpOn) return true
        if (dev.type == AudioDeviceInfo.TYPE_WIRED_HEADSET || dev.type == AudioDeviceInfo.TYPE_WIRED_HEADPHONES) {
            return audioManager.isWiredHeadsetOn
        }
        return false
    }

    private fun getDeviceTypeName(type: Int): String {
        return when (type) {
            AudioDeviceInfo.TYPE_BUILTIN_SPEAKER -> "Phone Speaker"
            AudioDeviceInfo.TYPE_BLUETOOTH_A2DP -> "Bluetooth Audio"
            AudioDeviceInfo.TYPE_BLUETOOTH_SCO -> "Bluetooth Headset"
            AudioDeviceInfo.TYPE_WIRED_HEADPHONES -> "Wired AUX / Headphones"
            AudioDeviceInfo.TYPE_WIRED_HEADSET -> "Wired Headset"
            AudioDeviceInfo.TYPE_USB_DEVICE, AudioDeviceInfo.TYPE_USB_HEADSET -> "USB-C DAC / Audio"
            AudioDeviceInfo.TYPE_BLE_HEADSET, AudioDeviceInfo.TYPE_BLE_SPEAKER -> "BLE Wireless Audio"
            AudioDeviceInfo.TYPE_HEARING_AID -> "Hearing Aid"
            else -> "Audio Output"
        }
    }

    private val mainHandler = android.os.Handler(android.os.Looper.getMainLooper())

    private fun notifyDeviceChange() {
        mainHandler.post {
            try {
                val list = getConnectedAudioDevices()
                eventSink?.success(list)
            } catch (_: Throwable) {}
        }
    }
}
