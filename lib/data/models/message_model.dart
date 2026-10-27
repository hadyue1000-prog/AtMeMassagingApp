import '../../core/constants/supabase_constants.dart';

/// Message types stored in `messages.message_type`.
enum MessageType {
  text(SupabaseConstants.messageTypeText),
  audio(SupabaseConstants.messageTypeAudio);

  const MessageType(this.value);

  final String value;

  static MessageType fromValue(String? value) {
    return value == SupabaseConstants.messageTypeAudio
        ? MessageType.audio
        : MessageType.text;
  }
}

/// A row from `public.messages`.
class MessageModel {
  const MessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.messageType,
    required this.createdAt,
    this.content,
    this.mediaUrl,
    this.audioDuration = 0,
    this.isRead = false,
    this.isPending = false,
    this.localAudioPath,
    this.replySenderOverride,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final MessageType messageType;
  final String? content;
  final String? mediaUrl;

  /// Duration of the voice note in seconds.
  final int audioDuration;
  final bool isRead;
  final DateTime createdAt;

  /// True when the message was created offline and is queued in local storage
  /// waiting for internet connectivity to automatically sync to Supabase.
  final bool isPending;

  /// Local file path for a recorded voice note while `isPending` is true.
  final String? localAudioPath;

  /// Optional display name for sender in group chats.
  final String? replySenderOverride;

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  bool get isText => messageType == MessageType.text;

  bool get isAudio => messageType == MessageType.audio;

  bool isMine(String? currentUserId) => senderId == currentUserId;

  /// Text shown in `conversations.last_message`.
  String get preview => isAudio
      ? SupabaseConstants.voiceMessagePreview
      : bodyText.trim();

  Duration get duration => Duration(seconds: audioDuration);

  // ---------------------------------------------------------------------------
  // Quoted Reply Encoding / Parsing
  // ---------------------------------------------------------------------------
  // Encoded format inside `content`: `> [SenderName]: [Snippet]\n[ActualMessage]`
  static final RegExp _replyPrefixRegex =
      RegExp(r'^> \[([^\]]+)\]: ([^\n]*)\n([\s\S]*)$');

  bool get hasReply =>
      isText && content != null && _replyPrefixRegex.hasMatch(content!);

  String? get replySenderName {
    if (!hasReply) return null;
    return _replyPrefixRegex.firstMatch(content!)?.group(1);
  }

  String? get replySnippet {
    if (!hasReply) return null;
    return _replyPrefixRegex.firstMatch(content!)?.group(2);
  }

  /// Actual message body without the quoted reply header.
  String get bodyText {
    if (content == null) return '';
    if (!hasReply) return content!;
    return _replyPrefixRegex.firstMatch(content!)?.group(3) ?? content!;
  }

  /// Formats a message with an embedded reply quote header.
  static String encodeWithReply({
    required String text,
    required String replySender,
    required String replyText,
  }) {
    final String cleanSender =
        replySender.replaceAll('[', '').replaceAll(']', '').trim();
    final String singleLineSnippet =
        replyText.replaceAll('\n', ' ').trim();
    final String truncatedSnippet = singleLineSnippet.length > 60
        ? '${singleLineSnippet.substring(0, 60)}...'
        : singleLineSnippet;
    return '> [$cleanSender]: $truncatedSnippet\n${text.trim()}';
  }

  // ---------------------------------------------------------------------------
  // Serialization
  // ---------------------------------------------------------------------------

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      senderId: json['sender_id'] as String,
      messageType: MessageType.fromValue(json['message_type'] as String?),
      content: json['content'] as String?,
      mediaUrl: json['media_url'] as String?,
      audioDuration: (json['audio_duration'] as num?)?.toInt() ?? 0,
      isRead: (json['is_read'] as bool?) ?? false,
      createdAt: _parseDate(json['created_at']),
      isPending: (json['is_pending'] as bool?) ?? false,
      localAudioPath: json['local_audio_path'] as String?,
      replySenderOverride: json['reply_sender_override'] as String?,
    );
  }

  /// Full row JSON for local offline cache persistence.
  Map<String, dynamic> toCacheJson() {
    return <String, dynamic>{
      'id': id,
      'conversation_id': conversationId,
      'sender_id': senderId,
      'message_type': messageType.value,
      'content': content,
      'media_url': mediaUrl,
      'audio_duration': audioDuration,
      'is_read': isRead,
      'created_at': createdAt.toUtc().toIso8601String(),
      'is_pending': isPending,
      if (localAudioPath != null) 'local_audio_path': localAudioPath,
      if (replySenderOverride != null)
        'reply_sender_override': replySenderOverride,
    };
  }

  /// Payload for INSERT (id, is_read & created_at are generated by Postgres).
  Map<String, dynamic> toInsertJson() {
    return <String, dynamic>{
      'conversation_id': conversationId,
      'sender_id': senderId,
      'message_type': messageType.value,
      'content': content,
      'media_url': mediaUrl,
      'audio_duration': audioDuration,
    };
  }

  /// Builds an INSERT payload for a text message.
  static Map<String, dynamic> textPayload({
    required String conversationId,
    required String senderId,
    required String content,
  }) {
    return <String, dynamic>{
      'conversation_id': conversationId,
      'sender_id': senderId,
      'message_type': MessageType.text.value,
      'content': content.trim(),
    };
  }

  /// Builds an INSERT payload for a voice note.
  static Map<String, dynamic> audioPayload({
    required String conversationId,
    required String senderId,
    required String mediaUrl,
    required int audioDuration,
  }) {
    return <String, dynamic>{
      'conversation_id': conversationId,
      'sender_id': senderId,
      'message_type': MessageType.audio.value,
      'media_url': mediaUrl,
      'audio_duration': audioDuration,
    };
  }

  MessageModel copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    MessageType? messageType,
    String? content,
    String? mediaUrl,
    int? audioDuration,
    bool? isRead,
    DateTime? createdAt,
    bool? isPending,
    String? localAudioPath,
    String? replySenderOverride,
  }) {
    return MessageModel(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      messageType: messageType ?? this.messageType,
      content: content ?? this.content,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      audioDuration: audioDuration ?? this.audioDuration,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      isPending: isPending ?? this.isPending,
      localAudioPath: localAudioPath ?? this.localAudioPath,
      replySenderOverride: replySenderOverride ?? this.replySenderOverride,
    );
  }

  static DateTime _parseDate(dynamic value) {
    if (value is DateTime) return value.toLocal();
    if (value == null) return DateTime.now();
    return DateTime.tryParse(value.toString())?.toLocal() ?? DateTime.now();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MessageModel &&
          other.id == id &&
          other.isRead == isRead &&
          other.isPending == isPending &&
          other.content == content &&
          other.mediaUrl == mediaUrl;

  @override
  int get hashCode => Object.hash(id, isRead, isPending, content, mediaUrl);

  @override
  String toString() =>
      'MessageModel($id, ${messageType.value}, read: $isRead, at: $createdAt)';
}
