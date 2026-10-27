import 'package:get/get.dart';

import 'search_controller.dart';

/// Binding for the `/search` route.
class SearchBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<UserSearchController>(() => UserSearchController());
  }
}
