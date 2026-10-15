package com.qaza_namaz.cloud_adapter

import android.accounts.Account
import android.content.Context
import com.google.android.gms.auth.api.identity.AuthorizationRequest
import com.google.android.gms.auth.api.identity.ClearTokenRequest
import com.google.android.gms.auth.api.identity.Identity
import com.google.android.gms.common.api.Scope
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Provides a strictly non-interactive Drive authorization path usable by the
 * Flutter WorkManager engine. The channel never launches an authorization
 * resolution; callers must send the user back to the foreground to reconnect.
 *
 * Access tokens are returned only to the requesting Dart runtime and are never
 * persisted by this plugin.
 */
class QazaCloudAdapterPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private var appContext: Context? = null
    private var channel: MethodChannel? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        channel = MethodChannel(
            binding.binaryMessenger,
            CHANNEL_NAME,
        ).also { it.setMethodCallHandler(this) }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        appContext = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "authorizeDriveSilently" -> authorizeDriveSilently(call, result)
            "clearAuthorizationToken" -> clearAuthorizationToken(call, result)
            else -> result.notImplemented()
        }
    }

    private fun authorizeDriveSilently(call: MethodCall, result: MethodChannel.Result) {
        val context = appContext
        val accountId = call.argument<String>("accountId")?.trim()
        val accountEmail = call.argument<String>("accountEmail")?.trim()
        if (context == null ||
            accountId.isNullOrEmpty() ||
            accountEmail.isNullOrEmpty()
        ) {
            result.success(
                mapOf(
                    "status" to "unavailable",
                    "message" to "The Android authorization context or connected account is unavailable.",
                ),
            )
            return
        }

        // Target the account the foreground user explicitly connected. The
        // cached email selects the account; only a freshly returned access token
        // and granted scope prove that the native authorization is usable.
        val request = AuthorizationRequest.builder()
            .setAccount(Account(accountEmail, GOOGLE_ACCOUNT_TYPE))
            .setRequestedScopes(listOf(Scope(DRIVE_APPDATA_SCOPE)))
            .build()

        try {
            Identity.getAuthorizationClient(context)
                .authorize(request)
                .addOnSuccessListener { authorization ->
                    // A resolution is deliberately not launched here. This
                    // method may be called by WorkManager with no Activity.
                    if (authorization.hasResolution()) {
                        result.success(mapOf("status" to "interactionRequired"))
                        return@addOnSuccessListener
                    }

                    val accessToken = authorization.accessToken
                    val grantedScopes = authorization.grantedScopes

                    // AuthorizationResult can provide the Google account
                    // represented by this authorization. Validate its stable
                    // Google ID as well as the email used to target the native
                    // account. A cached email alone must never select a
                    // different sync-state namespace.
                    @Suppress("DEPRECATION")
                    val authorizedAccount = authorization.toGoogleSignInAccount()
                    val authorizedAccountId = authorizedAccount?.id?.trim()
                    val authorizedEmail = authorizedAccount?.email?.trim()

                    if (accessToken.isNullOrBlank() ||
                        !grantedScopes.contains(DRIVE_APPDATA_SCOPE)
                    ) {
                        result.success(mapOf("status" to "interactionRequired"))
                        return@addOnSuccessListener
                    }
                    val hasAuthorizedAccountId = !authorizedAccountId.isNullOrEmpty()
                    val hasAuthorizedEmail = !authorizedEmail.isNullOrEmpty()
                    val emailMatches = hasAuthorizedEmail &&
                        authorizedEmail.equals(accountEmail, ignoreCase = true)

                    // AuthorizationResult's deprecated GoogleSignInAccount can
                    // omit the stable ID because this is an authorization-only
                    // request, not a Google Sign-In ID request. The Android
                    // AuthorizationRequest is explicitly pinned to Account(email).
                    // If a native ID is present, require an exact ID match; if it
                    // is absent, require the returned email to match the pinned
                    // account. Never accept a result with no identity data or
                    // contradictory identity claims.
                    if ((hasAuthorizedAccountId && authorizedAccountId != accountId) ||
                        (hasAuthorizedEmail && !emailMatches) ||
                        (!hasAuthorizedAccountId && !hasAuthorizedEmail)
                    ) {
                        result.success(
                            mapOf(
                                "status" to "accountMismatch",
                                "message" to "Google Drive authorization did not confirm the previously connected Google account.",
                            ),
                        )
                        return@addOnSuccessListener
                    }

                    val identitySource = if (hasAuthorizedAccountId) {
                        "googleId"
                    } else {
                        "targetAccountEmail"
                    }
                    result.success(
                        mapOf(
                            "status" to "authorized",
                            // For the email-only fallback, the stable ID is the
                            // previously verified ID bound to this exact target
                            // email, not a newly inferred native ID.
                            "accountId" to (authorizedAccountId ?: accountId),
                            "accountEmail" to (authorizedEmail ?: accountEmail),
                            "identitySource" to identitySource,
                            "accessToken" to accessToken,
                            "grantedScopes" to grantedScopes,
                        ),
                    )
                }
                .addOnFailureListener { error ->
                    // Distinguish a transient/SDK failure from missing consent.
                    // WorkManager can retry failures; missing consent must be
                    // resolved by a user-initiated foreground action.
                    result.success(
                        mapOf(
                            "status" to "unavailable",
                            "message" to (
                                error.message
                                    ?: "Google Drive authorization is temporarily unavailable."
                            ),
                        ),
                    )
                }
        } catch (error: Exception) {
            result.success(
                mapOf(
                    "status" to "unavailable",
                    "message" to (
                        error.message
                            ?: "Google Drive authorization is temporarily unavailable."
                    ),
                ),
            )
        }
    }

    private fun clearAuthorizationToken(
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        val context = appContext
        val accessToken = call.argument<String>("accessToken")
        if (context == null || accessToken.isNullOrBlank()) {
            result.error(
                "INVALID_TOKEN",
                "A token is required to clear the native authorization cache.",
                null,
            )
            return
        }

        try {
            Identity.getAuthorizationClient(context)
                .clearToken(ClearTokenRequest.builder().setToken(accessToken).build())
                .addOnSuccessListener { result.success(null) }
                .addOnFailureListener { error ->
                    result.error(
                        "TOKEN_CLEAR_FAILED",
                        error.message ?: "Google authorization token cache could not be cleared.",
                        null,
                    )
                }
        } catch (error: Exception) {
            result.error(
                "TOKEN_CLEAR_FAILED",
                error.message ?: "Google authorization token cache could not be cleared.",
                null,
            )
        }
    }

    private companion object {
        const val CHANNEL_NAME = "qaza_cloud_adapter/google_drive_authorization"
        const val GOOGLE_ACCOUNT_TYPE = "com.google"
        const val DRIVE_APPDATA_SCOPE =
            "https://www.googleapis.com/auth/drive.appdata"
    }
}
