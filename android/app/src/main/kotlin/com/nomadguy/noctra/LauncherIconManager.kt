package com.nomadguy.noctra

import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager
import android.util.Log

/**
 * Manages the Android launcher icon by toggling activity-aliases.
 *
 * Invariant enforced everywhere: EXACTLY ONE alias is enabled at any time.
 * Android PackageManager is the single source of truth.
 * All operations are serialized via the caller's iconExecutor.
 *
 * Transactional algorithm:
 *   1. Capture current state (snapshot)
 *   2. Apply target state
 *   3. Verify exactly 1 enabled == target
 *   4a. Success → persist → return success
 *   4b. Failure → restore snapshot → verify rollback → if rollback fails, force default
 */
class LauncherIconManager(private val context: Context) {

    companion object {
        private const val TAG = "LauncherIconManager"
        private const val PREFS_NAME = "noctra_icon"
        private const val PREFS_KEY = "selected_icon"
    }

    private val pm = context.packageManager
    private val pkg = context.packageName

    /** All launcher aliases — exactly one should be enabled at any time. */
    private val aliases = mapOf(
        "default" to "$pkg.MainActivity.default",
        "noir_black" to "$pkg.MainActivity.noir_black",
        "noir_white" to "$pkg.MainActivity.noir_white",
        "liquid_glass" to "$pkg.MainActivity.liquid_glass",
    )

    // ---- Internal helpers ----

    /**
     * Capture the current enabled/disabled state of all aliases.
     * Returns a map of aliasKey → component enabled state.
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
     * Restore a previously captured state.
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

    /** Check how many aliases are currently enabled, and which one. */
    private fun verifyExactlyOneEnabled(): Pair<Boolean, String?> {
        val enabledAliases = aliases.entries.filter { (_, alias) ->
            try {
                pm.getComponentEnabledSetting(ComponentName(pkg, alias)) ==
                    PackageManager.COMPONENT_ENABLED_STATE_ENABLED
            } catch (e: Exception) {
                false
            }
        }
        return Pair(enabledAliases.size == 1, enabledAliases.firstOrNull()?.key)
    }

