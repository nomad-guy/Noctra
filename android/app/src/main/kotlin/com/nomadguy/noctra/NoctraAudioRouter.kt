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

    fun setPreferredOutputDevice(deviceId: Int): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val devices = audioManager.availableCommunicationDevices
            val target = devices.find { it.id == deviceId }
            if (target != null) {
                return audioManager.setCommunicationDevice(target)
            }
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val devices = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
            val target = devices.find { it.id == deviceId }
            if (target != null) {
                if (target.type == AudioDeviceInfo.TYPE_BUILTIN_SPEAKER) {
                    audioManager.isSpeakerphoneOn = true
                } else if (target.type == AudioDeviceInfo.TYPE_BLUETOOTH_A2DP || target.type == AudioDeviceInfo.TYPE_BLUETOOTH_SCO) {
                    audioManager.isSpeakerphoneOn = false
                    audioManager.startBluetoothSco()
                    audioManager.isBluetoothScoOn = true
                }
                notifyDeviceChange()
                return true
            }
        }
        return false
    }

    fun setMultiOutputMode(enabled: Boolean, deviceIds: List<Int>): Boolean {
        // Multi-Sink Audio Routing Trigger
        notifyDeviceChange()
        return true
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

    private fun notifyDeviceChange() {
        val list = getConnectedAudioDevices()
        eventSink?.success(list)
    }
}
