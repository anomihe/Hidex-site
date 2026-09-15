import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Boots the Supabase client from `.env` (see `.env.example`). Call once
/// in `main()` before `runApp`.
class SupabaseInit {
  SupabaseInit._();

  static Future<void> init() async {
    final url = dotenv.env['SUPABASE_URL'];
    final anonKey = dotenv.env['SUPABASE_ANON_KEY'];

    if (url == null || url.isEmpty || anonKey == null || anonKey.isEmpty) {
      throw StateError(
        'SUPABASE_URL / SUPABASE_ANON_KEY are missing. Copy '
        'flutter_app/.env.example to flutter_app/.env and fill in your '
        "project's values.",
      );
    }

    await Supabase.initialize(url: url, anonKey: anonKey);
  }
}

/// Shorthand accessor used throughout the app.
SupabaseClient get supabase => Supabase.instance.client;
