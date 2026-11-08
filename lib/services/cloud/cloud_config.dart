/// Supabase project the vaults are stored in.
///
/// Defaults to the project's own database. Override at build time with
/// `--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_KEY=...`.
/// The key is the project's publishable (anon) key: it is meant to ship in
/// apps, and row-level security limits each account to its own rows.
class CloudConfig {
  CloudConfig._();

  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://luegdvgoxhomsldotdqv.supabase.co',
  );
  static const publishableKey = String.fromEnvironment(
    'SUPABASE_KEY',
    defaultValue: 'sb_publishable_7LeZ-Mpqt1X6ohdXemVaFw_EIYnaaUH',
  );

  static bool get isConfigured => url.isNotEmpty && publishableKey.isNotEmpty;
}
