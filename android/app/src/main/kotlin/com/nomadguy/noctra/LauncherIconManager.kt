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
 * All operations are serialized internally via synchronized blocks.
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
     * Apply a target icon state: enable target, disable all others.
     * Returns Result indicating success or the state of failure.
     */
    @Synchronized
    private fun applyIconState(targetKey: String): Result<Unit> {
        val targetAlias = aliases[targetKey]
            ?: return Result.failure(IllegalArgumentException("Unknown icon: $targetKey"))

        return try {
            pm.setComponentEnabledSetting(
                ComponentName(pkg, targetAlias),
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                PackageManager.DONT_KILL_APP
            )
            for ((key, alias) in aliases) {
                if (key == targetKey) continue
                pm.setComponentEnabledSetting(
                    ComponentName(pkg, alias),
                    PackageManager.COMPONENT_ENABLED_STATE_DEFAULT,
                    PackageManager.DONT_KILL_APP
                )
            }
            Result.success(Unit)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to apply icon state for: $targetKey", e)
            Result.failure(e)
        }
    }

    /**
     * Last-resort recovery: force default alias enabled, all others disabled.
     * If this fails, the app may lose its launcher icon entirely.
     */
    private fun forceDefaultIcon() {
        Log.w(TAG, "Last-resort: forcing default icon")
        try {
            pm.setComponentEnabledSetting(
                ComponentName(pkg, aliases["default"]!!),
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                PackageManager.DONT_KILL_APP
            )
            for ((key, alias) in aliases) {
                if (key == "default") continue
                pm.setComponentEnabledSetting(
                    ComponentName(pkg, alias),
                    PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                    PackageManager.DONT_KILL_APP
                )
            }
        } catch (e: Exception) {
            Log.e(TAG, "CRITICAL: Last-resort default icon recovery FAILED", e)
        }
    }

    // ---- Public API ----

    /**
     * Combined initialization: reconcile state + return the actual current icon.
     * This is the single native init operation called by Dart on startup.
     *
     * Returns the icon key that is actually enabled, or "default" as last resort.
     */
    @Synchronized
    fun reconcileAndGetCurrentIcon(): String {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        var saved = prefs.getString(PREFS_KEY, "default") ?: "default"

        // Handle unknown/removed icon keys
        if (!aliases.containsKey(saved)) {
            Log.w(TAG, "Unknown saved icon '$saved' — falling back to default")
            saved = "default"
        }

        // Check current state
        val (ok, enabledKey) = verifyExactlyOneEnabled()

        if (ok && enabledKey == saved) {
            // State is consistent
            Log.i(TAG, "Icon state consistent: $saved")
            return saved
        }

        // State is inconsistent — repair it
        Log.i(TAG, "Icon state inconsistent (enabled=$enabledKey, saved=$saved) — repairing")

        val applyResult = applyIconState(saved)
        if (applyResult.isSuccess) {
            val (repairedOk, repairedKey) = verifyExactlyOneEnabled()
            if (repairedOk && repairedKey == saved) {
                prefs.edit().putString(PREFS_KEY, saved).apply()
                Log.i(TAG, "Repaired launcher icon to: $saved")
                return saved
            }
            Log.e(TAG, "Repair verification failed (enabled=$repairedKey, expected=$saved)")
        } else {
            Log.e(TAG, "Repair apply failed", applyResult.exceptionOrNull())
        }

        // Repair failed — last resort: force default
        forceDefaultIcon()
        val (lastResortOk, lastResortKey) = verifyExactlyOneEnabled()
        if (lastResortOk) {
            prefs.edit().putString(PREFS_KEY, lastResortKey).apply()
            Log.w(TAG, "Last-resort recovery succeeded: $lastResortKey")
            return lastResortKey ?: "default"
        }

        // Absolute worst case — log critical error, return default
        Log.e(TAG, "CRITICAL: Could not establish any valid launcher icon state")
        return "default"
    }

    /**
     * Switch the launcher icon to [iconKey].
     *
     * Transactional with rollback:
     * 1. Enable target alias
     * 2. Disable all other aliases
     * 3. Verify exactly 1 enabled and it is the target
     * 4a. Success → persist → return success
     * 4b. Failure → last-resort recovery → return failure
     */
    @Synchronized
    fun setIcon(iconKey: String): Result<Unit> {
        val targetAlias = aliases[iconKey]
            ?: return Result.failure(IllegalArgumentException("Unknown icon: $iconKey"))

        // Apply target state
        val applyResult = applyIconState(iconKey)
        if (applyResult.isFailure) {
            forceDefaultIcon()
            return applyResult
        }

        // Verify
        val (ok, enabledKey) = verifyExactlyOneEnabled()
        if (!ok || enabledKey != iconKey) {
            Log.w(TAG, "Verification failed (enabled=$enabledKey, expected=$iconKey) — last-resort recovery")
            forceDefaultIcon()
            return Result.failure(IllegalStateException("Icon verification failed: enabled=$enabledKey, expected=$iconKey"))
        }

        // All good — persist
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(PREFS_KEY, iconKey)
            .apply()

        Log.i(TAG, "Launcher icon switched to: $iconKey")
        return Result.success(Unit)
    }
}
