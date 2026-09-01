package com.nomadguy.noctra

import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager
import android.util.Log

/**
 * Manages the Android launcher icon by toggling activity-aliases.
 *
 * Architecture:
 * - MainActivity ALWAYS keeps its LAUNCHER filter and is NEVER disabled.
 * - Each alias represents an actual icon variant (not a theme).
 * - Only ONE alias should be enabled at a time.
 * - We use COMPONENT_ENABLED_STATE_DEFAULT (not DISABLED) for non-target
 *   aliases to avoid aggressive COMPONENT_REMOVED signals on OEM launchers.
 * - No ACTION_PACKAGE_CHANGED broadcast — Android handles launcher refresh.
 */
class LauncherIconManager(private val context: Context) {

    companion object {
        private const val TAG = "LauncherIconManager"
    }

    private val pm = context.packageManager
    private val pkg = context.packageName

    // Icon aliases only — no .amoled (duplicate of noir_black), no .default
    private val aliases = mapOf(
        "noir_black" to "$pkg.MainActivity.noir_black",
        "noir_white" to "$pkg.MainActivity.noir_white",
        "liquid_glass" to "$pkg.MainActivity.liquid_glass",
    )

    /**
     * Switch the launcher icon to [iconKey].
     *
     * Steps:
     * 1. Enable target alias first (safe — enabling never kills)
     * 2. Reset all other aliases to DEFAULT state (reverts to manifest "false")
     * 3. Persist choice
     *
     * @return Result.success if icon was switched, Result.failure with error otherwise.
     */
    fun setIcon(iconKey: String): Result<Unit> {
        if (!aliases.containsKey(iconKey)) {
            Log.w(TAG, "Unknown icon key: $iconKey")
            return Result.failure(IllegalArgumentException("Unknown icon: $iconKey"))
        }

        val targetAlias = aliases[iconKey]!!

        return try {
            // Step 1: Enable the target alias
            pm.setComponentEnabledSetting(
                ComponentName(pkg, targetAlias),
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                PackageManager.DONT_KILL_APP
            )

            // Step 2: Reset other aliases to DEFAULT (not DISABLED)
            aliases.values
                .filter { it != targetAlias }
                .forEach { alias ->
                    try {
                        pm.setComponentEnabledSetting(
                            ComponentName(pkg, alias),
                            PackageManager.COMPONENT_ENABLED_STATE_DEFAULT,
                            PackageManager.DONT_KILL_APP
                        )
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to reset alias: $alias", e)
                    }
                }

            // Step 3: Persist the choice
            context.getSharedPreferences("noctra_icon", Context.MODE_PRIVATE)
                .edit()
                .putString("selected_icon", iconKey)
                .apply()

            Log.i(TAG, "Launcher icon switched to: $iconKey")
            Result.success(Unit)
        } catch (e: Exception) {
            Log.e(TAG, "Icon switch failed for: $iconKey", e)
            Result.failure(e)
        }
    }
}
