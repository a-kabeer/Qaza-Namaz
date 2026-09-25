package com.example.qaza_namaz_task1_flutter

import android.Manifest
import android.app.NotificationManager
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.Signature
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.security.MessageDigest

class MainActivity : FlutterFragmentActivity() {
    private companion object {
        const val CHANNEL = "qaza_namaz/notification_settings"
        const val SIGNING_CHANNEL = "qaza_namaz/signing_identity"
        const val QAZA_REMINDER_CHANNEL_ID = "qaza_daily_reminder_v2"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openNotificationSettings" -> {
                        result.success(openNotificationSettings())
                    }

                    "getNotificationPermissionState" -> {
                        result.success(getNotificationPermissionState())
                    }

                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SIGNING_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getSigningIdentity" -> result.success(getSigningIdentity())
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * The package name and signing certificate fingerprints of *this* build.
     *
     * Read from the installed package rather than from Gradle config, because
     * the question being answered is what Google Play services will actually
     * see when it matches the caller against a registered OAuth client. A
     * mismatch here is what surfaces on the device as "[16] Account reauth
     * failed" with no further explanation.
     */
    private fun getSigningIdentity(): Map<String, Any?> = try {
        val signatures = readSignatures()
        mapOf(
            "packageName" to packageName,
            "sha1" to signatures.map { fingerprint(it, "SHA-1") },
            "sha256" to signatures.map { fingerprint(it, "SHA-256") },
        )
    } catch (error: Exception) {
        // Never block sign-in over a failed self-inspection; the Dart side
        // treats an empty result as "cannot tell" and proceeds.
        mapOf(
            "packageName" to packageName,
            "sha1" to emptyList<String>(),
            "sha256" to emptyList<String>(),
        )
    }

    private fun readSignatures(): List<Signature> =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            @Suppress("DEPRECATION")
            val info = packageManager.getPackageInfo(
                packageName,
                PackageManager.GET_SIGNING_CERTIFICATES,
            )
            val signingInfo = info.signingInfo
            when {
                signingInfo == null -> emptyList()
                signingInfo.hasMultipleSigners() ->
                    signingInfo.apkContentsSigners?.toList() ?: emptyList()
                else ->
                    signingInfo.signingCertificateHistory?.toList() ?: emptyList()
            }
        } else {
            @Suppress("DEPRECATION")
            val info = packageManager.getPackageInfo(
                packageName,
                PackageManager.GET_SIGNATURES,
            )
            @Suppress("DEPRECATION")
            info.signatures?.filterNotNull() ?: emptyList()
        }

    private fun fingerprint(signature: Signature, algorithm: String): String {
        val digest = MessageDigest.getInstance(algorithm)
            .digest(signature.toByteArray())
        return digest.joinToString("") { byte -> "%02x".format(byte) }
    }

    private fun getNotificationPermissionState(): Map<String, Any> {
        val runtimePermission = Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU
        val runtimePermissionGranted = !runtimePermission ||
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
                PackageManager.PERMISSION_GRANTED
        val shouldShowRationale = runtimePermission &&
            !runtimePermissionGranted &&
            shouldShowRequestPermissionRationale(
                Manifest.permission.POST_NOTIFICATIONS,
            )

        return mapOf(
            "sdkInt" to Build.VERSION.SDK_INT,
            "runtimePermission" to runtimePermission,
            "runtimePermissionGranted" to runtimePermissionGranted,
            "shouldShowRationale" to shouldShowRationale,
        )
    }

    private fun openNotificationSettings(): Boolean = try {
        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager =
                getSystemService(NotificationManager::class.java)
            val channel = notificationManager?.getNotificationChannel(
                QAZA_REMINDER_CHANNEL_ID,
            )
            val appNotificationsEnabled =
                notificationManager?.areNotificationsEnabled() ?: true

            if (appNotificationsEnabled &&
                channel != null &&
                channel.importance == NotificationManager.IMPORTANCE_NONE
            ) {
                Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS)
                    .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                    .putExtra(
                        Settings.EXTRA_CHANNEL_ID,
                        QAZA_REMINDER_CHANNEL_ID,
                    )
            } else {
                Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                    .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
            }
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
        } else {
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                .setData(Uri.fromParts("package", packageName, null))
        }
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(intent)
        true
    } catch (error: Exception) {
        false
    }
}
