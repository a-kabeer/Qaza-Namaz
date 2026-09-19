package com.example.qaza_namaz_task1_flutter

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private companion object {
        const val CHANNEL = "qaza_namaz/notification_settings"
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
    }

    private fun getNotificationPermissionState(): Map<String, Any> {
        val runtimePermission = Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU
        val shouldShowRationale = runtimePermission &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
                PackageManager.PERMISSION_GRANTED &&
            shouldShowRequestPermissionRationale(
                Manifest.permission.POST_NOTIFICATIONS,
            )

        return mapOf(
            "sdkInt" to Build.VERSION.SDK_INT,
            "runtimePermission" to runtimePermission,
            "shouldShowRationale" to shouldShowRationale,
        )
    }

    private fun openNotificationSettings(): Boolean = try {
        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
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
