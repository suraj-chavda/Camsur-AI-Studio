import 'dart:convert';
import 'dart:io' show Platform;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../core/constants/social_auth_constants.dart';

/// Result of a native social sign-in, ready to send to `POST /auth/social`.
class SocialSignInResult {
  const SocialSignInResult({
    required this.provider,
    required this.idToken,
    this.nonce,
  });

  final String provider; // 'google' | 'apple'
  final String idToken;
  final String? nonce;
}

/// The user closed the native sign-in sheet — not a real error, don't show one.
class SocialSignInCancelled implements Exception {}

/// Wraps the native Google/Apple SDKs. Backend only ever sees the resulting
/// ID token (and, for Apple, the raw nonce) — it forwards that to Supabase's
/// `sign_in_with_id_token`, which does the actual provider verification.
class SocialAuthSource {
  bool _googleReady = false;

  Future<void> _ensureGoogleInitialized() async {
    if (_googleReady) return;
    final isApplePlatform = !kIsWeb && (Platform.isIOS || Platform.isMacOS);
    await GoogleSignIn.instance.initialize(
      clientId:
          isApplePlatform && SocialAuthConstants.googleIosClientId.isNotEmpty
          ? SocialAuthConstants.googleIosClientId
          : null,
      serverClientId: SocialAuthConstants.googleServerClientId.isEmpty
          ? null
          : SocialAuthConstants.googleServerClientId,
    );
    _googleReady = true;
  }

  Future<SocialSignInResult> signInWithGoogle() async {
    await _ensureGoogleInitialized();
    try {
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw StateError('Google sign-in did not return an ID token');
      }
      return SocialSignInResult(provider: 'google', idToken: idToken);
    } on GoogleSignInException catch (e) {
      // Android's Credential Manager can return "canceled" for real user
      // cancels AND for config problems (bad SHA-1/package/serverClientId,
      // OAuth consent screen still in Testing with this account not added
      // as a test user, etc.) — the plugin can't tell them apart. Log the
      // full detail so a false "cancel" is diagnosable instead of silent.
      debugPrint(
        'GoogleSignInException: code=${e.code} description=${e.description} details=${e.details}',
      );
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw SocialSignInCancelled();
      }
      rethrow;
    }
  }

  Future<SocialSignInResult> signInWithApple() async {
    // Apple embeds the *hash* of this nonce in the identity token; Supabase
    // verifies it by hashing the raw nonce we send alongside the token.
    final rawNonce = generateNonce();
    final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );
      final idToken = credential.identityToken;
      if (idToken == null || idToken.isEmpty) {
        throw StateError('Apple sign-in did not return an identity token');
      }
      return SocialSignInResult(
        provider: 'apple',
        idToken: idToken,
        nonce: rawNonce,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        throw SocialSignInCancelled();
      }
      rethrow;
    }
  }
}
