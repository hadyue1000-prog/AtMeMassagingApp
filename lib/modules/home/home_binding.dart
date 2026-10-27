import 'package:get/get.dart';

import 'home_controller.dart';

/// Binding for the `/home` route.
class HomeBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<HomeController>(() => HomeController());
  }
}
