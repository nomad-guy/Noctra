package com.nomadguy.noctra

import android.content.Context
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Build
import android.util.Log

/**
 * Helper utilities for NoctraAudioRouter: intent launching, device state queries,
 * and device naming.
 */
object NoctraAudioRouterHelper {
    private const val TAG = "NoctraAudioRouterHelper"

    fun openSystemMediaOutputSwitcher(context: Context): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            try {
                val intent = android.content.Intent(
                    "android.settings.panel.action.MEDIA_OUTPUT"
                ).apply {
                    putExtra(
                        "com.android.settings.panel.extra.PACKAGE_NAME",
                        context.packageName
                    )
                    flags = android.content.Intent.FLAG_ACTIVITY_NEW_TASK
                }
                context.startActivity(intent)
                return true
            } catch (e: Throwable) {
                Log.w(TAG, "Failed to open system media output switcher", e)
            }
        }
        try {
            val intent = android.content.Intent(
                android.provider.Settings.ACTION_BLUETOOTH_SETTINGS
            ).apply {
                flags = android.content.Intent.FLAG_ACTIVITY_NEW_TASK
            }
            context.startActivity(intent)
            return true
        } catch (e: Throwable) {
            Log.w(TAG, "Failed to open Bluetooth settings", e)
            return false
        }
    }

    fun isDeviceCurrentlyActive(audioManager: AudioManager, dev: AudioDeviceInfo): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            try {
                val current = audioManager.communicationDevice
                if (current != null && current.id == dev.id) return true
            } catch (e: Throwable) {
                Log.w(TAG, "communicationDevice lookup failed", e)
            }
        }
        if (dev.type == AudioDeviceInfo.TYPE_BUILTIN_SPEAKER) {
            @Suppress("DEPRECATION")
            if (audioManager.isSpeakerphoneOn) return true
        }
        if (dev.type == AudioDeviceInfo.TYPE_BLUETOOTH_A2DP) {
            @Suppress("DEPRECATION")
            if (audioManager.isBluetoothA2dpOn) return true
        }
        if (dev.type == AudioDeviceInfo.TYPE_WIRED_HEADSET ||
            dev.type == AudioDeviceInfo.TYPE_WIRED_HEADPHONES
        ) {
            @Suppress("DEPRECATION")
            if (audioManager.isWiredHeadsetOn) return true
        }
        return false
    }

    fun getDeviceTypeName(type: Int): String = when (type) {
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
