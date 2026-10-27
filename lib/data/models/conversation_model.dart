import 'dart:convert';

import '../../core/constants/supabase_constants.dart';
import 'profile_model.dart';

/// Metadata for a Group Conversation, stored either in dedicated columns on
/// `public.conversations` (`is_group`, `group_name`, etc.) OR transparently
/// serialized inside a `__ATME_GROUP__` metadata envelope when the remote
/// database has not run the group migration yet.
class GroupChatMeta {
  const GroupChatMeta({
    required this.name,
    this.description = '',
    this.avatarUrl,
    required this.ownerId,
    required this.adminIds,
    required this.memberIds,
    this.onlyAdminsCanSend = false,
    this.onlyAdminsCanEditInfo = true,
    this.onlyAdminsCanAddMembers = false,
    this.inviteCode = '',
  });

  final String name;
  final String description;
  final String? avatarUrl;
  final String ownerId;
  final List<String> adminIds;
  final List<String> memberIds;
  final bool onlyAdminsCanSend;
  final bool onlyAdminsCanEditInfo;
  final bool onlyAdminsCanAddMembers;
  final String inviteCode;

  bool isOwner(String? userId) => userId != null && userId == ownerId;

  bool isAdmin(String? userId) =>
      userId != null && (userId == ownerId || adminIds.contains(userId));

  bool isMember(String? userId) =>
      userId != null &&
      (userId == ownerId ||
          adminIds.contains(userId) ||
          memberIds.contains(userId));

  bool canUserSend(String? userId) {
    if (!isMember(userId)) return false;
    if (onlyAdminsCanSend) return isAdmin(userId);
    return true;
  }

  bool canUserEditInfo(String? userId) {
    if (!isMember(userId)) return false;
    if (onlyAdminsCanEditInfo) return isAdmin(userId);
    return true;
  }

  bool canUserAddMembers(String? userId) {
    if (!isMember(userId)) return false;
    if (onlyAdminsCanAddMembers) return isAdmin(userId);
    return true;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'description': description,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
        'owner_id': ownerId,
        'admin_ids': adminIds,
        'member_ids': memberIds,
        'only_admins_can_send': onlyAdminsCanSend,
        'only_admins_can_edit': onlyAdminsCanEditInfo,
        'only_admins_can_add': onlyAdminsCanAddMembers,
        'invite_code': inviteCode,
      };

  factory GroupChatMeta.fromJson(Map<String, dynamic> json) {
    final List<String> admins = (json['admin_ids'] as List<dynamic>? ??
            json['group_admins'] as List<dynamic>? ??
            const <dynamic>[])
        .map((dynamic e) => e.toString())
        .toList();
    final List<String> members = (json['member_ids'] as List<dynamic>? ??
            json['group_members'] as List<dynamic>? ??
            const <dynamic>[])
        .map((dynamic e) => e.toString())
        .toList();
    final String owner =
        (json['owner_id'] ?? json['group_owner_id'] ?? '').toString();
    if (owner.isNotEmpty && !admins.contains(owner)) {
      admins.insert(0, owner);
    }
    for (final String a in admins) {
      if (a.isNotEmpty && !members.contains(a)) {
        members.add(a);
      }
    }

    return GroupChatMeta(
      name: (json['name'] ?? json['group_name'] ?? '').toString(),
      description:
          (json['description'] ?? json['group_description'] ?? '').toString(),
      avatarUrl: (json['avatar_url'] ?? json['group_avatar_url']) as String?,
      ownerId: owner,
      adminIds: admins,
      memberIds: members,
      onlyAdminsCanSend:
          (json['only_admins_can_send'] as bool?) ?? false,
      onlyAdminsCanEditInfo:
          (json['only_admins_can_edit'] as bool?) ?? true,
      onlyAdminsCanAddMembers:
          (json['only_admins_can_add'] as bool?) ?? false,
      inviteCode:
          (json['invite_code'] ?? json['group_invite_code'] ?? '').toString(),
    );
  }

