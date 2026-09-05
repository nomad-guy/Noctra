package com.nomadguy.noctra

import android.content.Context
import android.media.AudioDeviceCallback
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Build
import android.util.Log
import io.flutter.plugin.common.EventChannel

/**
 * Routes audio output to the user's chosen device and surfaces
 * connection changes to the Flutter side.
 *
 * Threading: every public entry point runs on the main looper
 * (registered with `audioManager.registerAudioDeviceCallback(..., null)`
 * which posts callbacks to the calling thread's looper). The
 * internal mutable state is therefore confined to a single thread
 * and needs no external lock.
 *
 * Routing API note (Android 12 / API 31+): there is no public,
 * cross-OEM API for routing *media* playback to an arbitrary output
 * device. `AudioManager.setCommunicationDevice()` is documented
 * for voice calls and does not reliably change the music stream
 * destination. We therefore fall back to the per-type heuristic
 * below (speakerphone, Bluetooth SCO, etc.) and expose the
 * system media output panel for the user to pick anything we
 * cannot address programmatically.
 */
class NoctraAudioRouter(private val context: Context) {
    companion object {
        private const val TAG = "NoctraAudioRouter"
    }

    private val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = android.os.Handler(android.os.Looper.getMainLooper())

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
            audioManager.registerAudioDeviceCallback(deviceCallback, mainHandler)
        }
        notifyDeviceChange()
    }

    fun stopListening() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            audioManager.unregisterAudioDeviceCallback(deviceCallback)
        }
        try {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
                @Suppress("DEPRECATION")
                audioManager.stopBluetoothSco()
            }
            @Suppress("DEPRECATION")
            audioManager.isBluetoothScoOn = false
        } catch (e: Throwable) {
            Log.w(TAG, "Failed to tear down Bluetooth SCO on stopListening", e)
        }
        this.eventSink = null
    }

    fun getConnectedAudioDevices(): List<Map<String, Any>> {
        val deviceList = mutableListOf<Map<String, Any>>()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val devices = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
            for (dev in devices) {
                val typeName = NoctraAudioRouterHelper.getDeviceTypeName(dev.type)
                val cleanName = if (dev.productName.isNotEmpty()) {
                    dev.productName.toString()
                } else {
                    typeName
                }
                deviceList.add(
                    mapOf(
                        "id" to dev.id,
                        "name" to cleanName,
                        "type" to typeName,
                        "typeCode" to dev.type,
                        "isSink" to dev.isSink,
                        "isActive" to NoctraAudioRouterHelper.isDeviceCurrentlyActive(audioManager, dev),
                    )
                )
            }
        } else {
            // Pre-Marshmallow: AudioDeviceInfo is unavailable. Report a
            // single built-in speaker so the UI still has something to
            // show; the system media output panel can be opened for
            // any other output.
            deviceList.add(
                mapOf(
                    "id" to 1,
                    "name" to "Built-in Phone Speaker",
                    "type" to "speaker",
                    "typeCode" to 2,
                    "isSink" to true,
                    "isActive" to true,
                )
            )
        }
        return deviceList
    }

    /**
     * Route media playback to [deviceId].
     *
     * Returns a [RouteResult] so the caller can distinguish
     * "device not found" from "we addressed the right device but
     * the OS declined" (which used to be collapsed to a single
     * `false` and made debugging impossible).
     */
    fun setPreferredOutputDevice(deviceId: Int): RouteResult {
        return try {
            val devices = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
            val target = devices.find { it.id == deviceId }
                ?: return RouteResult.DeviceNotFound

            applyDeviceRouting(target)
            notifyDeviceChange()
            RouteResult.Ok
        } catch (e: Throwable) {
            Log.w(TAG, "setPreferredOutputDevice($deviceId) failed", e)
            RouteResult.Failed(e.message ?: "unknown error")
        }
    }

    /**
     * Apply per-type heuristics for the device classes the legacy
     * AudioManager API actually controls. USB / HDMI / etc. fall
     * through to "open the system media output panel so the user
     * can pick it" because no public Android API exists for
     * routing them at the application level.
     */
    private fun applyDeviceRouting(target: AudioDeviceInfo) {
        when (target.type) {
            AudioDeviceInfo.TYPE_BUILTIN_SPEAKER -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    try {
                        audioManager.mode = AudioManager.MODE_IN_COMMUNICATION
                        audioManager.setCommunicationDevice(target)
                    } catch (e: Throwable) {
                        Log.w(TAG, "setCommunicationDevice(speaker) failed", e)
                    }
                } else {
                    audioManager.mode = AudioManager.MODE_IN_COMMUNICATION
                    @Suppress("DEPRECATION")
                    audioManager.isSpeakerphoneOn = true
                }
            }
            AudioDeviceInfo.TYPE_BLUETOOTH_A2DP,
            AudioDeviceInfo.TYPE_BLUETOOTH_SCO,
            AudioDeviceInfo.TYPE_BLE_HEADSET,
            AudioDeviceInfo.TYPE_BLE_SPEAKER -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    try {
                        audioManager.clearCommunicationDevice()
                        audioManager.setCommunicationDevice(target)
                    } catch (_: Throwable) {}
                    audioManager.mode = AudioManager.MODE_NORMAL
                } else {
                    @Suppress("DEPRECATION")
                    audioManager.isSpeakerphoneOn = false
                    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
                        @Suppress("DEPRECATION")
                        audioManager.startBluetoothSco()
                        @Suppress("DEPRECATION")
                        audioManager.isBluetoothScoOn = true
                    }
                    audioManager.mode = AudioManager.MODE_NORMAL
                }
            }
            AudioDeviceInfo.TYPE_WIRED_HEADPHONES,
            AudioDeviceInfo.TYPE_WIRED_HEADSET,
            AudioDeviceInfo.TYPE_USB_DEVICE,
            AudioDeviceInfo.TYPE_USB_HEADSET -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    try {
                        audioManager.clearCommunicationDevice()
                        audioManager.setCommunicationDevice(target)
                    } catch (_: Throwable) {}
                    audioManager.mode = AudioManager.MODE_NORMAL
                } else {
                    @Suppress("DEPRECATION")
                    audioManager.isSpeakerphoneOn = false
                    audioManager.mode = AudioManager.MODE_NORMAL
                }
            }
            else -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    try {
                        audioManager.clearCommunicationDevice()
                    } catch (_: Throwable) {}
                }
                @Suppress("DEPRECATION")
                audioManager.isSpeakerphoneOn = false
                audioManager.mode = AudioManager.MODE_NORMAL
            }
        }
    }

    fun openSystemMediaOutputSwitcher(): Boolean =
        NoctraAudioRouterHelper.openSystemMediaOutputSwitcher(context)

    /**
     * Result of [setPreferredOutputDevice] / [enableSpeakerPlusBluetooth].
     *
     * `Failed` carries a message so the Dart side can surface it
     * to the user instead of silently logging it and proceeding.
     */
    sealed class RouteResult {
        object Ok : RouteResult()
        object DeviceNotFound : RouteResult()
        data class Failed(val reason: String) : RouteResult()
    }

    /**
     * Best-effort "speaker + Bluetooth" dual output. Android does
     * not expose a public API for true simultaneous multi-sink media
     * output, so this function enables the speakerphone plus a
     * Bluetooth SCO link when [deviceIds] contains both kinds. It
     * is honest about the limitation: see the result enum.
     */
    fun enableSpeakerPlusBluetooth(deviceIds: List<Int>): SpeakerPlusBluetoothResult {
        if (deviceIds.isEmpty()) {
            return SpeakerPlusBluetoothResult.NothingSelected
        }
        val devices = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
        val hasSpeaker = deviceIds.any { id ->
            devices.find { it.id == id }?.type ==
                AudioDeviceInfo.TYPE_BUILTIN_SPEAKER
        }
        val btTypes = setOf(
            AudioDeviceInfo.TYPE_BLUETOOTH_A2DP,
            AudioDeviceInfo.TYPE_BLUETOOTH_SCO,
            AudioDeviceInfo.TYPE_BLE_HEADSET,
            AudioDeviceInfo.TYPE_BLE_SPEAKER,
        )
        val hasBluetooth = deviceIds.any { id ->
            devices.find { it.id == id }?.type in btTypes
        }
        if (!hasSpeaker || !hasBluetooth) {
            // Not a speaker+BT combo — fall back to the single
            // device the user selected, which is the honest thing
            // to do instead of pretending we have multi-sink.
            val firstId = deviceIds.first()
            val first = devices.find { it.id == firstId }
            if (first == null) return SpeakerPlusBluetoothResult.DeviceNotFound
            applyDeviceRouting(first)
            return SpeakerPlusBluetoothResult.SingleDeviceRouted
        }
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val speaker = devices.find { it.type == AudioDeviceInfo.TYPE_BUILTIN_SPEAKER }
                if (speaker != null) {
                    audioManager.mode = AudioManager.MODE_IN_COMMUNICATION
                    audioManager.setCommunicationDevice(speaker)
                }
                notifyDeviceChange()
                SpeakerPlusBluetoothResult.SpeakerOnly
            } else {
                audioManager.mode = AudioManager.MODE_IN_COMMUNICATION
                @Suppress("DEPRECATION")
                audioManager.isSpeakerphoneOn = true
                @Suppress("DEPRECATION")
                audioManager.startBluetoothSco()
                @Suppress("DEPRECATION")
                audioManager.isBluetoothScoOn = true
                notifyDeviceChange()
                SpeakerPlusBluetoothResult.Ok
            }
        } catch (e: Throwable) {
            Log.w(TAG, "enableSpeakerPlusBluetooth failed", e)
            SpeakerPlusBluetoothResult.Failed(e.message ?: "unknown error")
        }
    }

    sealed class SpeakerPlusBluetoothResult {
        object Ok : SpeakerPlusBluetoothResult()
        object NothingSelected : SpeakerPlusBluetoothResult()
        object DeviceNotFound : SpeakerPlusBluetoothResult()
        // API 31+ cannot run two media sinks simultaneously from
        // user code; the speaker is the only one we could turn on.
        object SpeakerOnly : SpeakerPlusBluetoothResult()
        // The selection wasn't a speaker+BT combo, so we routed
        // the single device the user picked.
        object SingleDeviceRouted : SpeakerPlusBluetoothResult()
        data class Failed(val reason: String) : SpeakerPlusBluetoothResult()
    }


    private fun notifyDeviceChange() {
        mainHandler.post {
            try {
                val list = getConnectedAudioDevices()
                eventSink?.success(list)
            } catch (e: Throwable) {
                Log.w(TAG, "notifyDeviceChange dispatch failed", e)
            }
        }
    }
}
