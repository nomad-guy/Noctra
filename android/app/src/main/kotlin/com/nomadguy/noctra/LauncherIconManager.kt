package com.nomadguy.noctra

import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager
import android.util.Log

/**
 * Manages the Android launcher icon by toggling activity-aliases.
 *
 * Invariant enforced everywhere: EXACTLY ONE alias is enabled at any time.
 *
 * Android PackageManager is the single source of truth.
 * Dart reads from this on startup via getCurrentIcon().
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
     * Read the current enabled/disabled state of every alias.
     * Returns Result.failure if any state read fails (never silently defaults).
     */
    private fun captureState(): Result<Map<String, Int>> {
        return try {
            val state = aliases.mapValues { (_, alias) ->
                pm.getComponentEnabledSetting(ComponentName(pkg, alias))
            }
            Result.success(state)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to capture component state", e)
            Result.failure(e)
        }
    }

    /** Restore a previously captured state snapshot. */
    private fun restoreState(snapshot: Map<String, Int>) {
        for ((key, state) in snapshot) {
            val alias = aliases[key] ?: continue
            try {
                pm.setComponentEnabledSetting(ComponentName(pkg, alias), state, PackageManager.DONT_KILL_APP)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to restore alias $key to state $state", e)
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

    // ---- Public API ----

    /**
     * Returns the key of the currently enabled launcher icon.
     * Used by Dart on startup to read the actual Android state.
     */
    fun getCurrentIcon(): String {
        val (_, enabledKey) = verifyExactlyOneEnabled()
        return enabledKey ?: "default"
    }

    /**
     * Switch the launcher icon to [iconKey].
     *
     * Algorithm (transactional with rollback):
     * 1. Capture current state
     * 2. Enable target alias
     * 3. Disable all other aliases
     * 4. Verify exactly 1 enabled and it is the target
     * 5a. On success → persist → return success
     * 5b. On failure → restore old state → verify rollback → return failure
     */
    fun setIcon(iconKey: String): Result<Unit> {
        val targetAlias = aliases[iconKey]
            ?: return Result.failure(IllegalArgumentException("Unknown icon: $iconKey"))

        // Step 1: Capture current state for rollback
        val oldStateResult = captureState()
        if (oldStateResult.isFailure) {
            return Result.failure(IllegalStateException("Cannot read current state", oldStateResult.exceptionOrNull()))
        }
        val oldState = oldStateResult.getOrThrow()

        try {
            // Step 2: Enable the target alias first (safe — enabling never kills)
            pm.setComponentEnabledSetting(
                ComponentName(pkg, targetAlias),
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                PackageManager.DONT_KILL_APP
            )

            // Step 3: Disable ALL other aliases
            for ((key, alias) in aliases) {
                if (key == iconKey) continue
                pm.setComponentEnabledSetting(
                    ComponentName(pkg, alias),
                    PackageManager.COMPONENT_ENABLED_STATE_DEFAULT,
                    PackageManager.DONT_KILL_APP
                )
            }

            // Step 4: Verify — must be exactly 1 enabled and it must be the target
            val (ok, enabledKey) = verifyExactlyOneEnabled()
            if (!ok || enabledKey != iconKey) {
                Log.w(TAG, "Verification failed after switch (enabled=$enabledKey, expected=$iconKey) — restoring old state")
                restoreState(oldState)

                // Step 5b-verify: verify rollback itself
                val (rollbackOk, rollbackKey) = verifyExactlyOneEnabled()
                if (!rollbackOk) {
                    Log.e(TAG, "ROLLBACK VERIFICATION FAILED (enabled=$rollbackKey) — state may be inconsistent")
                }
                return Result.failure(IllegalStateException("Icon verification failed: enabled=$enabledKey, expected=$iconKey"))
            }

            // Step 5a: All good — persist
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .edit()
                .putString(PREFS_KEY, iconKey)
                .apply()

            Log.i(TAG, "Launcher icon switched to: $iconKey")
            return Result.success(Unit)

        } catch (e: Exception) {
            // Step 5b: Something failed — rollback to old state
            Log.e(TAG, "Icon switch FAILED for: $iconKey — restoring old state", e)
            restoreState(oldState)

            // Verify rollback
            val (rollbackOk, rollbackKey) = verifyExactlyOneEnabled()
            if (!rollbackOk) {
                Log.e(TAG, "ROLLBACK VERIFICATION FAILED after exception (enabled=$rollbackKey) — state may be inconsistent")
            }
            return Result.failure(e)
        }
    }

    /**
     * Called on app startup. Reconciles the persisted icon choice with
     * actual PackageManager state. Invariant after return: EXACTLY ONE alias enabled.
     */
    fun reconcileOnStartup() {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        var saved = prefs.getString(PREFS_KEY, "default") ?: "default"

        // Handle unknown/removed icon keys
        if (!aliases.containsKey(saved)) {
            Log.w(TAG, "Unknown saved icon '$saved' — falling back to default")
            saved = "default"
        }

        val targetAlias = aliases[saved]!!

        // Check current state
        val (ok, enabledKey) = verifyExactlyOneEnabled()

        if (ok && enabledKey == saved) {
            Log.i(TAG, "Icon state consistent: $saved")
            return
        }

        // State is inconsistent — repair it
        Log.i(TAG, "Icon state inconsistent (enabled=$enabledKey, saved=$saved) — repairing")

        try {
            pm.setComponentEnabledSetting(
                ComponentName(pkg, targetAlias),
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                PackageManager.DONT_KILL_APP
            )
            for ((key, alias) in aliases) {
                if (key == saved) continue
                pm.setComponentEnabledSetting(
                    ComponentName(pkg, alias),
                    PackageManager.COMPONENT_ENABLED_STATE_DEFAULT,
                    PackageManager.DONT_KILL_APP
                )
            }

            // Verify repair
            val (repairedOk, repairedKey) = verifyExactlyOneEnabled()
            if (repairedOk && repairedKey == saved) {
                Log.i(TAG, "Repaired launcher icon state to: $saved")
                // Persist the repaired state
                prefs.edit().putString(PREFS_KEY, saved).apply()
            } else {
                Log.e(TAG, "Repair verification failed (enabled=$repairedKey, expected=$saved)")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to repair icon state", e)
        }
    }
}
