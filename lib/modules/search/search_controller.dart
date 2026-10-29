import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/supabase_constants.dart';
import '../../core/routes/app_routes.dart';
import '../../data/models/conversation_model.dart';
import '../../data/models/profile_model.dart';

/// Controller for `/search` — finds public friends by `@username` OR adds
/// hidden/private friends directly via Private Invite Code / Link.
class UserSearchController extends GetxController {
  final TextEditingController searchInputController = TextEditingController();
  final TextEditingController privateCodeController = TextEditingController();
  final FocusNode searchFocusNode = FocusNode();

  final RxString query = ''.obs;
  final RxList<ProfileModel> results = <ProfileModel>[].obs;
  final RxList<ProfileModel> suggestedUsers = <ProfileModel>[].obs;
  final RxBool isSearching = false.obs;
  final RxBool isLoadingSuggestions = false.obs;
  final RxBool isAddingByPrivateCode = false.obs;
  final RxString startingChatWithUserId = ''.obs;
  final RxString errorMessage = ''.obs;

  Worker? _searchDebounceWorker;

  String? get currentUserId => supabase.auth.currentUser?.id;

  String get myPrivateInviteCode {
    final String? uid = currentUserId;
    if (uid == null || uid.isEmpty) return '';
    final String clean = uid.replaceAll('-', '').toUpperCase();
    return clean.length >= 8 ? clean.substring(0, 8) : clean;
  }

  String get myPrivateInviteLink {
    final String? uid = currentUserId;
    if (uid == null || uid.isEmpty) return '';
    return 'https://atme.app/add/$uid';
  }

  @override
  void onInit() {
    super.onInit();
    // 500ms GetX debounce on the search query
    _searchDebounceWorker = debounce<String>(
      query,
      _performSearch,
      time: const Duration(milliseconds: 500),
    );
    loadSuggestedUsers();
  }

  @override
  void onClose() {
    _searchDebounceWorker?.dispose();
    searchInputController.dispose();
    privateCodeController.dispose();
    searchFocusNode.dispose();
    super.onClose();
  }

