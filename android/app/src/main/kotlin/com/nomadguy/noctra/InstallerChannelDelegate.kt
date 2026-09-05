package com.nomadguy.noctra

import android.app.Activity
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import java.io.File

object InstallerChannelDelegate {
    private const val TAG = "InstallerChannelDelegate"
    private const val UPDATE_NOTIFY_CHANNEL = "com.nomadguy.noctra/update_notify"
    private const val SIGNING_CERT_CHANNEL = "com.nomadguy.noctra/signing_cert"
    private const val INSTALLER_CHECK_CHANNEL = "com.nomadguy.noctra/installer_check"

    fun register(activity: Activity, messenger: DartExecutor) {
        // ====== UPDATE NOTIFICATIONS ======
        MethodChannel(messenger, UPDATE_NOTIFY_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "showUpdateNotification") {
                val title = call.argument<String>("title") ?: "Noctra update available"
                val body = call.argument<String>("body") ?: "Tap to download."
                val url = call.argument<String>("url") ?: ""
                try {
                    val nm = activity.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                    val channelId = "noctra_updates"
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        val ch = NotificationChannel(channelId, "Noctra Updates", NotificationManager.IMPORTANCE_HIGH).apply {
                            description = "New version release alerts"
                        }
                        nm.createNotificationChannel(ch)
                    }
                    val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
                    val pi = PendingIntent.getActivity(
                        activity, 0, intent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                    val notification = NotificationCompat.Builder(activity, channelId)
                        .setSmallIcon(R.drawable.ic_notification)
                        .setContentTitle(title)
                        .setContentText(body)
                        .setAutoCancel(true)
                        .setPriority(NotificationCompat.PRIORITY_HIGH)
                        .setContentIntent(pi)
                        .build()
                    nm.notify(9001, notification)
                    result.success(true)
                } catch (e: Throwable) {
                    Log.e(TAG, "Update notification failed", e)
                    result.success(false)
                }
            } else if (call.method == "installApk") {
                val filePath = call.argument<String>("filePath") ?: ""
                try {
                    val file = File(filePath)
                    if (file.exists()) {
                        val uri = FileProvider.getUriForFile(
                            activity.applicationContext,
                            "${activity.applicationContext.packageName}.fileprovider",
                            file
                        )
                        val installIntent = Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(uri, "application/vnd.android.package-archive")
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_GRANT_READ_URI_PERMISSION
                        }
                        activity.startActivity(installIntent)
                        result.success(true)
                    } else {
                        result.success(false)
                    }
                } catch (e: Throwable) {
                    Log.e(TAG, "APK install failed", e)
                    result.error("INSTALL_ERROR", e.message, null)
                }
            } else if (call.method == "shareFile") {
                val filePath = call.argument<String>("filePath") ?: ""
                val title = call.argument<String>("title") ?: "Share"
                val mimeType = call.argument<String>("mimeType") ?: "image/png"
                try {
                    val file = File(filePath)
                    if (file.exists()) {
                        val uri = FileProvider.getUriForFile(
                            activity.applicationContext,
                            "${activity.applicationContext.packageName}.fileprovider",
                            file
                        )
                        val shareIntent = Intent(Intent.ACTION_SEND).apply {
                            type = mimeType
                            putExtra(Intent.EXTRA_STREAM, uri)
                            flags = Intent.FLAG_GRANT_READ_URI_PERMISSION
                        }
                        val chooser = Intent.createChooser(shareIntent, title).apply {
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        activity.startActivity(chooser)
                        result.success(true)
                    } else {
                        result.success(false)
                    }
                } catch (e: Throwable) {
                    Log.e(TAG, "File share failed", e)
                    result.error("SHARE_ERROR", e.message, null)
                }
            } else {
                result.notImplemented()
            }
        }

        // ====== SIGNING CERTIFICATE ======
        MethodChannel(messenger, SIGNING_CERT_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method != "getInstalledSigningCertSha256") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            try {
                result.success(
                    SigningCertUtils.installedSignerDigests(
                        activity.packageManager,
                        activity.packageName
                    )
                )
            } catch (e: Throwable) {
                Log.e(TAG, "signing cert lookup failed", e)
                result.error("SIGNING_CERT_ERROR", e.message, null)
            }
        }

        // ====== INSTALLER CHECK ======
        MethodChannel(messenger, INSTALLER_CHECK_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method != "inspectDownloadedApk") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            try {
                val path = call.argument<String>("filePath")
                if (path.isNullOrEmpty()) {
                    result.error("INSTALLER_CHECK_ERROR", "missing filePath", null)
                    return@setMethodCallHandler
                }
                val pm = activity.packageManager
                val archive = pm.getPackageArchiveInfo(
                    path,
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                        PackageManager.GET_SIGNING_CERTIFICATES
                    } else {
                        @Suppress("DEPRECATION")
                        PackageManager.GET_SIGNATURES
                    }
                )
                if (archive == null) {
                    result.error("INSTALLER_CHECK_ERROR", "unparsable APK", null)
                    return@setMethodCallHandler
                }
                archive.applicationInfo?.sourceDir = path
                val pkgName = archive.packageName ?: ""
                val versionName = archive.versionName ?: ""
                val versionCode: Long =
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                        archive.longVersionCode
                    } else {
                        @Suppress("DEPRECATION")
                        archive.versionCode.toLong()
                    }
                val signerDigests = SigningCertUtils.signerDigestsOf(archive)
                val matchesInstalled =
                    signerDigests.isNotEmpty() &&
                        signerDigests.any {
                            SigningCertUtils.installedSignerDigests(pm, activity.packageName)
                                .contains(it)
                        }
                val payload = mapOf(
                    "packageName" to pkgName,
                    "versionCode" to versionCode,
                    "versionName" to versionName,
                    "signerDigests" to signerDigests,
                    "matchesInstalledSigner" to matchesInstalled,
                    "installedVersionCode" to
                        SigningCertUtils.installedVersionCode(pm, activity.packageName)
                )
                result.success(payload)
            } catch (e: Throwable) {
                Log.e(TAG, "installer check failed", e)
                result.error("INSTALLER_CHECK_ERROR", e.message, null)
            }
        }
    }
}
