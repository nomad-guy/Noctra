package com.nomadguy.noctra

import android.content.ComponentName
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
 *
 * Three clean primitives:
 *   captureState()  → read current alias states
 *   applyState(target) → enable target, disable all others
 *   verifyState(snapshot) → confirm the current state matches a snapshot
 *
 * All public operations compose these primitives transactionally.
 */
class LauncherIconManager(private val context: Context) {

    companion object {
        private const val TAG = "LauncherIconManager"
        private const val PREFS_NAME = "noctra_icon"
        private const val PREFS_KEY = "selected_icon"
    }

    private val pm = context.packageManager
    private val pkg = context.packageName

    /** All launcher aliases — exactly one should be enabled after any completed operation. */
    private val aliases = mapOf(
        "default" to "$pkg.MainActivity.default",
        "noir_black" to "$pkg.MainActivity.noir_black",
        "noir_white" to "$pkg.MainActivity.noir_white",
        "liquid_glass" to "$pkg.MainActivity.liquid_glass",
    )

    // ---- Three clean primitives ----

    /**
     * PRIMITIVE 1: Capture the current enabled/disabled state of all aliases.
     * Returns a Result to surface PackageManager read errors.
     */
    private fun captureState(): Result<Map<String, Int>> {
        return try {
            val state = mutableMapOf<String, Int>()
            for ((key, alias) in aliases) {
                state[key] = pm.getComponentEnabledSetting(ComponentName(pkg, alias))
            }
            Result.success(state)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to capture alias state", e)
            Result.failure(e)
        }
    }

    /**
     * PRIMITIVE 2: Apply a target icon state — enable target, disable all others.
     * Uses explicit ENABLED/DISABLED everywhere.
     */
    private fun applyState(targetKey: String): Result<Unit> {
        val targetAlias = aliases[targetKey]
            ?: return Result.failure(IllegalArgumentException("Unknown icon: $targetKey"))

        return try {
            // Enable target FIRST — so there's always at least one launcher entry
            pm.setComponentEnabledSetting(
                ComponentName(pkg, targetAlias),
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                PackageManager.DONT_KILL_APP
            )
            // Disable all others explicitly
            for ((key, alias) in aliases) {
                if (key == targetKey) continue
                pm.setComponentEnabledSetting(
                    ComponentName(pkg, alias),
                    PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                    PackageManager.DONT_KILL_APP
                )
            }
            Result.success(Unit)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to apply state for: $targetKey", e)
            Result.failure(e)
        }
    }

    /**
     * PRIMITIVE 3: Verify that the current state matches the given snapshot exactly.
     * Every alias must be in the same state as in the snapshot.
     */
    private fun verifyStateEquals(snapshot: Map<String, Int>): Boolean {
        for ((key, alias) in aliases) {
            val expected = snapshot[key] ?: return false
            try {
                val actual = pm.getComponentEnabledSetting(ComponentName(pkg, alias))
                if (actual != expected) return false
            } catch (e: Exception) {
                Log.e(TAG, "Failed to verify alias $key", e)
                return false
            }
        }
        return true
    }

    /**
     * Verify that exactly one alias is enabled and it is the target.
     */
    private fun verifyExactlyOneEnabled(): Result<Pair<Boolean, String?>> {
        return try {
            val enabledAliases = aliases.entries.filter { (_, alias) ->
                pm.getComponentEnabledSetting(ComponentName(pkg, alias)) ==
                    PackageManager.COMPONENT_ENABLED_STATE_ENABLED
            }
            Result.success(Pair(enabledAliases.size == 1, enabledAliases.firstOrNull()?.key))
        } catch (e: Exception) {
            Log.e(TAG, "Failed to verify enabled aliases", e)
            Result.failure(e)
        }
    }

    // ---- Recovery ----

    /**
     * Last-resort recovery: force default alias enabled, all others disabled.
     * ONLY persists after successfully establishing the state in PackageManager.
     * Returns the icon key that is actually enabled, or null if recovery failed.
     */
    private fun recoverToDefault(): String? {
        Log.w(TAG, "Last-resort: recovering to default icon")
        val result = applyState("default")
        if (result.isFailure) {
            Log.e(TAG, "CRITICAL: recoverToDefault apply failed", result.exceptionOrNull())
            return null
        }

        val verifyResult = verifyExactlyOneEnabled()
        if (verifyResult.isFailure) {
            Log.e(TAG, "CRITICAL: recoverToDefault verification read failed", verifyResult.exceptionOrNull())
            return null
        }

        val (ok, enabledKey) = verifyResult.getOrThrow()
        return if (ok && enabledKey == "default") {
            // Only persist AFTER successfully establishing in PackageManager
            persistIcon("default")
            "default"
        } else {
            Log.e(TAG, "CRITICAL: recoverToDefault verification failed (enabled=$enabledKey)")
            null
        }
    }

