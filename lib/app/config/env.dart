/// Build-time configuration passed with `--dart-define-from-file=env.json`.
///
/// Only the public Supabase URL and the anon (publishable) key may live in
/// the client: data access is protected by Row Level Security and by the
/// validated RPC functions in `supabase/migrations`. The service-role key
/// must never be added here.
abstract final class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Redirect target for password-reset e-mails (deep link or web URL).
  static const authRedirectUrl = String.fromEnvironment(
    'AUTH_REDIRECT_URL',
    defaultValue: 'io.liferpg.app://login-callback',
  );

  static bool get hasSupabase => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