  Future<void> copyMyPrivateCode() async {
    final String code = myPrivateInviteCode;
    if (code.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: code));
    Get.snackbar(
      'تم النسخ',
      'تم نسخ كود الإضافة الخاص بك ($code)',
      snackPosition: SnackPosition.TOP,
      backgroundColor: const Color(0xEB0B2147),
      colorText: Colors.white,
      margin: const EdgeInsets.all(16),
    );
  }

  Future<void> copyMyPrivateLink() async {
    final String link = myPrivateInviteLink;
    if (link.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: link));
    Get.snackbar(
      'تم النسخ',
      'تم نسخ رابط الدعوة الخاص بك إلى الحافظة 🔗',
      snackPosition: SnackPosition.TOP,
      backgroundColor: const Color(0xEB0B2147),
      colorText: Colors.white,
      margin: const EdgeInsets.all(16),
    );
  }

  /// Adds and opens a chat with a user using their Private Invite Code or Link,
  /// bypassing the public `is_profile_discoverable` filter so users who enabled
  /// Hidden Mode (`وضع عدم الظهور`) can still be added privately.
  Future<void> addFriendByPrivateCodeOrLink([String? rawInput]) async {
    final String input = (rawInput ?? privateCodeController.text).trim();
    if (input.isEmpty || isAddingByPrivateCode.value) return;

    final String? myId = currentUserId;
    if (myId == null) return;

    isAddingByPrivateCode.value = true;
    FocusManager.instance.primaryFocus?.unfocus();

    try {
      // Extract token from link if user pasted a URL (`https://atme.app/add/...`)
      String token = input;
      if (token.contains('/add/')) {
        token = token.split('/add/').last.split('?').first.trim();
      } else if (token.contains('/')) {
        token = token.split('/').last.trim();
      }
      token = token.replaceFirst(RegExp(r'^@+'), '').trim();

      if (token.isEmpty) {
        Get.snackbar(
          'تنبيه',
          'يرجى إدخال كود دعوة أو رابط صحيح',
          snackPosition: SnackPosition.TOP,
          backgroundColor: const Color(0xEB0B2147),
          colorText: Colors.white,
          margin: const EdgeInsets.all(16),
        );
        return;
      }

      ProfileModel? matchedUser;

      // Case 1: Full UUID (from private link)
      final bool looksLikeUuid = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      ).hasMatch(token);

      if (looksLikeUuid) {
        Map<String, dynamic>? row;
        try {
          row = await supabase
              .from(SupabaseConstants.profilesTable)
              .select(SupabaseConstants.publicProfileColumns)
              .eq('id', token)
              .neq('id', myId)
              .maybeSingle();
        } on PostgrestException {
          row = await supabase
              .from(SupabaseConstants.profilesTable)
              .select(SupabaseConstants.fallbackPublicProfileColumns)
              .eq('id', token)
              .neq('id', myId)
              .maybeSingle();
        }
        if (row != null) {
          matchedUser = ProfileModel.fromJson(row);
        }
      }

      // Case 2: Direct lookup by exact username or UUID prefix in Postgres
      if (matchedUser == null) {
        try {
          // Direct check by username or display name (ignores is_profile_discoverable)
          final Map<String, dynamic>? userRow = await supabase
              .from(SupabaseConstants.profilesTable)
              .select(SupabaseConstants.publicProfileColumns)
              .or('username.ilike.$token,display_name.ilike.$token')
              .neq('id', myId)
              .maybeSingle();

          if (userRow != null) {
            matchedUser = ProfileModel.fromJson(userRow);
          }
        } catch (_) {}
      }

      // Case 3: 8-char Private Invite Code (UUID prefix search or fast fallback)
      if (matchedUser == null) {
        try {
          final String prefix = token.toLowerCase();
          final List<dynamic> prefixRows = await supabase
              .from(SupabaseConstants.profilesTable)
              .select(SupabaseConstants.publicProfileColumns)
              .ilike('id', '$prefix%')
              .neq('id', myId)
              .limit(5);

          for (final dynamic item in prefixRows) {
            if (item is Map<String, dynamic>) {
              final ProfileModel candidate = ProfileModel.fromJson(item);
              if (candidate.isComplete) {
                matchedUser = candidate;
                break;
              }
            }
          }
        } catch (_) {}
      }

      // Case 4: Memory scan fallback if custom RPC or PostgREST operators aren't available
      if (matchedUser == null) {
        List<dynamic> allRows;
        try {
          allRows = await supabase
              .from(SupabaseConstants.profilesTable)
              .select(SupabaseConstants.publicProfileColumns)
              .neq('id', myId)
              .limit(200);
        } on PostgrestException {
          allRows = await supabase
              .from(SupabaseConstants.profilesTable)
              .select(SupabaseConstants.fallbackPublicProfileColumns)
              .neq('id', myId)
              .limit(200);
        }

        final String upperToken = token.replaceAll('-', '').toUpperCase();
        final String lowerToken = token.toLowerCase();

        for (final dynamic item in allRows) {
          if (item is! Map<String, dynamic>) continue;
          final ProfileModel candidate = ProfileModel.fromJson(item);
          if (!candidate.isComplete) continue;

          if (candidate.privateInviteCode.toUpperCase() == upperToken ||
              candidate.id.replaceAll('-', '').toUpperCase().startsWith(
                    upperToken,
                  ) ||
              candidate.username.toLowerCase() == lowerToken) {
            matchedUser = candidate;
            break;
          }
        }
      }

      if (matchedUser == null) {
        Get.snackbar(
          'لم يتم العثور على الحساب',
          'تأكد من صحة كود الدعوة الخاص أو الرابط وحاول مرة أخرى',
          snackPosition: SnackPosition.TOP,
          backgroundColor: const Color(0xEB0B2147),
          colorText: Colors.white,
          margin: const EdgeInsets.all(16),
        );
        return;
      }

      privateCodeController.clear();
      await startOrOpenConversation(matchedUser);
    } catch (_) {
      Get.snackbar(
        'تنبيه',
        'تعذّر التحقق من الكود حالياً، تحقّق من اتصالك بالإنترنت',
        snackPosition: SnackPosition.TOP,
        backgroundColor: const Color(0xEB0B2147),
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
      );
    } finally {
      isAddingByPrivateCode.value = false;
    }
  }

  void onQueryChanged(String value) {
    // Strip leading '@' and spaces so typing '@ahmed' or 'ahmed' both work seamlessly
    final String cleaned =
        value.trim().replaceFirst(RegExp(r'^@+'), '').toLowerCase();
    query.value = cleaned;

    if (cleaned.isEmpty) {
      results.clear();
      isSearching.value = false;
      errorMessage.value = '';
    } else {
      isSearching.value = true;
      errorMessage.value = '';
    }
  }

  void clearSearch() {
    searchInputController.clear();
    query.value = '';
    results.clear();
    isSearching.value = false;
    errorMessage.value = '';
    searchFocusNode.requestFocus();
  }

  /// Loads public discoverable accounts on initial open so the user can
  /// browse active/recent users even before typing a search query.
  Future<void> loadSuggestedUsers() async {
    final String? myId = currentUserId;
    if (myId == null) {
      Get.offAllNamed(AppRoutes.email);
      return;
    }

    isLoadingSuggestions.value = true;
    try {
      List<dynamic> rows;
      try {
        rows = await supabase
            .from(SupabaseConstants.profilesTable)
            .select(SupabaseConstants.publicProfileColumns)
            .neq('id', myId)
            .eq('is_profile_discoverable', true)
            .order('is_online', ascending: false)
            .order('last_seen', ascending: false)
            .limit(15);
      } on PostgrestException {
        rows = await supabase
            .from(SupabaseConstants.profilesTable)
            .select(SupabaseConstants.fallbackPublicProfileColumns)
            .neq('id', myId)
            .order('is_online', ascending: false)
            .order('last_seen', ascending: false)
            .limit(15);
      }

      final List<ProfileModel> list = rows
          .whereType<Map<String, dynamic>>()
          .map(ProfileModel.fromJson)
          .where((ProfileModel p) => p.isComplete && p.isProfileDiscoverable)
          .toList();

      suggestedUsers.assignAll(list);
    } catch (_) {
      // Non-fatal
    } finally {
      isLoadingSuggestions.value = false;
    }
  }

  Future<void> _performSearch(String rawQuery) async {
    final String cleaned = rawQuery.trim().toLowerCase();
    if (cleaned.isEmpty) {
      results.clear();
      isSearching.value = false;
      return;
    }

    final String? myId = currentUserId;
    if (myId == null) {
      isSearching.value = false;
      Get.offAllNamed(AppRoutes.email);
      return;
    }

    isSearching.value = true;
    errorMessage.value = '';

    try {
      // Select ONLY publicProfileColumns (email is excluded for privacy)
      // Filter to users who allow their account to be seen (`is_profile_discoverable = true`)
      List<dynamic> rows;
      try {
        rows = await supabase
            .from(SupabaseConstants.profilesTable)
            .select(SupabaseConstants.publicProfileColumns)
            .or('username.ilike.%$cleaned%,display_name.ilike.%$cleaned%')
            .neq('id', myId)
            .eq('is_profile_discoverable', true)
            .order('username', ascending: true)
            .limit(30);
      } on PostgrestException {
        // Fallback if `is_profile_discoverable` column hasn't been added to remote DB yet
        rows = await supabase
            .from(SupabaseConstants.profilesTable)
            .select(
              'id, username, display_name, avatar_url, is_online, last_seen, created_at',
            )
            .or('username.ilike.%$cleaned%,display_name.ilike.%$cleaned%')
            .neq('id', myId)
            .order('username', ascending: true)
            .limit(30);
      }

      // Ignore stale responses if the user kept typing
      if (cleaned != query.value) return;

      final List<ProfileModel> found = rows
          .whereType<Map<String, dynamic>>()
          .map(ProfileModel.fromJson)
          .where((ProfileModel p) => p.isComplete && p.isProfileDiscoverable)
          .toList();

      results.assignAll(found);
    } on PostgrestException catch (e) {
      if (cleaned == query.value) {
        errorMessage.value = 'تعذّر البحث حالياً: ${e.message}';
      }
    } catch (_) {
      if (cleaned == query.value) {
        errorMessage.value = 'تعذّر الاتصال بالخادم، تحقّق من الإنترنت';
      }
    } finally {
      if (cleaned == query.value) {
        isSearching.value = false;
      }
    }
  }

  /// Checks if a 1-on-1 conversation already exists between `currentUserId`
  /// and [otherUser.id] (in either `user1_id` or `user2_id`). If found, opens
  /// it; otherwise creates a new row in `conversations` and navigates to `/chat`.
  Future<void> startOrOpenConversation(ProfileModel otherUser) async {
    if (startingChatWithUserId.value.isNotEmpty) return;

    final String? myId = currentUserId;
    if (myId == null) return;

    FocusManager.instance.primaryFocus?.unfocus();
    startingChatWithUserId.value = otherUser.id;

    try {
      // 1) Check existing 1-on-1 conversation in either direction
      final Map<String, dynamic>? existingRow = await supabase
          .from(SupabaseConstants.conversationsTable)
          .select()
          .or(
            'and(user1_id.eq.$myId,user2_id.eq.${otherUser.id}),'
            'and(user1_id.eq.${otherUser.id},user2_id.eq.$myId)',
          )
          .limit(1)
          .maybeSingle();

      ConversationModel conversation;

      if (existingRow != null) {
        conversation = ConversationModel.fromJson(
          existingRow,
          currentUserId: myId,
        ).copyWith(otherUser: otherUser);
      } else {
        // 2) Create a new 1-on-1 conversation
        final Map<String, dynamic> insertedRow = await supabase
            .from(SupabaseConstants.conversationsTable)
            .insert(
              ConversationModel.insertPayload(
                currentUserId: myId,
                otherUserId: otherUser.id,
              ),
            )
            .select()
            .single();

        conversation = ConversationModel.fromJson(
          insertedRow,
          currentUserId: myId,
        ).copyWith(otherUser: otherUser);
      }

      // 3) Navigate to /chat passing the conversation & otherUser via Get.arguments
      await Get.offNamed(
        AppRoutes.chat,
        arguments: <String, dynamic>{
          'conversationId': conversation.id,
          'conversation': conversation,
          'otherUser': otherUser,
        },
      );
    } on PostgrestException catch (e) {
      // Handle race condition if unique pair index triggered (code 23505)
      if (e.code == '23505') {
        try {
          final Map<String, dynamic>? retryRow = await supabase
              .from(SupabaseConstants.conversationsTable)
              .select()
              .or(
                'and(user1_id.eq.$myId,user2_id.eq.${otherUser.id}),'
                'and(user1_id.eq.${otherUser.id},user2_id.eq.$myId)',
              )
              .limit(1)
              .maybeSingle();

          if (retryRow != null) {
            final ConversationModel conv = ConversationModel.fromJson(
              retryRow,
              currentUserId: myId,
            ).copyWith(otherUser: otherUser);

            await Get.offNamed(
              AppRoutes.chat,
              arguments: <String, dynamic>{
                'conversationId': conv.id,
                'conversation': conv,
                'otherUser': otherUser,
              },
            );
            return;
          }
        } catch (_) {}
      }

      Get.snackbar(
        'تعذّر فتح المحادثة',
        e.message,
        snackPosition: SnackPosition.TOP,
        backgroundColor: const Color(0xEB0B2147),
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
      );
    } catch (_) {
      Get.snackbar(
        'تعذّر فتح المحادثة',
        'حدث خطأ غير متوقع، حاول مرة أخرى',
        snackPosition: SnackPosition.TOP,
        backgroundColor: const Color(0xEB0B2147),
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
      );
    } finally {
      startingChatWithUserId.value = '';
    }
  }
}
