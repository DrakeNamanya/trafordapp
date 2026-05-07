import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String url = 'https://ibigvmkybuejciykbqbg.supabase.co';
  static const String anonKey = 'sb_publishable_L6bVDZ5_Wzmr76-jybcddQ_lj1QQMqP';

  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
    );
  }
}
