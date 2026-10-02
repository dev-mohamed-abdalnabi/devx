import 'package:supabase_flutter/supabase_flutter.dart';

/// Public client configuration. Inject fresh values at build time; never commit keys.
class SupabaseConfig {
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const publishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  static bool get isConfigured => url.startsWith('https://') && publishableKey.isNotEmpty;

  static void validate() {
    if (!isConfigured) {
      throw StateError(
        'Supabase is not configured. Build with --dart-define=SUPABASE_URL=... '
        'and --dart-define=SUPABASE_PUBLISHABLE_KEY=...',
      );
    }
  }
}

SupabaseClient get supabase => Supabase.instance.client;
