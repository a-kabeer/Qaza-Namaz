package com.qaza_namaz.com

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private companion object {
        const val CHANNEL = "qaza_namaz/location"
        const val LOCATION_SETTINGS_REQUEST_CODE = 2047
        const val LOCATION_PERMISSION_REQUEST_CODE = 2048
        const val LOCATION_TIMEOUT_MILLIS = 8_000L
    }

    private lateinit var locationManager: LocationManager
    private val mainHandler = Handler(Looper.getMainLooper())

    private var pendingSettingsResult: MethodChannel.Result? = null
    private var pendingPermissionResult: MethodChannel.Result? = null
    private var pendingLocationResult: MethodChannel.Result? = null
    private var locationListener: LocationListener? = null
    private var locationTimeout: Runnable? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        locationManager = getSystemService(LocationManager::class.java)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isLocationServiceEnabled" -> result.success(isLocationServiceEnabled())
                    "checkPermission" -> result.success(permissionState())
                    "requestPermission" -> requestLocationPermission(result)
                    "ensureLocationServices" -> ensureLocationServices(result)
                    "getCurrentLocation" -> getCurrentLocation(result)
                    "openAppSettings" -> openAppSettings(result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun isLocationServiceEnabled(): Boolean =
        locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER)

    private fun permissionState(): String {
        val fine = checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED
        val coarse =
            checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) ==
                PackageManager.PERMISSION_GRANTED

        return when {
            fine || coarse -> "whileInUse"
            else -> "denied"
        }
    }

    private fun requestLocationPermission(result: MethodChannel.Result) {
        if (pendingPermissionResult != null) {
            result.error("BUSY", "A location permission request is already active.", null)
            return
        }

        if (permissionState() != "denied") {
            result.success(permissionState())
            return
        }

        pendingPermissionResult = result
        requestPermissions(
            arrayOf(
                Manifest.permission.ACCESS_FINE_LOCATION,
                Manifest.permission.ACCESS_COARSE_LOCATION,
            ),
            LOCATION_PERMISSION_REQUEST_CODE,
        )
    }

    private fun ensureLocationServices(result: MethodChannel.Result) {
        if (isLocationServiceEnabled()) {
            result.success(true)
            return
        }

        if (pendingSettingsResult != null) {
            result.error("BUSY", "Location settings are already being resolved.", null)
            return
        }

        pendingSettingsResult = result
        try {
            startActivityForResult(
                Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS),
                LOCATION_SETTINGS_REQUEST_CODE,
            )
        } catch (_: Exception) {
            pendingSettingsResult = null
            result.success(false)
        }
    }

    private fun getCurrentLocation(result: MethodChannel.Result) {
        if (!isLocationServiceEnabled()) {
            result.error(
                "LOCATION_DISABLED",
                "Device GPS services are disabled.",
                null,
            )
            return
        }

        if (permissionState() == "denied") {
            result.error(
                "PERMISSION_REQUIRED",
                "Location permission is required.",
                null,
            )
            return
        }

        if (pendingLocationResult != null) {
            result.error("BUSY", "A location request is already active.", null)
            return
        }

        val listener = object : LocationListener {
            override fun onLocationChanged(location: Location) {
                finishLocation(
                    success = mapOf(
                        "latitude" to location.latitude,
                        "longitude" to location.longitude,
                    ),
                )
            }
        }

        pendingLocationResult = result
        locationListener = listener
        locationTimeout = Runnable {
            finishLocation(
                errorCode = "LOCATION_TIMEOUT",
                errorMessage = "Unable to obtain a GPS location in time.",
            )
        }

        try {
            locationManager.requestLocationUpdates(
                LocationManager.GPS_PROVIDER,
                0L,
                0f,
                listener,
                Looper.getMainLooper(),
            )
            mainHandler.postDelayed(locationTimeout!!, LOCATION_TIMEOUT_MILLIS)
        } catch (error: SecurityException) {
            finishLocation(
                errorCode = "PERMISSION_REQUIRED",
                errorMessage = error.message ?: "Location permission is required.",
            )
        } catch (error: Exception) {
            finishLocation(
                errorCode = "LOCATION_ERROR",
                errorMessage = error.message ?: "Unable to obtain device location.",
            )
        }
    }

    private fun finishLocation(
        success: Map<String, Any?>? = null,
        errorCode: String? = null,
        errorMessage: String? = null,
    ) {
        locationTimeout?.let(mainHandler::removeCallbacks)
        locationTimeout = null

        locationListener?.let { listener ->
            try {
                locationManager.removeUpdates(listener)
            } catch (_: Exception) {
                // Best-effort cleanup.
            }
        }
        locationListener = null

        val result = pendingLocationResult ?: return
        pendingLocationResult = null

        when {
            success != null -> result.success(success)
            errorCode != null -> result.error(errorCode, errorMessage, null)
            else -> result.success(null)
        }
    }

    private fun openAppSettings(result: MethodChannel.Result) {
        try {
            val intent = Intent(
                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                Uri.parse("package:$packageName"),
            )
            startActivity(intent)
            result.success(true)
        } catch (_: Exception) {
            result.success(false)
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)

        if (requestCode != LOCATION_PERMISSION_REQUEST_CODE) return

        val result = pendingPermissionResult ?: return
        pendingPermissionResult = null

        val granted = grantResults.any { it == PackageManager.PERMISSION_GRANTED }
        if (granted) {
            result.success("whileInUse")
            return
        }

        val permanentlyDenied =
            permissions.indices.any { index ->
                grantResults.getOrNull(index) == PackageManager.PERMISSION_DENIED &&
                    !shouldShowRequestPermissionRationale(permissions[index])
            }

        result.success(if (permanentlyDenied) "deniedForever" else "denied")
    }

    override fun onActivityResult(
        requestCode: Int,
        resultCode: Int,
        data: Intent?,
    ) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode != LOCATION_SETTINGS_REQUEST_CODE) return

        val result = pendingSettingsResult ?: return
        pendingSettingsResult = null
        result.success(isLocationServiceEnabled())
    }

    override fun onDestroy() {
        finishLocation(
            errorCode = "ACTIVITY_DESTROYED",
            errorMessage = "The activity was destroyed while locating the device.",
        )
        super.onDestroy()
    }
}
