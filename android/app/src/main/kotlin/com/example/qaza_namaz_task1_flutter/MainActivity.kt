package com.example.qaza_namaz_task1_flutter

import android.content.pm.PackageManager
import android.content.pm.Signature
import android.os.Build
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.security.MessageDigest

class MainActivity : FlutterFragmentActivity() {
    private companion object {
        const val SIGNING_CHANNEL = "qaza_namaz/signing_identity"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
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


}
