import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/services/app_preferences_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_widgets.dart';
import '../../../core/widgets/other_user_profile_sheet.dart';
import '../../../data/models/conversation_model.dart';
import '../../../data/models/profile_model.dart';
import '../chat_controller.dart';

/// Opens the Group Information, Members & Admin Permissions sheet.
void showGroupInfoSheet(ChatController controller) {
  controller.loadGroupMembers();
  Get.bottomSheet(
    _GroupInfoSheetContent(controller: controller),
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
  );
}

class _GroupInfoSheetContent extends StatefulWidget {
  const _GroupInfoSheetContent({required this.controller});

  final ChatController controller;

  @override
  State<_GroupInfoSheetContent> createState() => _GroupInfoSheetContentState();
}

class _GroupInfoSheetContentState extends State<_GroupInfoSheetContent> {
  bool _isEditingInfo = false;
  bool _showAddMembers = false;
  late TextEditingController _nameController;
  late TextEditingController _descController;

  @override
  void initState() {
    super.initState();
    final GroupChatMeta? meta = widget.controller.groupMeta;
    _nameController = TextEditingController(text: meta?.name ?? '');
    _descController = TextEditingController(text: meta?.description ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _showGroupAvatarOptions(bool isAr, bool hasAvatar) {
    Get.bottomSheet(
      GlassBottomSheet(
        title: isAr ? 'صورة المجموعة' : 'Group Picture',
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading:
                    const Icon(Icons.camera_alt_rounded, color: AppColors.aqua),
                title: Text(
                  isAr
                      ? 'التقاط صورة بالكاميرا 📷'
                      : 'Take a photo with camera 📷',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                onTap: () {
                  Get.back<void>();
                  widget.controller
                      .updateGroupAvatarFromPicker(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library_rounded,
                  color: AppColors.aqua,
                ),
                title: Text(
                  isAr
                      ? 'اختيار صورة من المعرض 🖼️'
                      : 'Choose photo from gallery 🖼️',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                onTap: () {
                  Get.back<void>();
                  widget.controller
                      .updateGroupAvatarFromPicker(ImageSource.gallery);
                },
              ),
              if (hasAvatar)
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.error,
                  ),
                  title: Text(
                    isAr ? 'إزالة صورة المجموعة' : 'Remove group picture',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.error,
                    ),
                  ),
                  onTap: () {
                    Get.back<void>();
                    widget.controller.removeGroupAvatar();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isAr = Get.isRegistered<AppPreferencesService>()
        ? AppPreferencesService.to.isArabic
        : true;

    return GlassBottomSheet(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.84,
        ),
        child: Obx(() {
          final GroupChatMeta? meta = widget.controller.groupMeta;
          if (meta == null) {
            return const SizedBox.shrink();
          }

          final String myId = widget.controller.currentUserId ?? '';
          final bool isAdmin = meta.isAdmin(myId);
          final bool canEdit = meta.canUserEditInfo(myId);
          final List<ProfileModel> members =
              widget.controller.groupMembersList;
          final List<ProfileModel> addable =
              widget.controller.addableFriendsList;

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // 1) Group Hero Header
                Center(
                  child: Column(
                    children: <Widget>[
                      // Interactive Group Avatar with Edit Badge
                      Obx(() {
                        final bool isUploading =
                            widget.controller.isUpdatingGroupAvatar.value;
                        final bool hasAvatar = meta.avatarUrl != null &&
                            meta.avatarUrl!.trim().isNotEmpty;

                        return GestureDetector(
                          onTap: canEdit
                              ? () => _showGroupAvatarOptions(isAr, hasAvatar)
                              : null,
                          child: Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.center,
                            children: <Widget>[
                              Container(
                                width: 84,
                                height: 84,
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: <Color>[
                                      AppColors.electricCyan,
                                      AppColors.royalBlue,
                                    ],
                                  ),
                                  shape: BoxShape.circle,
                                  boxShadow: <BoxShadow>[
                                    BoxShadow(
                                      color: AppColors.electricCyan
                                          .withValues(alpha: 0.35),
                                      blurRadius: 18,
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: hasAvatar
                                      ? buildUniversalAvatarImage(
                                          imageUrl: meta.avatarUrl,
                                          fallbackText: meta.name,
                                          radius: 39,
                                        )
                                      : const Center(
                                          child: Icon(
                                            Icons.groups_rounded,
                                            color: Colors.white,
                                            size: 42,
                                          ),
                                        ),
                                ),
                              ),
                              if (isUploading)
                                Container(
                                  width: 84,
                                  height: 84,
                                  decoration: BoxDecoration(
                                    color:
                                        Colors.black.withValues(alpha: 0.55),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.8,
                                      color: AppColors.aqua,
                                    ),
                                  ),
                                ),
                              if (canEdit && !isUploading)
                                PositionedDirectional(
                                  bottom: 0,
                                  end: 0,
                                  child: Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      gradient: AppColors.cyanButtonGradient,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt_rounded,
                                      color: Colors.white,
                                      size: 15,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Flexible(
                            child: Text(
                              meta.name,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          if (canEdit)
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(
                                Icons.edit_rounded,
                                size: 18,
                                color: AppColors.aqua,
                              ),
                              onPressed: () {
                                setState(() {
                                  _nameController.text = meta.name;
                                  _descController.text = meta.description;
                                  _isEditingInfo = !_isEditingInfo;
                                });
                              },
                            ),
                        ],
                      ),
                      if (canEdit)
                        Padding(
                          padding: const EdgeInsets.only(top: 2, bottom: 4),
                          child: InkWell(
                            onTap: () => _showGroupAvatarOptions(
                              isAr,
                              meta.avatarUrl != null &&
                                  meta.avatarUrl!.trim().isNotEmpty,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  const Icon(
                                    Icons.photo_camera_rounded,
                                    size: 14,
                                    color: AppColors.aqua,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    isAr
                                        ? 'تغيير صورة المجموعة'
                                        : 'Change group picture',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.aqua,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      if (meta.description.trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            meta.description,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      // Group Invite Code Pill
                      if (meta.inviteCode.isNotEmpty)
                        InkWell(
                          onTap: () async {
                            await Clipboard.setData(
                              ClipboardData(text: meta.inviteCode),
                            );
                            Get.snackbar(
                              isAr ? 'تم النسخ' : 'Copied',
                              isAr
                                  ? 'تم نسخ كود دعوة المجموعة (${meta.inviteCode})'
                                  : 'Group invite code copied',
                              snackPosition: SnackPosition.TOP,
                              backgroundColor: const Color(0xEB0B2147),
                              colorText: Colors.white,
                              margin: const EdgeInsets.all(16),
                            );
                          },
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.electricCyan.withValues(
                                alpha: 0.14,
                              ),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: AppColors.aqua.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                const Icon(
                                  Icons.qr_code_rounded,
                                  size: 15,
                                  color: AppColors.aqua,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  isAr
                                      ? 'كود المجموعة: ${meta.inviteCode}'
                                      : 'Group Code: ${meta.inviteCode}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.aqua,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.copy_rounded,
                                  size: 13,
                                  color: AppColors.aqua,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Inline Edit Group Name & Description
                if (_isEditingInfo && canEdit) ...<Widget>[
                  const SizedBox(height: 14),
                  GlassCard(
                    borderRadius: 18,
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: <Widget>[
                        TextField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText:
                                isAr ? 'اسم المجموعة' : 'Group Name',
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _descController,
                          maxLines: 2,
                          decoration: InputDecoration(
                            labelText: isAr
                                ? 'وصف المجموعة'
                                : 'Group Description',
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: GlowingCyanButton(
                            height: 42,
                            label: 'save_changes'.tr,
                            icon: Icons.check_rounded,
                            onPressed: () async {
                              await widget.controller.updateGroupInfo(
                                name: _nameController.text,
                                description: _descController.text,
                              );
                              setState(() => _isEditingInfo = false);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // 2) Group Admin Permissions Card (Editable by Group Admins)
                GlassCard(
                  borderRadius: 20,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        child: Row(
                          children: <Widget>[
                            const Icon(
                              Icons.admin_panel_settings_rounded,
                              color: AppColors.aqua,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                isAr
                                    ? 'صلاحيات مدير ومشرفي المجموعة'
                                    : 'Group Admin Permissions',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            if (isAdmin)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.online.withValues(
                                    alpha: 0.18,
                                  ),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  isAr ? 'أنت مشرف ⭐' : 'You are Admin ⭐',
                                  style: const TextStyle(
                                    color: AppColors.online,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      SwitchListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 6,
                        ),
                        title: Text(
                          isAr
                              ? 'إرسال الرسائل للمشرفين فقط'
                              : 'Only admins can send messages',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13.5,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          isAr
                              ? 'منع الأعضاء العاديين من الكتابة في المجموعة'
                              : 'Restrict sending messages to group admins only',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        value: meta.onlyAdminsCanSend,
                        onChanged: isAdmin
                            ? (bool val) => widget.controller
                                  .updateGroupPermissions(
                                    onlyAdminsCanSend: val,
                                  )
                            : null,
                      ),
                      Divider(height: 1, color: AppColors.divider),
                      SwitchListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 6,
                        ),
                        title: Text(
                          isAr
                              ? 'تعديل معلومات المجموعة للمشرفين فقط'
                              : 'Only admins can edit group info',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13.5,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        value: meta.onlyAdminsCanEditInfo,
                        onChanged: isAdmin
                            ? (bool val) => widget.controller
                                  .updateGroupPermissions(
                                    onlyAdminsCanEditInfo: val,
                                  )
                            : null,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 3) Members Header + Add Member Button (for Admins)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      isAr
                          ? 'أعضاء المجموعة (${meta.memberIds.length})'
                          : 'Group Members (${meta.memberIds.length})',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (isAdmin)
                      TextButton.icon(
                        onPressed: () =>
                            setState(() => _showAddMembers = !_showAddMembers),
                        icon: Icon(
                          _showAddMembers
                              ? Icons.close_rounded
                              : Icons.person_add_alt_1_rounded,
                          size: 18,
                          color: AppColors.aqua,
                        ),
                        label: Text(
                          _showAddMembers
                              ? 'cancel'.tr
                              : (isAr ? 'إضافة عضو' : 'Add Member'),
                          style: const TextStyle(
                            color: AppColors.aqua,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                  ],
                ),

                // Expandable Add Members Picker for Admins
                if (_showAddMembers && isAdmin) ...<Widget>[
                  GlassCard(
                    borderRadius: 18,
                    padding: const EdgeInsets.all(10),
                    child: addable.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(12),
                            child: Center(
                              child: Text(
                                isAr
                                    ? 'جميع المستخدمين المتاحين مضافون بالفعل'
                                    : 'All available users are already in the group',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          )
                        : Column(
                            children: addable.take(8).map((ProfileModel u) {
                              return ListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                                leading: CircleAvatar(
                                  radius: 18,
                                  backgroundColor: AppColors.deepNavy,
                                  child: Text(
                                    u.initials,
                                    style: const TextStyle(
                                      color: AppColors.aqua,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  u.displayName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                trailing: ElevatedButton(
                                  onPressed: () =>
                                      widget.controller.addMemberToGroup(u),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.electricCyan,
                                    foregroundColor: AppColors.deepNavy,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                  ),
                                  child: Text(
                                    isAr ? 'إضافة' : 'Add',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                  ),
                  const SizedBox(height: 12),
                ],

                // 4) Members List with Admin Roles & Actions
                GlassCard(
                  borderRadius: 20,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: widget.controller.isLoadingGroupMembers.value &&
                          members.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(20),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : Column(
                          children: members.map((ProfileModel member) {
                            final bool memberIsOwner = meta.isOwner(member.id);
                            final bool memberIsAdmin = meta.isAdmin(member.id);
                            final bool isMe = member.id == myId;

                            return ListTile(
                              onTap: () => showOtherUserProfileSheet(
                                user: member,
                              ),
                              leading: CircleAvatar(
                                radius: 21,
                                backgroundColor: AppColors.deepNavy,
                                backgroundImage: member.hasAvatar
                                    ? CachedNetworkImageProvider(
                                        member.avatarUrl!,
                                      )
                                    : null,
                                child: !member.hasAvatar
                                    ? Text(
                                        member.initials,
                                        style: const TextStyle(
                                          color: AppColors.aqua,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      )
                                    : null,
                              ),
                              // ONLY displayName is shown here; @username is inside User Info sheet!
                              title: Row(
                                children: <Widget>[
                                  Flexible(
                                    child: Text(
                                      isMe
                                          ? '${member.displayName} (${'you'.tr})'
                                          : member.displayName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14.5,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  if (memberIsOwner) ...<Widget>[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.withValues(
                                          alpha: 0.20,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      child: Text(
                                        isAr
                                            ? 'مدير الجروب 👑'
                                            : 'Owner 👑',
                                        style: const TextStyle(
                                          color: Colors.amber,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ] else if (memberIsAdmin) ...<Widget>[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.electricCyan
                                            .withValues(alpha: 0.20),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      child: Text(
                                        isAr ? 'مشرف ⭐' : 'Admin ⭐',
                                        style: const TextStyle(
                                          color: AppColors.aqua,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              subtitle: Text(
                                member.isOnline
                                    ? 'online_now'.tr
                                    : (isAr
                                          ? 'اضغط لعرض معلومات المستخدم'
                                          : 'Tap to view user info'),
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: member.isOnline
                                      ? AppColors.online
                                      : AppColors.textSecondary,
                                ),
                              ),
                              trailing: (isAdmin && !isMe && !memberIsOwner)
                                  ? PopupMenuButton<String>(
                                      color: AppColors.deepNavy,
                                      icon: Icon(
                                        Icons.more_vert_rounded,
                                        color: AppColors.textSecondary,
                                      ),
                                      onSelected: (String action) {
                                        if (action == 'toggle_admin') {
                                          widget.controller
                                              .toggleMemberAdminRole(member.id);
                                        } else if (action == 'remove') {
                                          widget.controller
                                              .removeMemberFromGroup(member.id);
                                        } else if (action == 'info') {
                                          showOtherUserProfileSheet(
                                            user: member,
                                          );
                                        }
                                      },
                                      itemBuilder: (BuildContext context) =>
                                          <PopupMenuEntry<String>>[
                                            PopupMenuItem<String>(
                                              value: 'toggle_admin',
                                              child: Row(
                                                children: <Widget>[
                                                  Icon(
                                                    memberIsAdmin
                                                        ? Icons
                                                              .person_remove_rounded
                                                        : Icons.stars_rounded,
                                                    color: AppColors.aqua,
                                                    size: 18,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    memberIsAdmin
                                                        ? (isAr
                                                              ? 'إلغاء الإشراف'
                                                              : 'Dismiss as Admin')
                                                        : (isAr
                                                              ? 'ترقية إلى مشرف ⭐'
                                                              : 'Make Group Admin ⭐'),
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            PopupMenuItem<String>(
                                              value: 'info',
                                              child: Row(
                                                children: <Widget>[
                                                  const Icon(
                                                    Icons.info_outline_rounded,
                                                    color: Colors.white70,
                                                    size: 18,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    isAr
                                                        ? 'معلومات المستخدم (@username)'
                                                        : 'User Info (@username)',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            PopupMenuItem<String>(
                                              value: 'remove',
                                              child: Row(
                                                children: <Widget>[
                                                  const Icon(
                                                    Icons
                                                        .remove_circle_outline_rounded,
                                                    color: AppColors.error,
                                                    size: 18,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    isAr
                                                        ? 'إزالة من المجموعة'
                                                        : 'Remove from Group',
                                                    style: const TextStyle(
                                                      color: AppColors.error,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                    )
                                  : IconButton(
                                      icon: Icon(
                                        Icons.info_outline_rounded,
                                        size: 19,
                                        color: AppColors.textSecondary,
                                      ),
                                      onPressed: () =>
                                          showOtherUserProfileSheet(
                                            user: member,
                                          ),
                                    ),
                            );
                          }).toList(),
                        ),
                ),
              ],
            ),
          );
        }),
        ),
      ),
    );
  }
}
