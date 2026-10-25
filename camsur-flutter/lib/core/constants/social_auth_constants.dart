/// Fill these in once Google/Apple sign-in are configured in the Supabase
/// dashboard and your own Google Cloud / Apple Developer accounts.
abstract final class SocialAuthConstants {
  SocialAuthConstants._();

  /// Google Cloud Console → APIs & Services → Credentials → the **Web
  /// application** OAuth client ID (not the Android/iOS one). This is what
  /// makes the ID token's audience match what Supabase's Google provider
  /// expects, regardless of which platform signed the user in.
  static const googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: '',
  );

  /// The **iOS** OAuth client ID (from `GoogleService-Info.plist`'s
  /// `CLIENT_ID`). Required on iOS/macOS even when passing IDs via Dart —
  /// the matching `CFBundleURLTypes` reversed-client-id URL scheme in
  /// Info.plist is still separately required (see ios/Runner/Info.plist).
  static const googleIosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
    defaultValue: '',
  );
}
