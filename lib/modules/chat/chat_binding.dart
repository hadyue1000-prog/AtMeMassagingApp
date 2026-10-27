import 'package:get/get.dart';

import 'chat_controller.dart';

/// Binding for the `/chat` route.
class ChatBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ChatController>(() => ChatController());
  }
}
