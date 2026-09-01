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
 * Architecture:
 * - MainActivity has NO LAUNCHER filter — it is the Flutter entry point only.
 * - All aliases start manifest-disabled. On first startup, the correct alias
 *   is explicitly enabled (no implicit dependency on manifest defaults).
 * - Switching: capture old state → enable target → disable others → verify →
 *   persist (only on full success). On failure: restore old state.
 * - Uses COMPONENT_ENABLED_STATE_DEFAULT for non-target aliases (reverts to
 *   manifest "false" since all aliases start disabled).
 * - No ACTION_PACKAGE_CHANGED broadcast — Android handles launcher refresh.
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

    /** Read the current enabled/disabled state of every alias. */
    private fun captureState(): Map<String, Int> {
        return aliases.mapValues { (_, alias) ->
            try {
                pm.getComponentEnabledSetting(ComponentName(pkg, alias))
            } catch (e: Exception) {
                PackageManager.COMPONENT_ENABLED_STATE_DEFAULT
            }
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
     * Switch the launcher icon to [iconKey].
     *
     * Algorithm (transactional with rollback):
     * 1. Capture current state
     * 2. Enable target alias
     * 3. Disable all other aliases
     * 4. Verify exactly 1 enabled and it is the target
     * 5a. On success → persist → return success
     * 5b. On failure → restore old state → return failure
     */
    fun setIcon(iconKey: String): Result<Unit> {
        val targetAlias = aliases[iconKey]
            ?: return Result.failure(IllegalArgumentException("Unknown icon: $iconKey"))

        // Step 1: Capture current state for rollback
        val oldState = captureState()

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
            return Result.failure(e)
        }
    }

    /**
     * Called on app startup. Reconciles the persisted icon choice with
     * actual PackageManager state. Handles:
     * - First install (no aliases enabled → enable default)
     * - Upgrade from old architecture
     * - Interrupted operation
     * - OEM weirdness
     * - Unknown/removed saved icon key
     *
     * Invariant after return: EXACTLY ONE alias is enabled.
     */
    fun reconcileOnStartup() {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        var saved = prefs.getString(PREFS_KEY, "default") ?: "default"

        // Handle unknown/removed icon keys — fall back to default
        if (!aliases.containsKey(saved)) {
            Log.w(TAG, "Unknown saved icon '$saved' — falling back to default")
            saved = "default"
            prefs.edit().putString(PREFS_KEY, saved).apply()
        }

        val targetAlias = aliases[saved]!!

        // Check current state
        val (ok, enabledKey) = verifyExactlyOneEnabled()

        if (ok && enabledKey == saved) {
            // State is consistent — nothing to do
            Log.i(TAG, "Icon state consistent: $saved")
            return
        }

        // State is inconsistent — repair it
        Log.i(TAG, "Icon state inconsistent (enabled=$enabledKey, saved=$saved) — repairing")

        try {
            // Enable target
            pm.setComponentEnabledSetting(
                ComponentName(pkg, targetAlias),
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                PackageManager.DONT_KILL_APP
            )

            // Disable all others
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
            } else {
                Log.e(TAG, "Repair verification failed (enabled=$repairedKey, expected=$saved)")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to repair icon state", e)
        }
    }
}
