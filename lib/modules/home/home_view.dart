import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/routes/app_routes.dart';
import '../../core/services/app_preferences_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass_widgets.dart';
import 'home_controller.dart';
import 'tabs/chats_tab_view.dart';
import 'tabs/profile_tab_view.dart';
import 'tabs/settings_tab_view.dart';
import 'tabs/statuses_tab_view.dart';
import 'widgets/create_group_sheet.dart';

class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  String _titleForTab(int index) {
    switch (index) {
      case 0:
        return 'Me@';
      case 1:
        return 'statuses_title'.tr;
      case 2:
        return 'profile_section_title'.tr;
      case 3:
        return 'settings_section_title'.tr;
      default:
        return 'AtMe';
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppPreferencesService prefs = AppPreferencesService.to;

    return Obx(() {
      final bool isDark = prefs.isDarkMode.value;
      final String _ = prefs.languageCode.value;
      final int currentIndex = controller.selectedTabIndex.value;
      final int unreadCount = controller.totalUnreadCount;

      return GlassScaffoldBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          extendBody: true,
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(66),
            child: ClipRect(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: isDark
                          ? <Color>[
                              const ui.Color.fromARGB(20, 13, 40, 94),
                              const ui.Color.fromARGB(0, 7, 21, 46),
                            ]
                          : <Color>[
                              const ui.Color.fromARGB(5, 255, 255, 255),
                              const ui.Color.fromARGB(8, 255, 255, 255),
                            ],
                    ),
                    border: Border(
                      bottom: BorderSide(
                        color: isDark
                            ? AppColors.aqua.withValues(alpha: 0.22)
                            : AppColors.lightBorder,
                      ),
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 860),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: <Widget>[

                              Expanded(
                                child: Text(
                                  _titleForTab(currentIndex),
                                  style: TextStyle(
                                    fontSize: 19.5,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: IndexedStack(
                index: currentIndex,
                children: const <Widget>[
                  ChatsTabView(),
                  StatusesTabView(),
                  ProfileTabView(),
                  SettingsTabView(),
                ],
              ),
            ),
          ),
          floatingActionButton: currentIndex == 0
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      GlassIconButton(
                        icon: Icons.group_add_rounded,
                        size: 46,
                        iconSize: 22,
                        isActive: true,
                        tooltip: prefs.isArabic
                            ? 'إنشاء مجموعة جديدة'
                            : 'Create New Group',
                        onTap: () => showCreateGroupBottomSheet(controller),
                      ),
                      const SizedBox(height: 10),
                      GlowingCyanCircleButton(
                        icon: Icons.create_rounded,
                        size: 58,
                        iconSize: 25,
                        tooltip: 'new_chat_tooltip'.tr,
                        onTap: () => _showNewChatOrGroupMenu(context, prefs),
                      ),
                    ],
                  ),
                )
              : null,
          bottomNavigationBar: GlassNavigationBar(
            currentIndex: currentIndex,
            unreadCount: unreadCount,
            onTap: controller.changeTab,
          ),
        ),
      );
    });
  }

  void _showNewChatOrGroupMenu(
    BuildContext context,
    AppPreferencesService prefs,
  ) {
    final bool isAr = prefs.isArabic;
    Get.bottomSheet(
      GlassBottomSheet(
        title: isAr ? 'بدء تواصل جديد' : 'Start New Chat',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              leading: const Icon(
                Icons.person_search_rounded,
                color: AppColors.aqua,
              ),
              title: Text(
                isAr ? 'محادثة جديدة / بحث عن صديق' : 'New Chat / Find Friend',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                isAr
                    ? 'بحث عام أو إضافة صديق عبر كود/رابط خاص'
                    : 'Public search or add via private code/link',
              ),
              onTap: () {
                Get.back<void>();
                Get.toNamed(AppRoutes.search);
              },
            ),
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              leading: const Icon(
                Icons.group_add_rounded,
                color: AppColors.aqua,
              ),
              title: Text(
                isAr ? 'إنشاء مجموعة جديدة 👥' : 'Create New Group 👥',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                isAr
                    ? 'مجموعة مع مدير وصلاحيات مخصصة للأعضاء'
                    : 'Group chat with admin controls & permissions',
              ),
              onTap: () {
                Get.back<void>();
                showCreateGroupBottomSheet(controller);
              },
            ),
          ],
        ),
      ),
    );
  }
}
