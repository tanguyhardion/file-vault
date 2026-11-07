/// Supabase project the vaults are stored in.
///
/// Override at build time with
/// `--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_KEY=...`.
/// The key is the project's publishable (anon) key: it is meant to ship in
/// apps, and row-level security limits each account to its own rows.
class CloudConfig {
  CloudConfig._();

  static const url = String.fromEnvironment('SUPABASE_URL');
  static const publishableKey = String.fromEnvironment('SUPABASE_KEY');

  static bool get isConfigured => url.isNotEmpty && publishableKey.isNotEmpty;
}
