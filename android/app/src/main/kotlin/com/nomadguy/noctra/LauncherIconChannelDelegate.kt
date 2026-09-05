package com.nomadguy.noctra

import android.app.Activity
import android.util.Log
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ExecutorService

object LauncherIconChannelDelegate {
    private const val TAG = "LauncherIconDelegate"
    private const val ICON_CHANNEL = "com.nomadguy.noctra/launcher_icon"

    fun register(
        activity: Activity,
        messenger: DartExecutor,
        launcherIconManager: LauncherIconManager,
        iconExecutor: ExecutorService
    ) {
        MethodChannel(messenger, ICON_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "reconcileAndInit" -> {
                    iconExecutor.execute {
                        try {
                            val iconResult = launcherIconManager.reconcileAndGetCurrentIcon()
                            activity.runOnUiThread {
                                try {
                                    iconResult.fold(
                                        onSuccess = { icon -> result.success(icon) },
                                        onFailure = { error ->
                                            Log.e(TAG, "Icon reconciliation failed", error)
                                            result.error("ICON_STATE_UNRECOVERABLE", error.message, null)
                                        }
                                    )
                                } catch (e: Throwable) {
                                    Log.e(TAG, "Failed to deliver icon result", e)
                                }
                            }
                        } catch (e: Throwable) {
                            Log.e(TAG, "reconcileAndInit crashed", e)
                            activity.runOnUiThread {
                                try {
                                    result.error("ICON_INIT_ERROR", e.message, null)
                                } catch (e2: Throwable) {
                                    Log.e(TAG, "Failed to deliver icon init error", e2)
                                }
                            }
                        }
                    }
                }
                "setIcon" -> {
                    val iconKey = call.argument<String>("icon") ?: ""
                    if (iconKey.isEmpty()) {
                        result.error("INVALID_ICON", "Icon key must not be empty", null)
                        return@setMethodCallHandler
                    }
                    iconExecutor.execute {
                        val operation = launcherIconManager.setIcon(iconKey)
                        activity.runOnUiThread {
                            try {
                                operation.fold(
                                    onSuccess = { result.success(true) },
                                    onFailure = { error ->
                                        Log.e(TAG, "Icon switch failed", error)
                                        result.error("ICON_CHANGE_FAILED", error.message, null)
                                    }
                                )
                            } catch (e: Throwable) {
                                Log.e(TAG, "Failed to deliver icon change result", e)
                            }
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
