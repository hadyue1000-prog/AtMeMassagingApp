import 'package:get/get.dart';

import '../../modules/auth/auth_binding.dart';
import '../../modules/auth/email_view.dart';
import '../../modules/auth/otp_view.dart';
import '../../modules/auth/setup_profile_view.dart';
import '../../modules/chat/chat_binding.dart';
import '../../modules/chat/chat_view.dart';
import '../../modules/home/home_binding.dart';
import '../../modules/home/home_view.dart';
import '../../modules/search/search_binding.dart';
import '../../modules/search/search_view.dart';
import 'app_routes.dart';

/// All GetX pages of AtMe (@Me).
class AppPages {
  AppPages._();

  static const String initial = AppRoutes.email;

  static const Duration _transitionDuration = Duration(milliseconds: 300);

  static final List<GetPage<dynamic>> routes = <GetPage<dynamic>>[
    // ------------------------------------------------------------- Auth
    GetPage<dynamic>(
      name: AppRoutes.email,
      page: () => const EmailView(),
      binding: AuthBinding(),
      transition: Transition.fadeIn,
      transitionDuration: _transitionDuration,
    ),
    GetPage<dynamic>(
      name: AppRoutes.otp,
      page: () => const OtpView(),
      binding: AuthBinding(),
      transition: Transition.cupertino,
      transitionDuration: _transitionDuration,
    ),
    GetPage<dynamic>(
      name: AppRoutes.setupProfile,
      page: () => const SetupProfileView(),
      binding: AuthBinding(),
      transition: Transition.fadeIn,
      transitionDuration: _transitionDuration,
    ),

    // ------------------------------------------------------------- Home
    GetPage<dynamic>(
      name: AppRoutes.home,
      page: () => const HomeView(),
      binding: HomeBinding(),
      transition: Transition.fadeIn,
      transitionDuration: _transitionDuration,
    ),

    // ------------------------------------------------------------- Search
    GetPage<dynamic>(
      name: AppRoutes.search,
      page: () => const SearchView(),
      binding: SearchBinding(),
      transition: Transition.cupertino,
      transitionDuration: _transitionDuration,
    ),

    // ------------------------------------------------------------- Chat
    GetPage<dynamic>(
      name: AppRoutes.chat,
      page: () => const ChatView(),
      binding: ChatBinding(),
      transition: Transition.cupertino,
      transitionDuration: _transitionDuration,
    ),
  ];
}
