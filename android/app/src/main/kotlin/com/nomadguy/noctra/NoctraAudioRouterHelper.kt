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
        // 1. Try Samsung One UI QuickBoard Media Output
        val samsungActions = listOf(
            "com.samsung.android.mdx.quickboard.action.MEDIA_OUTPUT",
            "com.samsung.android.oneconnect.action.MEDIA_OUTPUT"
        )
        for (action in samsungActions) {
            try {
                val intent = android.content.Intent(action).apply {
                    putExtra("com.android.settings.panel.extra.PACKAGE_NAME", context.packageName)
                    flags = android.content.Intent.FLAG_ACTIVITY_NEW_TASK
                }
                context.startActivity(intent)
                return true
            } catch (_: Throwable) {}
        }

        // 2. Standard AOSP Media Output Switcher (Android 10+)
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

        // 3. Fallback to Bluetooth settings
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
        // 1. Explicit communication device override (Android 12+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            try {
                val current = audioManager.communicationDevice
                if (current != null) {
                    return current.id == dev.id
                }
            } catch (e: Throwable) {
                Log.w(TAG, "communicationDevice lookup failed", e)
            }
        }

        // 2. Speakerphone override flag
        @Suppress("DEPRECATION")
        if (audioManager.isSpeakerphoneOn) {
            return dev.type == AudioDeviceInfo.TYPE_BUILTIN_SPEAKER
        }

        // 3. Bluetooth priority (A2DP / BLE outputs take active precedence on Android)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                val outputs = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
                val hasBt = outputs.any {
                    it.type == AudioDeviceInfo.TYPE_BLUETOOTH_A2DP ||
                    it.type == AudioDeviceInfo.TYPE_BLE_HEADSET ||
                    it.type == AudioDeviceInfo.TYPE_BLE_SPEAKER
                }
                if (hasBt) {
                    return dev.type == AudioDeviceInfo.TYPE_BLUETOOTH_A2DP ||
                           dev.type == AudioDeviceInfo.TYPE_BLE_HEADSET ||
                           dev.type == AudioDeviceInfo.TYPE_BLE_SPEAKER
                }

                // 4. Wired priority
                val hasWired = outputs.any {
                    it.type == AudioDeviceInfo.TYPE_WIRED_HEADSET ||
                    it.type == AudioDeviceInfo.TYPE_WIRED_HEADPHONES ||
                    it.type == AudioDeviceInfo.TYPE_USB_HEADSET ||
                    it.type == AudioDeviceInfo.TYPE_USB_DEVICE
                }
                if (hasWired) {
                    return dev.type == AudioDeviceInfo.TYPE_WIRED_HEADSET ||
                           dev.type == AudioDeviceInfo.TYPE_WIRED_HEADPHONES ||
                           dev.type == AudioDeviceInfo.TYPE_USB_HEADSET ||
                           dev.type == AudioDeviceInfo.TYPE_USB_DEVICE
                }
            } catch (_: Throwable) {}
        }

        // 5. Default fallback: Built-in Phone Speaker
        return dev.type == AudioDeviceInfo.TYPE_BUILTIN_SPEAKER
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
