package com.nomadguy.noctra

import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager
import android.util.Log

class LauncherIconStateHelper(
    private val context: Context,
    private val aliases: Map<String, String>
) {
    companion object {
        private const val TAG = "LauncherIconState"
    }

    private val pm: PackageManager = context.packageManager
    private val pkg: String = context.packageName

    fun captureState(): Result<Map<String, Int>> {
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

    fun applyState(targetKey: String): Result<Unit> {
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

    fun verifyStateEquals(snapshot: Map<String, Int>): Boolean {
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

    fun verifyExactlyOneEnabled(): Result<Pair<Boolean, String?>> {
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

    fun restoreState(snapshot: Map<String, Int>): Result<Unit> {
        return try {
            for ((key, alias) in aliases) {
                val state = snapshot[key] ?: PackageManager.COMPONENT_ENABLED_STATE_DEFAULT
                pm.setComponentEnabledSetting(ComponentName(pkg, alias), state, PackageManager.DONT_KILL_APP)
            }
            Result.success(Unit)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to restore snapshot", e)
            Result.failure(e)
        }
    }

    fun isValidSnapshot(snapshot: Map<String, Int>): Boolean {
        val enabledCount = snapshot.values.count { it == PackageManager.COMPONENT_ENABLED_STATE_ENABLED }
        return enabledCount == 1
    }
}
