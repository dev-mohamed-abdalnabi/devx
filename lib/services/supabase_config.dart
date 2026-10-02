import 'package:supabase_flutter/supabase_flutter.dart';

/// مفاتيح العميل العامة فقط؛ الحماية الفعلية مضمونة عبر RLS في قاعدة البيانات.
class SupabaseConfig {
  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://zkpoduinzfxdftsxfxbj.supabase.co',
  );
  static const publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_0673NtJNyzRwTzf4PvzWxw_V1q37fkO',
  );
}

SupabaseClient get supabase => Supabase.instance.client;
