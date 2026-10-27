import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/supabase_constants.dart';
import '../../../core/services/app_preferences_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_widgets.dart';
import '../../../data/models/profile_model.dart';
import '../home_controller.dart';

/// Opens the Glassmorphism Group Creation modal sheet where the user can:
/// - Enter Group Name & Description
/// - Configure Admin Permissions (`onlyAdminsCanSend`, `onlyAdminsCanEditInfo`)
/// - Select friends from existing conversations or search users to add as members
void showCreateGroupBottomSheet(HomeController homeController) {
  Get.bottomSheet(
    _CreateGroupSheetContent(homeController: homeController),
    isScrollControlled: true,
  );
}

class _CreateGroupSheetContent extends StatefulWidget {
  const _CreateGroupSheetContent({required this.homeController});

  final HomeController homeController;

  @override
  State<_CreateGroupSheetContent> createState() =>
      _CreateGroupSheetContentState();
}

class _CreateGroupSheetContentState extends State<_CreateGroupSheetContent> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _memberSearchController =
      TextEditingController();

  final Map<String, ProfileModel> _availableUsers = <String, ProfileModel>{};
  final Set<String> _selectedUserIds = <String>{};

  bool _onlyAdminsCanSend = false;
  bool _onlyAdminsCanEditInfo = true;
  bool _isSearchingRemote = false;

  @override
  void initState() {
    super.initState();
    // Seed available contacts from existing 1-on-1 conversations & community statuses
    for (final conv in widget.homeController.conversations) {
      if (!conv.isGroup && conv.otherUser != null) {
        _availableUsers[conv.otherUser!.id] = conv.otherUser!;
      }
    }
    for (final u in widget.homeController.statusUsers) {
      _availableUsers[u.id] = u;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _memberSearchController.dispose();
    super.dispose();
  }

  Future<void> _searchMoreUsers(String query) async {
    final String cleaned =
        query.trim().replaceFirst(RegExp(r'^@+'), '').toLowerCase();
    if (cleaned.length < 2) return;

    final String? myId = widget.homeController.currentUserId;
    if (myId == null) return;

    setState(() => _isSearchingRemote = true);
    try {
      final List<dynamic> rows = await supabase
          .from(SupabaseConstants.profilesTable)
          .select(SupabaseConstants.publicProfileColumns)
          .neq('id', myId)
          .or('display_name.ilike.%$cleaned%,username.ilike.%$cleaned%')
          .limit(20);

      for (final dynamic r in rows) {
        if (r is Map<String, dynamic>) {
          final ProfileModel p = ProfileModel.fromJson(r);
          _availableUsers[p.id] = p;
        }
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _isSearchingRemote = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = AppColors.isDark;
    final bool isAr = Get.isRegistered<AppPreferencesService>()
        ? AppPreferencesService.to.isArabic
        : true;
    final String q = _memberSearchController.text.trim().toLowerCase();

    final List<ProfileModel> filteredUsers = _availableUsers.values.where((
      ProfileModel u,
    ) {
      if (q.isEmpty) return true;
      return u.displayName.toLowerCase().contains(q) ||
          u.username.toLowerCase().contains(q) ||
          u.privateInviteCode.toLowerCase() == q;
    }).toList();

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.88,
          ),
          padding: EdgeInsets.fromLTRB(
            20,
            14,
            20,
            MediaQuery.viewInsetsOf(context).bottom + 24,
          ),
          decoration: BoxDecoration(
            gradient: isDark
                ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[Color(0xEB102E6B), Color(0xF507152E)],
                  )
                : AppColors.lightScaffoldGradient,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(
                color: isDark
                    ? AppColors.aqua.withValues(alpha: 0.38)
                    : AppColors.lightBorder,
                width: 1.2,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.divider,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: <Widget>[
                      Container(
                        width: 46,
                        height: 46,
                        decoration: const BoxDecoration(
                          gradient: AppColors.cyanButtonGradient,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.groups_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              isAr
                                  ? 'إنشاء مجموعة جديدة'
                                  : 'Create New Group',
                              style: TextStyle(
                                fontSize: 18.5,
                                fontWeight: FontWeight.w900,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              isAr
                                  ? 'ستكون أنت مؤسس ومدير المجموعة بكامل الصلاحيات 👑'
                                  : 'You will be the group founder & admin 👑',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Group Name
                  GlassTextField(
                    controller: _nameController,
                    prefixIcon: Icons.group_work_rounded,
                    hintText: isAr
                        ? 'اسم المجموعة (مثال: أصدقاء الدراسة)'
                        : 'Group Name',
                  ),
                  const SizedBox(height: 12),

                  // Group Description
                  GlassTextField(
                    controller: _descController,
                    prefixIcon: Icons.notes_rounded,
                    maxLines: 2,
                    hintText: isAr
                        ? 'وصف المجموعة وقوانينها (اختياري)...'
                        : 'Group description & rules (optional)...',
                  ),
                  const SizedBox(height: 16),

                  // Admin Permissions Card
                  GlassCard(
                    borderRadius: 20,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: Row(
                            children: <Widget>[
                              const Icon(
                                Icons.admin_panel_settings_rounded,
                                color: AppColors.aqua,
                                size: 19,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isAr
                                    ? 'صلاحيات مدير المجموعة'
                                    : 'Group Admin Permissions',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SwitchListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                          ),
                          title: Text(
                            isAr
                                ? 'إرسال الرسائل للمديرين فقط'
                                : 'Only admins can send messages',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            isAr
                                ? 'عند التفعيل، الأعضاء يقرأون فقط ولا يرسلون'
                                : 'Members can read only when enabled',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          value: _onlyAdminsCanSend,
                          onChanged: (bool val) =>
                              setState(() => _onlyAdminsCanSend = val),
                        ),
                        SwitchListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                          ),
                          title: Text(
                            isAr
                                ? 'تعديل معلومات المجموعة للمديرين فقط'
                                : 'Only admins can edit group info',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          value: _onlyAdminsCanEditInfo,
                          onChanged: (bool val) =>
                              setState(() => _onlyAdminsCanEditInfo = val),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Members Selection Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text(
                        isAr
                            ? 'إضافة أعضاء للمجموعة (${_selectedUserIds.length})'
                            : 'Add Group Members (${_selectedUserIds.length})',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14.5,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (_isSearchingRemote)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  GlassSearchField(
                    controller: _memberSearchController,
                    hintText: isAr
                        ? 'ابحث عن صديق لإضافته للمجموعة...'
                        : 'Search friend to add...',
                    onChanged: (String val) {
                      setState(() {});
                      _searchMoreUsers(val);
                    },
                  ),
                  const SizedBox(height: 10),

                  if (filteredUsers.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Center(
                        child: Text(
                          isAr
                              ? 'ابحث عن أصدقائك بالأعلى لإضافتهم، أو أنشئ المجموعة الآن وأضفهم لاحقاً'
                              : 'Search friends above or create group now and add them later',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    )
                  else
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 190),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: filteredUsers.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 6),
                        itemBuilder: (BuildContext context, int index) {
                          final ProfileModel user = filteredUsers[index];
                          final bool selected =
                              _selectedUserIds.contains(user.id);
                          return GlassCard(
                            borderRadius: 16,
                            isHighlighted: selected,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            onTap: () {
                              setState(() {
                                if (selected) {
                                  _selectedUserIds.remove(user.id);
                                } else {
                                  _selectedUserIds.add(user.id);
                                }
                              });
                            },
                            child: Row(
                              children: <Widget>[
                                GlassAvatar(
                                  imageUrl: user.avatarUrl,
                                  fallbackText: user.displayName,
                                  radius: 18,
                                  isOnline: user.isOnline,
                                  showGlow: false,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    user.displayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14.5,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                Icon(
                                  selected
                                      ? Icons.check_circle_rounded
                                      : Icons.radio_button_unchecked_rounded,
                                  color: selected
                                      ? AppColors.aqua
                                      : AppColors.textSecondary,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                  const SizedBox(height: 18),

                  Obx(
                    () => SizedBox(
                      width: double.infinity,
                      child: GlowingCyanButton(
                        label: isAr
                            ? 'إنشاء المجموعة الآن ✨'
                            : 'Create Group Now ✨',
                        icon: Icons.check_rounded,
                        loading: widget.homeController.isCreatingGroup.value,
                        onPressed: () async {
                          final List<ProfileModel> chosen = _selectedUserIds
                              .map((String id) => _availableUsers[id])
                              .whereType<ProfileModel>()
                              .toList();
                          Get.back<void>();
                          await widget.homeController.createGroupConversation(
                            groupName: _nameController.text,
                            groupDescription: _descController.text,
                            initialMembers: chosen,
                            onlyAdminsCanSend: _onlyAdminsCanSend,
                            onlyAdminsCanEditInfo: _onlyAdminsCanEditInfo,
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
