package com.nomadguy.noctra

import android.content.Context
import android.content.pm.PackageManager
import android.util.Log

/**
 * Manages the Android launcher icon by toggling activity-aliases.
 *
 * Invariant enforced after every completed operation:
 *   After every completed operation, exactly one launcher alias is enabled.
 *
 * Android PackageManager is the single source of truth.
 * All operations are serialized via the caller's iconExecutor.
 */
class LauncherIconManager(private val context: Context) {

    companion object {
        private const val TAG = "LauncherIconManager"
        private const val PREFS_NAME = "noctra_icon"
        private const val PREFS_KEY = "selected_icon"
    }

    private val pkg = context.packageName

    /** All launcher aliases — exactly one should be enabled after any completed operation. */
    private val aliases = mapOf(
        "default" to "$pkg.MainActivity.default",
        "noir_black" to "$pkg.MainActivity.noir_black",
        "noir_white" to "$pkg.MainActivity.noir_white",
        "liquid_glass" to "$pkg.MainActivity.liquid_glass",
    )

    private val stateHelper = LauncherIconStateHelper(context, aliases)

    private fun recoverToDefault(): String? {
        Log.w(TAG, "Last-resort: recovering to default icon")
        val result = stateHelper.applyState("default")
        if (result.isFailure) {
            Log.e(TAG, "CRITICAL: recoverToDefault apply failed", result.exceptionOrNull())
            return null
        }

        val verifyResult = stateHelper.verifyExactlyOneEnabled()
        if (verifyResult.isFailure) {
            Log.e(TAG, "CRITICAL: recoverToDefault verification read failed", verifyResult.exceptionOrNull())
            return null
        }

        val (ok, enabledKey) = verifyResult.getOrThrow()
        return if (ok && enabledKey == "default") {
            persistIcon("default")
            "default"
        } else {
            Log.e(TAG, "CRITICAL: recoverToDefault verification failed (enabled=$enabledKey)")
            null
        }
    }

