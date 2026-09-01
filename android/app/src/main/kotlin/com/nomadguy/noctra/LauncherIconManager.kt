package com.nomadguy.noctra

import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager
import android.util.Log

/**
 * Manages the Android launcher icon by toggling activity-aliases.
 *
 * Architecture:
 * - MainActivity has NO LAUNCHER filter — it is the Flutter entry point only.
 * - Exactly ONE alias is enabled at any time (the launcher entry).
 * - On install: .default alias is enabled, all others disabled.
 * - Switching: enable target FIRST, then disable ALL others (including .default).
 * - Uses COMPONENT_ENABLED_STATE_DEFAULT for non-target aliases (reverts to
 *   manifest state: enabled="false" for all non-default aliases).
 * - No ACTION_PACKAGE_CHANGED broadcast — Android handles launcher refresh.
 * - Persists choice ONLY after all component operations succeed.
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

    /**
     * Switch the launcher icon to [iconKey].
     *
     * Steps:
     * 1. Enable target alias (safe — enabling never kills)
     * 2. Disable ALL other aliases using DEFAULT state (not DISABLED)
     * 3. Verify exactly one alias is now enabled
     * 4. Persist only after all operations succeed
     *
     * If ANY step fails, the entire operation is considered failed and
     * the caller should roll back its Dart-side state.
     */
    fun setIcon(iconKey: String): Result<Unit> {
        val targetAlias = aliases[iconKey]
            ?: return Result.failure(IllegalArgumentException("Unknown icon: $iconKey"))

        return try {
            // Step 1: Enable the target alias first (safe — enabling never kills)
            pm.setComponentEnabledSetting(
                ComponentName(pkg, targetAlias),
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                PackageManager.DONT_KILL_APP
            )

            // Step 2: Disable ALL other aliases (including .default)
            // Using DEFAULT state (reverts to manifest: enabled="false") instead
            // of DISABLED (which sends aggressive COMPONENT_REMOVED signal).
            for ((key, alias) in aliases) {
                if (key == iconKey) continue
                pm.setComponentEnabledSetting(
                    ComponentName(pkg, alias),
                    PackageManager.COMPONENT_ENABLED_STATE_DEFAULT,
                    PackageManager.DONT_KILL_APP
                )
            }

            // Step 3: Verify exactly one alias is enabled
            val enabledCount = aliases.values.count { alias ->
                try {
                    val state = pm.getComponentEnabledSetting(ComponentName(pkg, alias))
                    state == PackageManager.COMPONENT_ENABLED_STATE_ENABLED
                } catch (e: Exception) {
                    false
                }
            }

            if (enabledCount != 1) {
                Log.w(TAG, "Expected 1 enabled alias, found $enabledCount — retrying with explicit disable")
                // Fallback: explicitly disable all non-target aliases
                for ((key, alias) in aliases) {
                    if (key == iconKey) continue
                    pm.setComponentEnabledSetting(
                        ComponentName(pkg, alias),
                        PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                        PackageManager.DONT_KILL_APP
                    )
                }
            }

            // Step 4: Persist ONLY after all operations succeed
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .edit()
                .putString(PREFS_KEY, iconKey)
                .apply()

            Log.i(TAG, "Launcher icon switched to: $iconKey (verified $enabledCount enabled)")
            Result.success(Unit)
        } catch (e: Exception) {
            Log.e(TAG, "Icon switch FAILED for: $iconKey", e)
            Result.failure(e)
        }
    }

    /**
     * Called on app startup. Reconciles the persisted icon choice with
     * actual PackageManager state. If they disagree (e.g., after an
     * upgrade, interrupted operation, or OEM weirdness), repairs the state.
     */
    fun reconcileOnStartup() {
        val saved = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getString(PREFS_KEY, "default")
            ?: "default"

        val targetAlias = aliases[saved] ?: aliases["default"]!!

        // Check how many aliases are currently enabled
        val enabledAliases = aliases.entries.filter { (_, alias) ->
            try {
                pm.getComponentEnabledSetting(ComponentName(pkg, alias)) ==
                    PackageManager.COMPONENT_ENABLED_STATE_ENABLED
            } catch (e: Exception) {
                false
            }
        }

        if (enabledAliases.size == 1 && enabledAliases.first().key == saved) {
            // State is consistent — nothing to do
            return
        }

        // State is inconsistent — repair it
        Log.i(TAG, "Icon state inconsistent (${enabledAliases.size} enabled, saved=$saved) — repairing")

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

            Log.i(TAG, "Repaired launcher icon state to: $saved")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to repair icon state", e)
        }
    }
}