    /**
     * Persist the icon key. Only call after successful PackageManager verification.
     */
    private fun persistIcon(iconKey: String) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit().putString(PREFS_KEY, iconKey).apply()
    }

    // ---- Public API ----

    /**
     * Combined initialization: reconcile state + return the actual current icon.
     * This is the single native init operation called by Dart on startup.
     *
     * Transactional:
     * 1. Verify current state matches saved preference
     * 2. If valid → return it
     * 3. If invalid → capture snapshot → attempt repair → verify →
     *    rollback to exact snapshot → verify snapshot restored →
     *    if snapshot was valid, return it; if snapshot was invalid, recoverToDefault
     *
     * Returns Result with the icon key on success, or error on unrecoverable state.
     */
    fun reconcileAndGetCurrentIcon(): Result<String> {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        var saved = prefs.getString(PREFS_KEY, "default") ?: "default"

        // Handle unknown/removed icon keys — but only persist after establishing default
        if (!aliases.containsKey(saved)) {
            Log.w(TAG, "Unknown saved icon '$saved' — will establish default")
            saved = "default"
        }

        // Capture current state for all checks
        val snapshotResult = captureState()
        if (snapshotResult.isFailure) {
            // Cannot read PackageManager at all — cannot do anything
            Log.e(TAG, "Cannot capture state at all — attempting blind recovery")
            val recovered = recoverToDefault()
            return if (recovered != null) {
                Result.success(recovered)
            } else {
                Result.failure(IllegalStateException("ICON_STATE_UNRECOVERABLE: cannot read PackageManager"))
            }
        }
        val snapshot = snapshotResult.getOrThrow()

        // Check if current state is valid (exactly one enabled) and matches saved
        val verifyResult = verifyExactlyOneEnabled()
        if (verifyResult.isFailure) {
            Log.e(TAG, "Cannot verify aliases — attempting recovery")
            val recovered = recoverToDefault()
            return if (recovered != null) Result.success(recovered)
            else Result.failure(IllegalStateException("ICON_STATE_UNRECOVERABLE: cannot verify state"))
        }

        val (ok, enabledKey) = verifyResult.getOrThrow()
        if (ok && enabledKey == saved) {
            // State is consistent — persist if we just fixed an unknown key
            if (!prefs.contains(PREFS_KEY) || prefs.getString(PREFS_KEY, null) != saved) {
                persistIcon(saved)
            }
            Log.i(TAG, "Icon state consistent: $saved")
            return Result.success(saved)
        }

        // State is inconsistent — attempt transactional repair
        Log.i(TAG, "Icon state inconsistent (enabled=$enabledKey, saved=$saved) — repairing")

        // Attempt to apply saved icon
        val applyResult = applyState(saved)
        if (applyResult.isFailure) {
            Log.e(TAG, "Repair apply failed — restoring snapshot", applyResult.exceptionOrNull())
            restoreState(snapshot)

            // Verify the snapshot was restored exactly
            return if (verifyStateEquals(snapshot)) {
                // Snapshot restored. But was the snapshot itself valid?
                if (isValidSnapshot(snapshot)) {
                    val restoredKey = snapshot.entries.find { it.value == PackageManager.COMPONENT_ENABLED_STATE_ENABLED }?.key
                    Log.i(TAG, "Snapshot rollback succeeded (valid state): $restoredKey")
                    persistIcon(restoredKey ?: "default")
                    Result.success(restoredKey ?: "default")
                } else {
                    // Snapshot was itself invalid — cannot return it as success
                    Log.w(TAG, "Snapshot was invalid — recovering to default")
                    val recovered = recoverToDefault()
                    if (recovered != null) Result.success(recovered)
                    else Result.failure(IllegalStateException("ICON_STATE_UNRECOVERABLE: invalid snapshot, recovery failed"))
                }
            } else {
                // Rollback itself failed
                Log.e(TAG, "Snapshot rollback verification failed")
                val recovered = recoverToDefault()
                if (recovered != null) Result.success(recovered)
                else Result.failure(IllegalStateException("ICON_STATE_UNRECOVERABLE: repair, rollback, and recovery all failed"))
            }
        }

        // Apply succeeded — verify repair
        val postRepairResult = verifyExactlyOneEnabled()
        if (postRepairResult.isSuccess && postRepairResult.getOrThrow().first && postRepairResult.getOrThrow().second == saved) {
            persistIcon(saved)
            Log.i(TAG, "Repaired launcher icon to: $saved")
            return Result.success(saved)
        }

        // Repair verification failed — rollback to exact snapshot
        Log.e(TAG, "Repair verification failed — restoring snapshot")
        restoreState(snapshot)

        return if (verifyStateEquals(snapshot)) {
            if (isValidSnapshot(snapshot)) {
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

    /**
     * Switch the launcher icon to [iconKey].
     *
     * Transactional with snapshot rollback:
     * 1. Capture current state (abort if capture fails — do NOT mutate)
     * 2. Apply target state (enable target, disable others)
     * 3. Verify exactly 1 enabled and it is the target
     * 4a. Success → persist → return success
     * 4b. Failure → restore exact snapshot → verify snapshot restored →
     *     if snapshot was valid, return it; if snapshot was invalid, recoverToDefault
     */
    fun setIcon(iconKey: String): Result<Unit> {
        val targetAlias = aliases[iconKey]
            ?: return Result.failure(IllegalArgumentException("Unknown icon: $iconKey"))

        // 1. Capture current state — if capture fails, ABORT (do not mutate)
        val snapshotResult = captureState()
        if (snapshotResult.isFailure) {
            Log.e(TAG, "Cannot capture state — aborting setIcon (no mutation)")
            return Result.failure(IllegalStateException("Cannot read current icon state", snapshotResult.exceptionOrNull()))
        }
        val snapshot = snapshotResult.getOrThrow()

        // 2. Apply target state
        val applyResult = applyState(iconKey)
        if (applyResult.isFailure) {
            Log.e(TAG, "Apply failed — restoring snapshot", applyResult.exceptionOrNull())
            return restoreAndVerify(snapshot, iconKey)
        }

        // 3. Verify
        val verifyResult = verifyExactlyOneEnabled()
        if (verifyResult.isFailure || !verifyResult.getOrThrow().first || verifyResult.getOrThrow().second != iconKey) {
            Log.w(TAG, "Verification failed (result=$verifyResult) — restoring snapshot")
            return restoreAndVerify(snapshot, iconKey)
        }

        // 4a. Success — persist
        persistIcon(iconKey)
        Log.i(TAG, "Launcher icon switched to: $iconKey")
        return Result.success(Unit)
    }

    /**
     * Restore from snapshot and verify the result.
     * Distinguishes between:
     * - Snapshot was valid → success (restored to previous working state)
     * - Snapshot was invalid → must recover to default
     * - Snapshot restoration itself failed → must recover to default
     */
    private fun restoreAndVerify(snapshot: Map<String, Int>, attemptedIcon: String): Result<Unit> {
        restoreState(snapshot)

        // Verify the exact snapshot was restored
        if (!verifyStateEquals(snapshot)) {
            Log.e(TAG, "Snapshot restoration failed — recovering to default")
            val recovered = recoverToDefault()
            return if (recovered != null) {
                Result.failure(IllegalStateException("Icon switch to $attemptedIcon failed, recovered to default"))
            } else {
                Result.failure(IllegalStateException("ICON_STATE_UNRECOVERABLE: snapshot restore and recovery both failed"))
            }
        }

        // Snapshot restored. Was the snapshot itself valid?
        if (isValidSnapshot(snapshot)) {
            val restoredKey = snapshot.entries.find { it.value == PackageManager.COMPONENT_ENABLED_STATE_ENABLED }?.key
            Log.i(TAG, "Snapshot rollback succeeded (valid state): $restoredKey")
            persistIcon(restoredKey ?: "default")
            return Result.failure(IllegalStateException("Icon switch to $attemptedIcon failed, restored to $restoredKey"))
        }

        // Snapshot was itself invalid — recover to default
        Log.w(TAG, "Snapshot was itself invalid — recovering to default")
        val recovered = recoverToDefault()
        return if (recovered != null) {
            Result.failure(IllegalStateException("Icon switch to $attemptedIcon failed, snapshot invalid, recovered to default"))
        } else {
            Result.failure(IllegalStateException("ICON_STATE_UNRECOVERABLE: invalid snapshot and recovery failed"))
        }
    }

    /**
     * Check if a snapshot represents a valid launcher state (exactly one alias enabled).
     */
    private fun isValidSnapshot(snapshot: Map<String, Int>): Boolean {
        val enabledCount = snapshot.values.count { it == PackageManager.COMPONENT_ENABLED_STATE_ENABLED }
        return enabledCount == 1
    }

    /**
     * Restore all aliases to their exact captured state.
     */
    private fun restoreState(snapshot: Map<String, Int>) {
        for ((key, alias) in aliases) {
            val targetState = snapshot[key] ?: continue
            try {
                pm.setComponentEnabledSetting(
                    ComponentName(pkg, alias),
                    targetState,
                    PackageManager.DONT_KILL_APP
                )
            } catch (e: Exception) {
                Log.e(TAG, "Failed to restore alias $key to state $targetState", e)
            }
        }
    }
}