    private fun persistIcon(iconKey: String) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit().putString(PREFS_KEY, iconKey).apply()
    }

    fun reconcileAndGetCurrentIcon(): Result<String> {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        var saved = prefs.getString(PREFS_KEY, "default") ?: "default"

        if (!aliases.containsKey(saved)) {
            Log.w(TAG, "Unknown saved icon '$saved' — will establish default")
            saved = "default"
        }

        val snapshotResult = stateHelper.captureState()
        if (snapshotResult.isFailure) {
            Log.e(TAG, "Cannot capture state at all — attempting blind recovery")
            val recovered = recoverToDefault()
            return if (recovered != null) {
                Result.success(recovered)
            } else {
                Result.failure(IllegalStateException("ICON_STATE_UNRECOVERABLE: cannot read PackageManager"))
            }
        }
        val snapshot = snapshotResult.getOrThrow()

        val verifyResult = stateHelper.verifyExactlyOneEnabled()
        if (verifyResult.isFailure) {
            Log.e(TAG, "Cannot verify aliases — attempting recovery")
            val recovered = recoverToDefault()
            return if (recovered != null) Result.success(recovered)
            else Result.failure(IllegalStateException("ICON_STATE_UNRECOVERABLE: cannot verify state"))
        }

        val (ok, enabledKey) = verifyResult.getOrThrow()
        if (ok && enabledKey == saved) {
            if (!prefs.contains(PREFS_KEY) || prefs.getString(PREFS_KEY, null) != saved) {
                persistIcon(saved)
            }
            Log.i(TAG, "Icon state consistent: $saved")
            return Result.success(saved)
        }

        Log.i(TAG, "Icon state inconsistent (enabled=$enabledKey, saved=$saved) — repairing")

        val applyResult = stateHelper.applyState(saved)
        if (applyResult.isFailure) {
            Log.e(TAG, "Repair apply failed — restoring snapshot", applyResult.exceptionOrNull())
            stateHelper.restoreState(snapshot)

            return if (stateHelper.verifyStateEquals(snapshot)) {
                if (stateHelper.isValidSnapshot(snapshot)) {
                    val restoredKey = snapshot.entries.find { it.value == PackageManager.COMPONENT_ENABLED_STATE_ENABLED }?.key
                    Log.i(TAG, "Snapshot rollback succeeded (valid state): $restoredKey")
                    persistIcon(restoredKey ?: "default")
                    Result.success(restoredKey ?: "default")
                } else {
                    Log.w(TAG, "Snapshot was invalid — recovering to default")
                    val recovered = recoverToDefault()
                    if (recovered != null) Result.success(recovered)
                    else Result.failure(IllegalStateException("ICON_STATE_UNRECOVERABLE: invalid snapshot, recovery failed"))
                }
            } else {
                Log.e(TAG, "Snapshot rollback verification failed")
                val recovered = recoverToDefault()
                if (recovered != null) Result.success(recovered)
                else Result.failure(IllegalStateException("ICON_STATE_UNRECOVERABLE: repair, rollback, and recovery all failed"))
            }
        }

        val postRepairResult = stateHelper.verifyExactlyOneEnabled()
        if (postRepairResult.isSuccess && postRepairResult.getOrThrow().first && postRepairResult.getOrThrow().second == saved) {
            persistIcon(saved)
            Log.i(TAG, "Repaired launcher icon to: $saved")
            return Result.success(saved)
        }

        Log.e(TAG, "Repair verification failed — restoring snapshot")
        stateHelper.restoreState(snapshot)

        return if (stateHelper.verifyStateEquals(snapshot)) {
            if (stateHelper.isValidSnapshot(snapshot)) {
                val restoredKey = snapshot.entries.find { it.value == PackageManager.COMPONENT_ENABLED_STATE_ENABLED }?.key
                Log.i(TAG, "Snapshot rollback succeeded (valid state): $restoredKey")
                persistIcon(restoredKey ?: "default")
                Result.success(restoredKey ?: "default")
            } else {
                Log.w(TAG, "Snapshot was invalid — recovering to default")
                val recovered = recoverToDefault()
                if (recovered != null) Result.success(recovered)
                else Result.failure(IllegalStateException("ICON_STATE_UNRECOVERABLE: invalid snapshot, recovery failed"))
            }
        } else {
            Log.e(TAG, "Snapshot rollback verification failed — recovering to default")
            val recovered = recoverToDefault()
            if (recovered != null) Result.success(recovered)
            else Result.failure(IllegalStateException("ICON_STATE_UNRECOVERABLE: all recovery attempts failed"))
        }
    }

    fun setIcon(iconKey: String): Result<Unit> {
        val targetAlias = aliases[iconKey]
            ?: return Result.failure(IllegalArgumentException("Unknown icon: $iconKey"))

        val snapshotResult = stateHelper.captureState()
        if (snapshotResult.isFailure) {
            Log.e(TAG, "Cannot capture state — aborting setIcon (no mutation)")
            return Result.failure(IllegalStateException("Cannot read current icon state", snapshotResult.exceptionOrNull()))
        }
        val snapshot = snapshotResult.getOrThrow()

        val applyResult = stateHelper.applyState(iconKey)
        if (applyResult.isFailure) {
            Log.e(TAG, "Apply failed — restoring snapshot", applyResult.exceptionOrNull())
            return restoreAndVerify(snapshot, iconKey)
        }

        val verifyResult = stateHelper.verifyExactlyOneEnabled()
        if (verifyResult.isFailure || !verifyResult.getOrThrow().first || verifyResult.getOrThrow().second != iconKey) {
            Log.w(TAG, "Verification failed (result=$verifyResult) — restoring snapshot")
            return restoreAndVerify(snapshot, iconKey)
        }

        persistIcon(iconKey)
        Log.i(TAG, "Launcher icon switched to: $iconKey")
        return Result.success(Unit)
    }

    private fun restoreAndVerify(snapshot: Map<String, Int>, attemptedIcon: String): Result<Unit> {
        stateHelper.restoreState(snapshot)

        if (!stateHelper.verifyStateEquals(snapshot)) {
            Log.e(TAG, "Snapshot restoration failed — recovering to default")
            val recovered = recoverToDefault()
            return if (recovered != null) {
                Result.failure(IllegalStateException("Icon switch to $attemptedIcon failed, recovered to default"))
            } else {
                Result.failure(IllegalStateException("ICON_STATE_UNRECOVERABLE: snapshot restore and recovery both failed"))
            }
        }

        if (stateHelper.isValidSnapshot(snapshot)) {
            val restoredKey = snapshot.entries.find { it.value == PackageManager.COMPONENT_ENABLED_STATE_ENABLED }?.key
            Log.i(TAG, "Snapshot rollback succeeded (valid state): $restoredKey")
            persistIcon(restoredKey ?: "default")
            return Result.failure(IllegalStateException("Icon switch to $attemptedIcon failed, restored to $restoredKey"))
        }

        Log.w(TAG, "Snapshot was itself invalid — recovering to default")
        val recovered = recoverToDefault()
        return if (recovered != null) {
            Result.failure(IllegalStateException("Icon switch to $attemptedIcon failed, snapshot invalid, recovered to default"))
        } else {
            Result.failure(IllegalStateException("ICON_STATE_UNRECOVERABLE: invalid snapshot and recovery failed"))
        }
    }
}