    /**
     * Force exactly one alias into a specific enabled state using explicit ENABLED/DISABLED.
     * Target → ENABLED, all others → DISABLED.
     */
    private fun applyExplicitState(targetKey: String): Result<Unit> {
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
            Log.e(TAG, "Failed to apply explicit state for: $targetKey", e)
            Result.failure(e)
        }
    }

    /**
     * Last-resort recovery: force default alias enabled, all others disabled.
     * Returns the icon key that is actually enabled, or null if everything failed.
     * Verifies its own result.
     */
    private fun forceDefaultIcon(): String? {
        Log.w(TAG, "Last-resort: forcing default icon")
        val result = applyExplicitState("default")
        if (result.isFailure) {
            Log.e(TAG, "CRITICAL: forceDefaultIcon apply failed", result.exceptionOrNull())
            return null
        }

        val (ok, enabledKey) = verifyExactlyOneEnabled()
        return if (ok && enabledKey == "default") {
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .edit().putString(PREFS_KEY, "default").apply()
            "default"
        } else {
            Log.e(TAG, "CRITICAL: forceDefaultIcon verification failed (enabled=$enabledKey)")
            null
        }
    }

    /**
     * Verify that exactly the target icon is enabled.
     */
    private fun verifyTarget(iconKey: String): Boolean {
        val (ok, enabledKey) = verifyExactlyOneEnabled()
        return ok && enabledKey == iconKey
    }

    // ---- Public API ----

    /**
     * Combined initialization: reconcile state + return the actual current icon.
     * This is the single native init operation called by Dart on startup.
     *
     * Transactional:
     * 1. Verify current state
     * 2. If valid → return it
     * 3. If invalid → capture snapshot → attempt repair → verify → if fails, rollback → if rollback fails, force default
     *
     * Returns Result with the icon key on success, or error on unrecoverable state.
     */
    fun reconcileAndGetCurrentIcon(): Result<String> {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        var saved = prefs.getString(PREFS_KEY, "default") ?: "default"

        // Handle unknown/removed icon keys
        if (!aliases.containsKey(saved)) {
            Log.w(TAG, "Unknown saved icon '$saved' — resetting to default")
            saved = "default"
            prefs.edit().putString(PREFS_KEY, "default").apply()
        }

        // Check current state — if valid, return immediately
        val (ok, enabledKey) = verifyExactlyOneEnabled()
        if (ok && enabledKey == saved) {
            Log.i(TAG, "Icon state consistent: $saved")
            return Result.success(saved)
        }

        // State is inconsistent — attempt transactional repair
        Log.i(TAG, "Icon state inconsistent (enabled=$enabledKey, saved=$saved) — repairing")

        // Capture current state for rollback
        val snapshotResult = captureState()
        if (snapshotResult.isFailure) {
            Log.e(TAG, "Cannot capture state for repair — forcing default")
            val recovered = forceDefaultIcon()
            return if (recovered != null) {
                Result.success(recovered)
            } else {
                Result.failure(IllegalStateException("ICON_STATE_UNRECOVERABLE: cannot capture or repair state"))
            }
        }
        val snapshot = snapshotResult.getOrThrow()

        // Attempt to apply saved icon
        val applyResult = applyExplicitState(saved)
        if (applyResult.isFailure) {
            Log.e(TAG, "Repair apply failed — restoring snapshot", applyResult.exceptionOrNull())
            restoreState(snapshot)
            if (verifyTarget(enabledKey ?: "default")) {
                Log.i(TAG, "Snapshot rollback succeeded")
                prefs.edit().putString(PREFS_KEY, enabledKey ?: "default").apply()
                return Result.success(enabledKey ?: "default")
            }
            // Rollback also failed — force default
            val recovered = forceDefaultIcon()
            return if (recovered != null) {
                Result.success(recovered)
            } else {
                Result.failure(IllegalStateException("ICON_STATE_UNRECOVERABLE: repair and rollback both failed"))
            }
        }

        // Verify repair
        if (verifyTarget(saved)) {
            prefs.edit().putString(PREFS_KEY, saved).apply()
            Log.i(TAG, "Repaired launcher icon to: $saved")
            return Result.success(saved)
        }

        // Repair verification failed — rollback
        Log.e(TAG, "Repair verification failed — restoring snapshot")
        restoreState(snapshot)

        // Verify rollback
        if (verifyTarget(enabledKey ?: "default")) {
            Log.i(TAG, "Snapshot rollback succeeded after failed repair")
            prefs.edit().putString(PREFS_KEY, enabledKey ?: "default").apply()
            return Result.success(enabledKey ?: "default")
        }

        // Rollback also failed — last resort
        Log.e(TAG, "Rollback verification failed — forcing default")
        val recovered = forceDefaultIcon()
        return if (recovered != null) {
            Result.success(recovered)
        } else {
            Result.failure(IllegalStateException("ICON_STATE_UNRECOVERABLE: all recovery attempts failed"))
        }
    }

    /**
     * Switch the launcher icon to [iconKey].
     *
     * Transactional with snapshot rollback:
     * 1. Capture current state
     * 2. Apply target state (enable target, disable others)
     * 3. Verify exactly 1 enabled and it is the target
     * 4a. Success → persist → return success
     * 4b. Failure → restore snapshot → verify rollback → if rollback fails, force default
     */
    fun setIcon(iconKey: String): Result<Unit> {
        val targetAlias = aliases[iconKey]
            ?: return Result.failure(IllegalArgumentException("Unknown icon: $iconKey"))

        // 1. Capture current state for rollback
        val snapshotResult = captureState()
        if (snapshotResult.isFailure) {
            Log.e(TAG, "Cannot capture state — attempting direct apply")
            val applyResult = applyExplicitState(iconKey)
            if (applyResult.isFailure) {
                forceDefaultIcon()
                return applyResult
            }
            if (verifyTarget(iconKey)) {
                persistIcon(iconKey)
                return Result.success(Unit)
            }
            forceDefaultIcon()
            return Result.failure(IllegalStateException("Cannot capture state and apply failed"))
        }
        val snapshot = snapshotResult.getOrThrow()

        // 2. Apply target state
        val applyResult = applyExplicitState(iconKey)
        if (applyResult.isFailure) {
            Log.e(TAG, "Apply failed — restoring snapshot", applyResult.exceptionOrNull())
            restoreState(snapshot)
            verifyAndHandleRollback(snapshot, iconKey)
            return applyResult
        }

        // 3. Verify
        if (verifyTarget(iconKey)) {
            // 4a. Success — persist
            persistIcon(iconKey)
            Log.i(TAG, "Launcher icon switched to: $iconKey")
            return Result.success(Unit)
        }

        // 4b. Verification failed — restore snapshot
        Log.w(TAG, "Verification failed (expected=$iconKey) — restoring snapshot")
        restoreState(snapshot)

        // Verify rollback
        val rolledBackOk = verifyRollback(snapshot)
        if (!rolledBackOk) {
            // Rollback also failed — last resort
            Log.e(TAG, "Rollback verification failed — forcing default")
            val recovered = forceDefaultIcon()
            if (recovered == null) {
                return Result.failure(IllegalStateException("ICON_STATE_UNRECOVERABLE: verification, rollback, and default recovery all failed"))
            }
        }

        return Result.failure(IllegalStateException("Icon verification failed: expected=$iconKey"))
    }

    /**
     * Persist the icon key after a successful operation.
     */
    private fun persistIcon(iconKey: String) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit().putString(PREFS_KEY, iconKey).apply()
    }

    /**
     * Verify that the rollback restored the expected state.
     * The expected state is whichever alias was enabled before we started (from snapshot).
     */
    private fun verifyRollback(snapshot: Map<String, Int>): Boolean {
        // Find which alias was enabled in the snapshot
        val previouslyEnabled = snapshot.entries.find { (_, state) ->
            state == PackageManager.COMPONENT_ENABLED_STATE_ENABLED
        }?.key

        if (previouslyEnabled != null) {
            return verifyTarget(previouslyEnabled)
        }
        // No alias was enabled in snapshot — verify exactly one is enabled now (any)
        val (ok, _) = verifyExactlyOneEnabled()
        return ok
    }

    /**
     * Handle rollback + verification after a failed setIcon attempt.
     * Used when we already restored state and just need to verify.
     */
    private fun verifyAndHandleRollback(snapshot: Map<String, Int>, attemptedIcon: String) {
        val rolledBackOk = verifyRollback(snapshot)
        if (!rolledBackOk) {
            Log.e(TAG, "Rollback verification failed — forcing default")
            forceDefaultIcon()
        }
    }
}
