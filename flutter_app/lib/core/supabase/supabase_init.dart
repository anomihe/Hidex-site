import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Boots the Supabase client from `.env` (see `.env.example`). Call once
/// in `main()` before `runApp`.
class SupabaseInit {
  SupabaseInit._();

  static Future<void> init() async {
    final url = dotenv.env['SUPABASE_URL'];
    // Supabase's newer "publishable key" format (sb_publishable_...) is
    // interchangeable with the legacy anon key for client init — same
    // env var name kept so `.env` doesn't need renaming later.
    final publishableKey = dotenv.env['SUPABASE_ANON_KEY'];

    if (url == null || url.isEmpty || publishableKey == null || publishableKey.isEmpty) {
      throw StateError(
        'SUPABASE_URL / SUPABASE_ANON_KEY are missing. Copy '
        'flutter_app/.env.example to flutter_app/.env and fill in your '
        "project's values.",
      );
    }

    await Supabase.initialize(url: url, publishableKey: publishableKey);
  }
}

/// Shorthand accessor used throughout the app.
SupabaseClient get supabase => Supabase.instance.client;