  GroupChatMeta copyWith({
    String? name,
    String? description,
    String? avatarUrl,
    String? ownerId,
    List<String>? adminIds,
    List<String>? memberIds,
    bool? onlyAdminsCanSend,
    bool? onlyAdminsCanEditInfo,
    bool? onlyAdminsCanAddMembers,
    String? inviteCode,
  }) {
    return GroupChatMeta(
      name: name ?? this.name,
      description: description ?? this.description,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      ownerId: ownerId ?? this.ownerId,
      adminIds: adminIds ?? this.adminIds,
      memberIds: memberIds ?? this.memberIds,
      onlyAdminsCanSend: onlyAdminsCanSend ?? this.onlyAdminsCanSend,
      onlyAdminsCanEditInfo:
          onlyAdminsCanEditInfo ?? this.onlyAdminsCanEditInfo,
      onlyAdminsCanAddMembers:
          onlyAdminsCanAddMembers ?? this.onlyAdminsCanAddMembers,
      inviteCode: inviteCode ?? this.inviteCode,
    );
  }
}

/// A 1-on-1 OR Group conversation row from `public.conversations`.
///
/// [otherUser], [groupMemberProfiles], [lastMessageIsRead] and [unreadCount]
/// are filled by the controllers (home / search / chat) for the UI.
class ConversationModel {
  const ConversationModel({
    required this.id,
    required this.user1Id,
    required this.user2Id,
    required this.lastMessageAt,
    this.lastMessage = '',
    this.lastMessageType = SupabaseConstants.messageTypeText,
    this.lastMessageSenderId,
    this.createdAt,
    this.otherUser,
    this.lastMessageIsRead = false,
    this.unreadCount = 0,
    this.isPinned = false,
    this.isMuted = false,
    this.isGroup = false,
    this.groupMeta,
    this.groupMemberProfiles = const <ProfileModel>[],
  });

  final String id;
  final String user1Id;
  final String user2Id;
  final String lastMessage;
  final String lastMessageType;
  final String? lastMessageSenderId;
  final DateTime lastMessageAt;
  final DateTime? createdAt;

  // ---- Group fields ---------------------------------------------------------
  final bool isGroup;
  final GroupChatMeta? groupMeta;
  final List<ProfileModel> groupMemberProfiles;

  // ---- UI-only fields -------------------------------------------------------
  final ProfileModel? otherUser;
  final bool lastMessageIsRead;
  final int unreadCount;
  final bool isPinned;
  final bool isMuted;

  static const String _groupEnvelopePrefix = '__ATME_GRP__:';

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Display title of this conversation (Group Name OR Other User Display Name).
  String get title {
    if (isGroup && groupMeta != null && groupMeta!.name.trim().isNotEmpty) {
      return groupMeta!.name.trim();
    }
    return otherUser?.displayName ?? '@Me';
  }

  /// Avatar URL for this conversation (Group Avatar OR Other User Avatar).
  String? get displayAvatarUrl {
    if (isGroup) return groupMeta?.avatarUrl;
    return otherUser?.avatarUrl;
  }

  /// Id of the participant that is NOT [currentUserId] (for 1-on-1 chats).
  String otherUserId(String currentUserId) =>
      user1Id == currentUserId ? user2Id : user1Id;

  bool includes(String userId) {
    if (isGroup && groupMeta != null) {
      return groupMeta!.isMember(userId);
    }
    return user1Id == userId || user2Id == userId;
  }

  bool isLastMessageMine(String? currentUserId) =>
      lastMessageSenderId != null && lastMessageSenderId == currentUserId;

  bool get isLastMessageAudio =>
      lastMessageType == SupabaseConstants.messageTypeAudio;

  bool get hasMessages =>
      lastMessage.trim().isNotEmpty || lastMessageSenderId != null;

  /// Preview text for the home list.
  String get previewText =>
      isLastMessageAudio ? SupabaseConstants.voiceMessagePreview : lastMessage;

  /// Encodes group metadata + visible preview text into a single `last_message`
  /// string so group chats work even if the remote database doesn't have
  /// dedicated group columns yet.
  static String encodeGroupLastMessage({
    required GroupChatMeta meta,
    required String visibleLastMessage,
  }) {
    final Map<String, dynamic> payload = <String, dynamic>{
      'meta': meta.toJson(),
      'msg': visibleLastMessage,
    };
    return '$_groupEnvelopePrefix${jsonEncode(payload)}';
  }

