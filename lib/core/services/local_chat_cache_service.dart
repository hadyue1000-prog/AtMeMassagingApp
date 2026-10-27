import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../../data/models/conversation_model.dart';
import '../../data/models/message_model.dart';

/// Offline-first local cache service for conversations and messages.
///
/// Uses `sqflite` on mobile platforms (Android / iOS / macOS) and falls back
/// transparently to `SharedPreferences` JSON storage on Web / Desktop / Tests
/// so that conversations and chat history open immediately even without
/// internet connection.
class LocalChatCacheService extends GetxService {
  static const String _dbName = 'at_me_offline_cache.db';
  static const int _dbVersion = 1;

  static const String _tableConversations = 'cached_conversations';
  static const String _tableMessages = 'cached_messages';

  static const String _spConversationsKey = 'at_me_offline_conversations_v1';
  static const String _spMessagesPrefix = 'at_me_offline_messages_v1_';
  static const String _spPendingOutboxKey = 'at_me_offline_pending_outbox_v1';
  static const String _spLocalGroupsKey = 'at_me_local_groups_v1';

  Database? _db;
  SharedPreferences? _prefs;

  /// Reactive list of messages queued while offline waiting to be sent.
  final RxList<MessageModel> pendingOutbox = <MessageModel>[].obs;

  static LocalChatCacheService get to => Get.find<LocalChatCacheService>();

  bool get _supportsSqflite {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  Future<LocalChatCacheService> init() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadPendingOutboxFromStorage();

    if (_supportsSqflite) {
      try {
        final String dbFolder = await getDatabasesPath();
        final String dbPath = p.join(dbFolder, _dbName);
        _db = await openDatabase(
          dbPath,
          version: _dbVersion,
          onCreate: (Database db, int version) async {
            await db.execute('''
              CREATE TABLE $_tableConversations (
                id TEXT PRIMARY KEY,
                last_message_at INTEGER NOT NULL,
                payload TEXT NOT NULL
              )
            ''');
            await db.execute('''
              CREATE TABLE $_tableMessages (
                id TEXT PRIMARY KEY,
                conversation_id TEXT NOT NULL,
                created_at INTEGER NOT NULL,
                payload TEXT NOT NULL
              )
            ''');
            await db.execute('''
              CREATE INDEX idx_cached_messages_conv
              ON $_tableMessages (conversation_id, created_at DESC)
            ''');
          },
        );
      } catch (_) {
        _db = null;
      }
    }
    return this;
  }

  // ===========================================================================
  // CONVERSATIONS CACHE
  // ===========================================================================

  Future<List<ConversationModel>> getCachedConversations() async {
    if (_db != null) {
      try {
        final List<Map<String, Object?>> rows = await _db!.query(
          _tableConversations,
          orderBy: 'last_message_at DESC',
        );
        final List<ConversationModel> list = <ConversationModel>[];
        for (final Map<String, Object?> r in rows) {
          try {
            final String raw = (r['payload'] as String?) ?? '';
            if (raw.isNotEmpty) {
              final Map<String, dynamic> map =
                  jsonDecode(raw) as Map<String, dynamic>;
              list.add(ConversationModel.fromCacheJson(map));
            }
          } catch (_) {}
        }
        return list;
      } catch (_) {}
    }

    final String? rawList = _prefs?.getString(_spConversationsKey);
    if (rawList == null || rawList.isEmpty) return <ConversationModel>[];

    try {
      final List<dynamic> decoded = jsonDecode(rawList) as List<dynamic>;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(ConversationModel.fromCacheJson)
          .toList();
    } catch (_) {
      return <ConversationModel>[];
    }
  }

