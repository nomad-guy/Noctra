package com.nomadguy.noctra

/**
 * Result outcomes for speaker + Bluetooth simultaneous playback routing.
 */
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