  // ---------------------------------------------------------------------------
  // Serialization
  // ---------------------------------------------------------------------------

  factory ConversationModel.fromJson(
    Map<String, dynamic> json, {
    String? currentUserId,
  }) {
    final String user1Id = json['user1_id'] as String;
    final String user2Id = json['user2_id'] as String;
    String rawLastMessage = (json['last_message'] as String?) ?? '';

    bool isGroupRow = (json['is_group'] as bool?) ?? false;
    GroupChatMeta? parsedGroupMeta;

    if (rawLastMessage.startsWith(_groupEnvelopePrefix)) {
      try {
        final String rawJson =
            rawLastMessage.substring(_groupEnvelopePrefix.length);
        final Map<String, dynamic> decoded =
            jsonDecode(rawJson) as Map<String, dynamic>;
        if (decoded['meta'] is Map<String, dynamic>) {
          parsedGroupMeta = GroupChatMeta.fromJson(
            decoded['meta'] as Map<String, dynamic>,
          );
          isGroupRow = true;
        }
        rawLastMessage = (decoded['msg'] as String?) ?? '';
      } catch (_) {}
    } else if (isGroupRow) {
      parsedGroupMeta = GroupChatMeta.fromJson(json);
    }

    ProfileModel? other;
    if (!isGroupRow && currentUserId != null) {
      final String otherKey = user1Id == currentUserId ? 'user2' : 'user1';
      final dynamic embedded = json[otherKey];
      if (embedded is Map<String, dynamic>) {
        other = ProfileModel.fromJson(embedded);
      }
    }

    return ConversationModel(
      id: json['id'] as String,
      user1Id: user1Id,
      user2Id: user2Id,
      lastMessage: rawLastMessage,
      lastMessageType: (json['last_message_type'] as String?) ??
          SupabaseConstants.messageTypeText,
      lastMessageSenderId: json['last_message_sender_id'] as String?,
      lastMessageAt: _parseDate(json['last_message_at']) ?? DateTime.now(),
      createdAt: _parseDate(json['created_at']),
      otherUser: other,
      isGroup: isGroupRow,
      groupMeta: parsedGroupMeta,
    );
  }

  Map<String, dynamic> toCacheJson() {
    return <String, dynamic>{
      'id': id,
      'user1_id': user1Id,
      'user2_id': user2Id,
      'last_message': lastMessage,
      'last_message_type': lastMessageType,
      'last_message_sender_id': lastMessageSenderId,
      'last_message_at': lastMessageAt.toUtc().toIso8601String(),
      if (createdAt != null) 'created_at': createdAt!.toUtc().toIso8601String(),
      if (otherUser != null) 'other_user': otherUser!.toJson(),
      'last_message_is_read': lastMessageIsRead,
      'unread_count': unreadCount,
      'is_pinned': isPinned,
      'is_muted': isMuted,
      'is_group': isGroup,
      if (groupMeta != null) 'group_meta': groupMeta!.toJson(),
      if (groupMemberProfiles.isNotEmpty)
        'group_member_profiles':
            groupMemberProfiles.map((ProfileModel p) => p.toJson()).toList(),
    };
  }

  factory ConversationModel.fromCacheJson(Map<String, dynamic> json) {
    final dynamic rawOther = json['other_user'];
    final dynamic rawMeta = json['group_meta'];
    final dynamic rawProfiles = json['group_member_profiles'];

    return ConversationModel(
      id: json['id'] as String,
      user1Id: json['user1_id'] as String,
      user2Id: json['user2_id'] as String,
      lastMessage: (json['last_message'] as String?) ?? '',
      lastMessageType: (json['last_message_type'] as String?) ??
          SupabaseConstants.messageTypeText,
      lastMessageSenderId: json['last_message_sender_id'] as String?,
      lastMessageAt: _parseDate(json['last_message_at']) ?? DateTime.now(),
      createdAt: _parseDate(json['created_at']),
      otherUser: rawOther is Map<String, dynamic>
          ? ProfileModel.fromJson(rawOther)
          : null,
      lastMessageIsRead: (json['last_message_is_read'] as bool?) ?? false,
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
      isPinned: (json['is_pinned'] as bool?) ?? false,
      isMuted: (json['is_muted'] as bool?) ?? false,
      isGroup: (json['is_group'] as bool?) ?? (rawMeta != null),
      groupMeta: rawMeta is Map<String, dynamic>
          ? GroupChatMeta.fromJson(rawMeta)
          : null,
      groupMemberProfiles: rawProfiles is List<dynamic>
          ? rawProfiles
              .whereType<Map<String, dynamic>>()
              .map(ProfileModel.fromJson)
              .toList()
          : const <ProfileModel>[],
    );
  }

