import 'dart:convert';

/// A single status item inside a user's 24-hour WhatsApp-style status story.
class StatusSegmentItem {
  const StatusSegmentItem({
    required this.id,
    required this.text,
    required this.colorHex,
    required this.createdAt,
    this.imageBase64,
  });

  final String id;
  final String text;
  final String colorHex;
  final DateTime createdAt;
  final String? imageBase64;

  bool get hasImage => imageBase64 != null && imageBase64!.trim().isNotEmpty;

  bool get isActive => DateTime.now().difference(createdAt).inHours < 24;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'text': text,
        'color': colorHex,
        'created_at': createdAt.toUtc().toIso8601String(),
        if (imageBase64 != null) 'img': imageBase64,
      };

  factory StatusSegmentItem.fromJson(Map<String, dynamic> json) {
    return StatusSegmentItem(
      id: (json['id'] as String?) ?? '${DateTime.now().millisecondsSinceEpoch}',
      text: (json['text'] as String?) ?? '',
      colorHex: (json['color'] as String?) ?? '#123D91',
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString())
              ?.toLocal() ??
          DateTime.now(),
      imageBase64: json['img'] as String?,
    );
  }
}

/// A user profile row from `public.profiles`.
///
/// `email` is nullable on purpose: when loading OTHER users we only select
/// public columns (see `SupabaseConstants.publicProfileColumns`) so the email
/// is never exposed in search results or chats.
class ProfileModel {
  const ProfileModel({
    required this.id,
    required this.username,
    required this.displayName,
    this.email,
    this.avatarUrl,
    this.bio = '',
    this.statusText = '',
    this.statusColor = '#0D9488',
    this.statusCreatedAt,
    this.isOnline = false,
    this.isProfileDiscoverable = true,
    this.lastSeen,
    this.createdAt,
  });

  final String id;
  final String? email;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final String bio;

  /// Written status / note (similar to 24-hour text statuses).
  final String statusText;

  /// Hex color string for the written status card (e.g. `#0D9488`).
  final String statusColor;

  /// Timestamp when the written status was posted.
  final DateTime? statusCreatedAt;

  final bool isOnline;
  final bool isProfileDiscoverable;
  final DateTime? lastSeen;
  final DateTime? createdAt;

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// `@username`
  String get handle => '@$username';

  bool get hasAvatar => avatarUrl != null && avatarUrl!.trim().isNotEmpty;

  bool get isComplete => username.trim().isNotEmpty;

  /// Parses all active 24h status segments for this user.
  /// Supports both multi-segment JSON array (`[{"id":...}]`) and legacy single-string status.
  List<StatusSegmentItem> get statusSegments {
    final String raw = statusText.trim();
    if (raw.isEmpty) return <StatusSegmentItem>[];

    if (raw.startsWith('[') && raw.endsWith(']')) {
      try {
        final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
        final List<StatusSegmentItem> parsed = decoded
            .whereType<Map<String, dynamic>>()
            .map(StatusSegmentItem.fromJson)
            .where((StatusSegmentItem s) => s.isActive && (s.text.trim().isNotEmpty || s.hasImage))
            .toList();
        return parsed;
      } catch (_) {}
    }

    // Legacy single status fallback
    if (statusCreatedAt != null &&
        DateTime.now().difference(statusCreatedAt!).inHours >= 24) {
      return <StatusSegmentItem>[];
    }
    return <StatusSegmentItem>[
      StatusSegmentItem(
        id: 'legacy_${statusCreatedAt?.millisecondsSinceEpoch ?? 0}',
        text: raw,
        colorHex: statusColor,
        createdAt: statusCreatedAt ?? DateTime.now(),
      ),
    ];
  }

  /// Latest status segment for preview cards and rings.
  StatusSegmentItem? get latestStatusSegment =>
      statusSegments.isNotEmpty ? statusSegments.last : null;

  /// Clean display text of the latest status segment (never raw JSON).
  String get latestStatusDisplayText {
    final StatusSegmentItem? latest = latestStatusSegment;
    if (latest == null) return '';
    if (latest.text.trim().isNotEmpty) return latest.text.trim();
    if (latest.hasImage) return '📷 صورة في الحالة';
    return '';
  }

  /// Color of the latest status segment.
  String get latestStatusColor =>
      latestStatusSegment?.colorHex ?? statusColor;

  /// Timestamp of the latest status segment.
  DateTime? get latestStatusTime =>
      latestStatusSegment?.createdAt ?? statusCreatedAt;

