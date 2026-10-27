import 'package:supabase_flutter/supabase_flutter.dart';

/// Global shortcut to the initialized Supabase client.
SupabaseClient get supabase => Supabase.instance.client;

/// All Supabase related constants for AtMe (@Me).
///
/// You can hard-code your project values below, or pass them at build time:
/// flutter run --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///             --dart-define=SUPABASE_ANON_KEY=eyJhbGciOi...
class SupabaseConstants {
  SupabaseConstants._();

  // ---------------------------------------------------------------------------
  // Project credentials
  // ---------------------------------------------------------------------------
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://hnspdxdhebwvhkzfulir.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imhuc3BkeGRoZWJ3dmhremZ1bGlyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTI5MDcwMTcsImV4cCI6MjEwODQ4MzAxN30.SaNnIDm6pRC4eSiluRbhRaTvtARYYijyi70SIVJUVLg',
  );

  // ---------------------------------------------------------------------------
  // Tables
  // ---------------------------------------------------------------------------
  static const String profilesTable = 'profiles';
  static const String conversationsTable = 'conversations';
  static const String messagesTable = 'messages';

  // ---------------------------------------------------------------------------
  // Storage buckets
  // ---------------------------------------------------------------------------
  static const String voiceNotesBucket = 'voice-notes';
  static const String avatarsBucket = 'avatars';

  // ---------------------------------------------------------------------------
  // Message types
  // ---------------------------------------------------------------------------
  static const String messageTypeText = 'text';
  static const String messageTypeAudio = 'audio';

  /// Preview text stored in `conversations.last_message` for voice notes.
  static const String voiceMessagePreview = '🎵 رسالة صوتية';

  // ---------------------------------------------------------------------------
  // Profile columns that are safe to expose to OTHER users.
  // (email is intentionally excluded to protect privacy)
  // ---------------------------------------------------------------------------
  static const String publicProfileColumns =
      'id, username, display_name, avatar_url, bio, status_text, status_color, status_created_at, is_online, is_profile_discoverable, last_seen, created_at';

  /// Safe fallback columns when optional newer columns are not migrated yet.
  static const String fallbackPublicProfileColumns =
      'id, username, display_name, avatar_url, is_online, last_seen, created_at';

  // ---------------------------------------------------------------------------
  // Auth / validation
  // ---------------------------------------------------------------------------
  static const int otpLength = 6;
  static const int otpResendSeconds = 60;

  static const int usernameMinLength = 3;
  static const int usernameMaxLength = 20;

  /// Same rule as the SQL check constraint: `^[a-z0-9_]{3,20}$`
  static final RegExp usernameRegex = RegExp(r'^[a-z0-9_]{3,20}$');

  static final RegExp emailRegex =
      RegExp(r'^[\w.+\-]+@([\w\-]+\.)+[a-zA-Z]{2,}$');

  // ---------------------------------------------------------------------------
  // Audio
  // ---------------------------------------------------------------------------
  static const String voiceFileExtension = 'm4a';
  static const String voiceContentType = 'audio/mp4';
}