  /// Payload used to create a new 1-on-1 conversation.
  static Map<String, dynamic> insertPayload({
    required String currentUserId,
    required String otherUserId,
  }) {
    return <String, dynamic>{
      'user1_id': currentUserId,
      'user2_id': otherUserId,
    };
  }

  /// Payload used to update the conversation after sending a message.
  static Map<String, dynamic> lastMessagePayload({
    required String lastMessage,
    required String lastMessageType,
    required String senderId,
    GroupChatMeta? groupMeta,
  }) {
    final String encodedMsg = groupMeta != null
        ? encodeGroupLastMessage(
            meta: groupMeta,
            visibleLastMessage: lastMessage,
          )
        : lastMessage;
    return <String, dynamic>{
      'last_message': encodedMsg,
      'last_message_type': lastMessageType,
      'last_message_sender_id': senderId,
      'last_message_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  ConversationModel copyWith({
    String? id,
    String? user1Id,
    String? user2Id,
    String? lastMessage,
    String? lastMessageType,
    String? lastMessageSenderId,
    DateTime? lastMessageAt,
    DateTime? createdAt,
    ProfileModel? otherUser,
    bool? lastMessageIsRead,
    int? unreadCount,
    bool? isPinned,
    bool? isMuted,
    bool? isGroup,
    GroupChatMeta? groupMeta,
    List<ProfileModel>? groupMemberProfiles,
  }) {
    return ConversationModel(
      id: id ?? this.id,
      user1Id: user1Id ?? this.user1Id,
      user2Id: user2Id ?? this.user2Id,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageType: lastMessageType ?? this.lastMessageType,
      lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      createdAt: createdAt ?? this.createdAt,
      otherUser: otherUser ?? this.otherUser,
      lastMessageIsRead: lastMessageIsRead ?? this.lastMessageIsRead,
      unreadCount: unreadCount ?? this.unreadCount,
      isPinned: isPinned ?? this.isPinned,
      isMuted: isMuted ?? this.isMuted,
      isGroup: isGroup ?? this.isGroup,
      groupMeta: groupMeta ?? this.groupMeta,
      groupMemberProfiles: groupMemberProfiles ?? this.groupMemberProfiles,
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
      other is ConversationModel &&
          other.id == id &&
          other.isGroup == isGroup &&
          other.groupMeta?.name == groupMeta?.name &&
          other.groupMeta?.description == groupMeta?.description &&
          other.groupMeta?.memberIds.length == groupMeta?.memberIds.length &&
          other.groupMeta?.adminIds.length == groupMeta?.adminIds.length &&
          other.groupMeta?.onlyAdminsCanSend == groupMeta?.onlyAdminsCanSend &&
          other.lastMessage == lastMessage &&
          other.lastMessageAt == lastMessageAt &&
          other.lastMessageIsRead == lastMessageIsRead &&
          other.unreadCount == unreadCount &&
          other.isPinned == isPinned &&
          other.isMuted == isMuted &&
          other.otherUser == otherUser;

  @override
  int get hashCode => Object.hash(
        id,
        isGroup,
        groupMeta?.name,
        lastMessage,
        lastMessageAt,
        lastMessageIsRead,
        unreadCount,
        isPinned,
        isMuted,
        otherUser,
      );

  @override
  String toString() =>
      'ConversationModel($id, isGroup: $isGroup, title: $title, last: $lastMessage)';
}