  Future<void> saveConversations(List<ConversationModel> conversations) async {
    if (_db != null) {
      try {
        final Batch batch = _db!.batch();
        batch.delete(_tableConversations);
        for (final ConversationModel conv in conversations) {
          batch.insert(
            _tableConversations,
            <String, Object?>{
              'id': conv.id,
              'last_message_at': conv.lastMessageAt.millisecondsSinceEpoch,
              'payload': jsonEncode(conv.toCacheJson()),
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await batch.commit(noResult: true);
      } catch (_) {}
    }

    try {
      final List<Map<String, dynamic>> serialized = conversations
          .map((ConversationModel c) => c.toCacheJson())
          .toList();
      await _prefs?.setString(_spConversationsKey, jsonEncode(serialized));
    } catch (_) {}
  }

  Future<void> removeCachedConversation(String conversationId) async {
    if (_db != null) {
      try {
        await _db!.delete(
          _tableConversations,
          where: 'id = ?',
          whereArgs: <Object?>[conversationId],
        );
        await _db!.delete(
          _tableMessages,
          where: 'conversation_id = ?',
          whereArgs: <Object?>[conversationId],
        );
      } catch (_) {}
    }

    try {
      await _prefs?.remove('$_spMessagesPrefix$conversationId');
      final List<ConversationModel> existing = await getCachedConversations();
      existing.removeWhere((ConversationModel c) => c.id == conversationId);
      final List<Map<String, dynamic>> serialized =
          existing.map((ConversationModel c) => c.toCacheJson()).toList();
      await _prefs?.setString(_spConversationsKey, jsonEncode(serialized));
    } catch (_) {}
  }

  // ===========================================================================
  // MESSAGES CACHE (Per Conversation)
  // ===========================================================================

  Future<List<MessageModel>> getCachedMessages(String conversationId) async {
    if (conversationId.isEmpty) return <MessageModel>[];

    if (_db != null) {
      try {
        final List<Map<String, Object?>> rows = await _db!.query(
          _tableMessages,
          where: 'conversation_id = ?',
          whereArgs: <Object?>[conversationId],
          orderBy: 'created_at DESC',
          limit: 300,
        );
        final List<MessageModel> list = <MessageModel>[];
        for (final Map<String, Object?> r in rows) {
          try {
            final String raw = (r['payload'] as String?) ?? '';
            if (raw.isNotEmpty) {
              final Map<String, dynamic> map =
                  jsonDecode(raw) as Map<String, dynamic>;
              list.add(MessageModel.fromJson(map));
            }
          } catch (_) {}
        }
        return list;
      } catch (_) {}
    }

    final String? raw =
        _prefs?.getString('$_spMessagesPrefix$conversationId');
    if (raw == null || raw.isEmpty) return <MessageModel>[];

    try {
      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      final List<MessageModel> list = decoded
          .whereType<Map<String, dynamic>>()
          .map(MessageModel.fromJson)
          .toList()
        ..sort(
          (MessageModel a, MessageModel b) =>
              b.createdAt.compareTo(a.createdAt),
        );
      return list;
    } catch (_) {
      return <MessageModel>[];
    }
  }

  Future<void> saveMessages(
    String conversationId,
    List<MessageModel> messages,
  ) async {
    if (conversationId.isEmpty) return;

    // Keep latest 300 messages per conversation for fast offline startup
    final List<MessageModel> capped =
        messages.length > 300 ? messages.sublist(0, 300) : messages;

    if (_db != null) {
      try {
        final Batch batch = _db!.batch();
        batch.delete(
          _tableMessages,
          where: 'conversation_id = ?',
          whereArgs: <Object?>[conversationId],
        );
        for (final MessageModel msg in capped) {
          batch.insert(
            _tableMessages,
            <String, Object?>{
              'id': msg.id,
              'conversation_id': conversationId,
              'created_at': msg.createdAt.millisecondsSinceEpoch,
              'payload': jsonEncode(msg.toCacheJson()),
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await batch.commit(noResult: true);
      } catch (_) {}
    }

    try {
      final List<Map<String, dynamic>> serialized =
          capped.map((MessageModel m) => m.toCacheJson()).toList();
      await _prefs?.setString(
        '$_spMessagesPrefix$conversationId',
        jsonEncode(serialized),
      );
    } catch (_) {}
  }

  Future<void> upsertSingleMessage(MessageModel message) async {
    final List<MessageModel> current =
        await getCachedMessages(message.conversationId);
    final int idx =
        current.indexWhere((MessageModel m) => m.id == message.id);
    if (idx != -1) {
      current[idx] = message;
    } else {
      current.insert(0, message);
    }
    current.sort(
      (MessageModel a, MessageModel b) => b.createdAt.compareTo(a.createdAt),
    );
    await saveMessages(message.conversationId, current);
  }

  // ===========================================================================
  // OFFLINE OUTBOX QUEUE (Send messages offline -> auto-sync when online)
  // ===========================================================================

  Future<void> _loadPendingOutboxFromStorage() async {
    final String? raw = _prefs?.getString(_spPendingOutboxKey);
    if (raw == null || raw.isEmpty) {
      pendingOutbox.clear();
      return;
    }
    try {
      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      final List<MessageModel> parsed = decoded
          .whereType<Map<String, dynamic>>()
          .map(MessageModel.fromJson)
          .map((MessageModel m) => m.copyWith(isPending: true))
          .toList()
        ..sort(
          (MessageModel a, MessageModel b) =>
              a.createdAt.compareTo(b.createdAt),
        );
      pendingOutbox.assignAll(parsed);
    } catch (_) {
      pendingOutbox.clear();
    }
  }

  Future<void> _persistPendingOutbox() async {
    try {
      final List<Map<String, dynamic>> serialized =
          pendingOutbox.map((MessageModel m) => m.toCacheJson()).toList();
      await _prefs?.setString(_spPendingOutboxKey, jsonEncode(serialized));
    } catch (_) {}
  }

  /// Adds an outgoing message to the persistent offline outbox and also inserts
  /// it into the conversation's cached messages so it displays immediately in the chat.
  Future<void> enqueueOfflineMessage(MessageModel message) async {
    final MessageModel pending = message.copyWith(isPending: true);
    final int idx =
        pendingOutbox.indexWhere((MessageModel m) => m.id == pending.id);
    if (idx != -1) {
      pendingOutbox[idx] = pending;
    } else {
      pendingOutbox.add(pending);
    }
    await _persistPendingOutbox();
    await upsertSingleMessage(pending);
  }

  /// Removes a message from the offline outbox once it has been delivered to Supabase.
  Future<void> removeOfflineMessage(String tempMessageId) async {
    pendingOutbox.removeWhere((MessageModel m) => m.id == tempMessageId);
    await _persistPendingOutbox();
  }

  /// Returns all pending offline messages for a specific conversation.
  List<MessageModel> getPendingMessagesForConversation(String conversationId) {
    return pendingOutbox
        .where((MessageModel m) => m.conversationId == conversationId)
        .toList();
  }

  // ===========================================================================
  // CLEAR ALL CACHE (Sign Out / Clear Storage in Settings)
  // ===========================================================================

  Future<void> clearAllCache() async {
    pendingOutbox.clear();
    if (_db != null) {
      try {
        await _db!.delete(_tableConversations);
        await _db!.delete(_tableMessages);
      } catch (_) {}
    }

    try {
      await _prefs?.remove(_spConversationsKey);
      await _prefs?.remove(_spPendingOutboxKey);
      await _prefs?.remove(_spLocalGroupsKey);
      final Set<String> keys = _prefs?.getKeys() ?? const <String>{};
      for (final String key in keys) {
        if (key.startsWith(_spMessagesPrefix)) {
          await _prefs?.remove(key);
        }
      }
    } catch (_) {}
  }
}
