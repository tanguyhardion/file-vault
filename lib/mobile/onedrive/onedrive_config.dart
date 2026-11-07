/// Microsoft identity settings for the OneDrive (Graph) integration.
///
/// The client ID comes from an Azure app registration and is passed at build
/// time:
/// `flutter build apk --dart-define=ONEDRIVE_CLIENT_ID=<application-id>`.
/// It is a public-client identifier (no secret), so it is not sensitive.
class OneDriveConfig {
  OneDriveConfig._();

  static const clientId = String.fromEnvironment('ONEDRIVE_CLIENT_ID');

  /// Must match the `appAuthRedirectScheme` in android/app/build.gradle.kts
  /// and a "Mobile and desktop applications" redirect URI in Azure.
  static const redirectUrl = 'com.tanguyhardion.filevault://auth';

  /// `common` accepts both personal Microsoft accounts and work/school ones.
  static const _authority =
      'https://login.microsoftonline.com/common/oauth2/v2.0';
  static const authorizationEndpoint = '$_authority/authorize';
  static const tokenEndpoint = '$_authority/token';

  static const scopes = ['Files.ReadWrite', 'offline_access'];

  static const graphBaseUrl = 'https://graph.microsoft.com/v1.0';

  static bool get isConfigured => clientId.isNotEmpty;
}