  /// True when the user has at least one active status segment within 24 hours.
  bool get hasActiveStatus => statusSegments.isNotEmpty;

  /// Short private invite code derived from user's UUID (first 8 hex characters uppercase)
  /// used to add friends even when `isProfileDiscoverable == false`.
  String get privateInviteCode {
    final String clean = id.replaceAll('-', '').toUpperCase();
    return clean.length >= 8 ? clean.substring(0, 8) : clean;
  }

  /// Private friend invite link (`atme://friend/{id}?code={code}`).
  String get privateInviteLink => 'https://atme.app/add/$id';

  /// First letter(s) used as avatar placeholder.
  String get initials {
    final List<String> parts = displayName
        .trim()
        .split(RegExp(r'\s+'))
        .where((String p) => p.isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      return username.isNotEmpty ? username[0].toUpperCase() : '?';
    }
    if (parts.length == 1) {
      return parts.first.firstChar.toUpperCase();
    }
    return '${parts[0].firstChar}${parts[1].firstChar}'.toUpperCase();
  }

  // ---------------------------------------------------------------------------
  // Serialization
  // ---------------------------------------------------------------------------

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id'] as String,
      email: json['email'] as String?,
      username: (json['username'] as String?) ?? '',
      displayName: (json['display_name'] as String?) ?? '',
      avatarUrl: json['avatar_url'] as String?,
      bio: (json['bio'] as String?) ?? '',
      statusText: (json['status_text'] as String?) ?? '',
      statusColor: (json['status_color'] as String?) ?? '#0D9488',
      statusCreatedAt: _parseDate(json['status_created_at']),
      isOnline: (json['is_online'] as bool?) ?? false,
      isProfileDiscoverable:
          (json['is_profile_discoverable'] as bool?) ?? true,
      lastSeen: _parseDate(json['last_seen']),
      createdAt: _parseDate(json['created_at']),
    );
  }

  /// Full row (used when caching or creating the current user's own profile).
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      if (email != null) 'email': email,
      'username': username,
      'display_name': displayName,
      'avatar_url': avatarUrl,
      'bio': bio,
      'status_text': statusText,
      'status_color': statusColor,
      if (statusCreatedAt != null)
        'status_created_at': statusCreatedAt!.toUtc().toIso8601String(),
      'is_online': isOnline,
      'is_profile_discoverable': isProfileDiscoverable,
      if (lastSeen != null) 'last_seen': lastSeen!.toUtc().toIso8601String(),
      if (createdAt != null) 'created_at': createdAt!.toUtc().toIso8601String(),
    };
  }

  ProfileModel copyWith({
    String? id,
    String? email,
    String? username,
    String? displayName,
    String? avatarUrl,
    String? bio,
    String? statusText,
    String? statusColor,
    DateTime? statusCreatedAt,
    bool? isOnline,
    bool? isProfileDiscoverable,
    DateTime? lastSeen,
    DateTime? createdAt,
  }) {
    return ProfileModel(
      id: id ?? this.id,
      email: email ?? this.email,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      statusText: statusText ?? this.statusText,
      statusColor: statusColor ?? this.statusColor,
      statusCreatedAt: statusCreatedAt ?? this.statusCreatedAt,
      isOnline: isOnline ?? this.isOnline,
      isProfileDiscoverable:
          isProfileDiscoverable ?? this.isProfileDiscoverable,
      lastSeen: lastSeen ?? this.lastSeen,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value.toLocal();
    return DateTime.tryParse(value.toString())?.toLocal();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProfileModel &&
          other.id == id &&
          other.username == username &&
          other.displayName == displayName &&
          other.avatarUrl == avatarUrl &&
          other.bio == bio &&
          other.statusText == statusText &&
          other.statusColor == statusColor &&
          other.statusCreatedAt == statusCreatedAt &&
          other.isOnline == isOnline &&
          other.isProfileDiscoverable == isProfileDiscoverable &&
          other.lastSeen == lastSeen;

  @override
  int get hashCode => Object.hash(
        id,
        username,
        displayName,
        avatarUrl,
        bio,
        statusText,
        statusColor,
        statusCreatedAt,
        isOnline,
        isProfileDiscoverable,
        lastSeen,
      );

  @override
  String toString() => 'ProfileModel($handle, $displayName, online: $isOnline)';
}

extension _FirstChar on String {
  /// First code point (safe for Arabic letters & emoji surrogate pairs).
  String get firstChar {
    if (isEmpty) return '';
    final int rune = runes.first;
    return String.fromCharCode(rune);
  }
}
