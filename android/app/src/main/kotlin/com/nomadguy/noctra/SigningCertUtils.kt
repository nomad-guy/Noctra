package com.nomadguy.noctra

import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.content.pm.Signature
import android.os.Build
import java.security.MessageDigest

/**
 * Utility functions for extracting and verifying package signing certificates
 * across Android versions (GET_SIGNING_CERTIFICATES on API 28+ vs legacy GET_SIGNATURES).
 */
object SigningCertUtils {

    /**
     * Compute the SHA-256 of a Signature's underlying X.509 certificate (lower-case hex).
     */
    fun certSha256(sig: Signature): String {
        val raw = sig.toByteArray()
        val md = MessageDigest.getInstance("SHA-256")
        val digest = md.digest(raw)
        return digest.joinToString("") { "%02x".format(it) }
    }

    /**
     * Version code of the INSTALLED package.
     */
    fun installedVersionCode(pm: PackageManager, pkgName: String): Long {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            pm.getPackageInfo(pkgName, 0).longVersionCode
        } else {
            @Suppress("DEPRECATION")
            pm.getPackageInfo(pkgName, 0).versionCode.toLong()
        }
    }

    /**
     * SHA-256 digests of the signing certificates of the INSTALLED package.
     */
    fun installedSignerDigests(pm: PackageManager, pkgName: String): List<String> {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val info = pm.getPackageInfo(
                pkgName,
                PackageManager.GET_SIGNING_CERTIFICATES
            )
            val signingInfo = info.signingInfo
            val sigs = if (signingInfo == null) {
                emptyArray()
            } else if (signingInfo.hasMultipleSigners()) {
                signingInfo.apkContentsSigners
            } else {
                signingInfo.signingCertificateHistory
            }
            sigs.map { sig -> certSha256(sig) }
        } else {
            @Suppress("DEPRECATION")
            val info = pm.getPackageInfo(pkgName, PackageManager.GET_SIGNATURES)
            @Suppress("DEPRECATION")
            val sigs = info.signatures ?: emptyArray()
            sigs.map { sig -> certSha256(sig) }
        }
    }

    /**
     * SHA-256 digests of the signing certificates embedded in a parsed APK archive.
     */
    fun signerDigestsOf(archive: PackageInfo): List<String> {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val signingInfo = archive.signingInfo
            val sigs = if (signingInfo == null) {
                emptyArray()
            } else if (signingInfo.hasMultipleSigners()) {
                signingInfo.apkContentsSigners
            } else {
                signingInfo.signingCertificateHistory
            }
            sigs.map { sig -> certSha256(sig) }
        } else {
            @Suppress("DEPRECATION")
            val sigs = archive.signatures ?: emptyArray()
            sigs.map { sig -> certSha256(sig) }
        }
    }
}
