/// Supabase project connection details for the license backend.
///
/// The anon key is safe to embed: Row Level Security blocks it from reading
/// or writing the `licenses` table directly, it can only call the two RPCs
/// (`request_activation`, `check_license`). Overridable via `--dart-define`
/// (same pattern as `MUSIC_SDK_LICENSE_KEY`) for pointing at a different
/// project without a code change.
abstract final class SupabaseConfig {
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://iddtvvqdofgljuxtzgpj.supabase.co',
  );

  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlkZHR2dnFkb2ZnbGp1eHR6Z3BqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODUxNDg0NDAsImV4cCI6MjEwMDcyNDQ0MH0.TJ34cqKoNgJIZ_ehC4WLXDjr0e_lAQUmPsJ5HTIDGG8',
  );
}
