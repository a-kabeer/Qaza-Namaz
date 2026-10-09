package com.qaza_namaz.com

import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.LocationSettingsRequest
import com.google.android.gms.location.Priority
import com.google.android.gms.common.api.ResolvableApiException
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private companion object {
        const val LOCATION_SETTINGS_CHANNEL = "qaza_namaz/location_settings"
        const val LOCATION_SETTINGS_REQUEST_CODE = 2047
    }

    private var pendingLocationSettingsResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LOCATION_SETTINGS_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "ensureLocationServices" -> ensureLocationServices(result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun ensureLocationServices(result: MethodChannel.Result) {
        if (pendingLocationSettingsResult != null) {
            result.success(false)
            return
        }

        val request = LocationRequest.Builder(
            Priority.PRIORITY_BALANCED_POWER_ACCURACY,
            10_000L,
        ).setMinUpdateIntervalMillis(5_000L).build()

        val settingsRequest = LocationSettingsRequest.Builder()
            .addLocationRequest(request)
            .setAlwaysShow(true)
            .build()

        LocationServices.getSettingsClient(this)
            .checkLocationSettings(settingsRequest)
            .addOnSuccessListener {
                result.success(true)
            }
            .addOnFailureListener { error ->
                if (error is ResolvableApiException) {
                    pendingLocationSettingsResult = result
                    try {
                        @Suppress("DEPRECATION")
                        error.startResolutionForResult(
                            this,
                            LOCATION_SETTINGS_REQUEST_CODE,
                        )
                    } catch (_: Exception) {
                        pendingLocationSettingsResult = null
                        result.success(false)
                    }
                } else {
                    result.success(false)
                }
            }
    }

    @Suppress("DEPRECATION")
    override fun onActivityResult(
        requestCode: Int,
        resultCode: Int,
        data: android.content.Intent?,
    ) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != LOCATION_SETTINGS_REQUEST_CODE) return

        val result = pendingLocationSettingsResult ?: return
        pendingLocationSettingsResult = null
        result.success(resultCode == RESULT_OK)
    }


}
