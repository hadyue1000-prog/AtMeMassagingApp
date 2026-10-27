import 'package:get/get.dart';

/// Bilingual translations (Arabic `ar` & English `en`) for AtMe (@Me).
class AppTranslations extends Translations {
  @override
  Map<String, Map<String, String>> get keys => <String, Map<String, String>>{
        'ar': <String, String>{
          // Navigation
          'nav_chats': 'المحادثات',
          'nav_statuses': 'الحالات',
          'nav_profile': 'حسابي',
          'nav_settings': 'الإعدادات',

          // Auth
          'welcome_title': 'أهلاً بك 👋',
          'welcome_subtitle':
              'سجّل دخولك باستخدام بريدك الإلكتروني فقط،\nوسنرسل لك رمز تحقق مكوّناً من 6 أرقام.',
          'email_label': 'البريد الإلكتروني',
          'send_otp_btn': 'إرسال رمز التحقق',
          'privacy_note':
              'لا نطلب رقم هاتفك أبداً. سيجدك أصدقاؤك عبر @username فقط، ولن يظهر بريدك الإلكتروني لأي شخص.',
          'verify_email_title': 'تحقّق من بريدك الإلكتروني ✉️',
          'verify_email_subtitle':
              'أدخل رمز التحقق المكوّن من 6 أرقام المرسل إلى:',
          'edit': 'تعديل',
          'verify_otp_btn': 'تأكيد الرمز والمتابعة',
          'resend_in': 'يمكنك إعادة إرسال الرمز خلال ',
          'resend_code': 'إعادة إرسال الرمز',
          'setup_account_title': 'إعداد الحساب',
          'switch_account': 'تبديل الحساب',
          'complete_profile_title': 'أكمل ملفك الشخصي في @Me',
          'complete_profile_subtitle':
              'اختر اسماً ظاهراً ومعرّف @username فريداً ليبحث عنك أصدقاؤك بسهولة.',
          'display_name_label': 'الاسم الظاهر (Display Name)',
          'display_name_hint': 'مثال: أحمد محمد',
          'username_label': 'اسم المستخدم الفريد (@username)',
          'username_rules':
              'يُسمح بالأحرف الإنجليزية الصغيرة (a-z)، الأرقام (0-9)، والشرطة السفلية (_) من 3 إلى 20 حرفاً.',
          'save_and_start': 'حفظ والبدء بالمراسلة',

          // Home & Chats
          'search_chats_hint': 'ابحث في محادثاتك أو الرسائل...',
          'filter_all': 'الكل',
          'filter_unread': 'غير مقروءة',
          'filter_online': 'متصل الآن',
          'filter_pinned': 'المثبّتة 📌',
          'mark_all_read': 'تعليم الكل كمقروء',
          'new_chat_tooltip': 'محادثة جديدة عبر @username',
          'no_chats_title': 'لا توجد محادثات بعد',
          'no_chats_subtitle':
              'ابحث عن أصدقائك عبر معرّف @username الخاص بهم وابدأ محادثة فورية بالنص أو الصوت.',
          'search_by_username': 'ابحث عبر @username',
          'start_chat_now': 'ابدأ المحادثة الآن 👋',
          'draft_prefix': 'مسودة',
          'yesterday': 'أمس',
          'today': 'اليوم',
          'retry': 'إعادة المحاولة',
          'show_all_chats': 'عرض كل المحادثات',
          'no_filter_matches': 'لا توجد محادثات مطابقة للفلتر أو البحث الحالي',
          'offline_cached_banner':
              'وضع عدم الاتصال — يتم عرض المحادثات المحفوظة محلياً',

          // Conversation Context Menu
          'pin_chat': 'تثبيت المحادثة في الأعلى',
          'unpin_chat': 'إلغاء تثبيت المحادثة',
          'mute_chat': 'كتم إشعارات المحادثة',
          'unmute_chat': 'تفعيل الإشعارات',
          'mark_as_read': 'تعليم الرسائل كمقروءة',
          'delete_chat': 'حذف المحادثة',

          // Written Statuses (الحالات المكتوبة)
          'statuses_title': 'الحالات المكتوبة',
          'my_status': 'حالتي المكتوبة',
          'tap_to_add_status': 'اضغط لكتابة حالة جديدة...',
          'write_status_title': 'كتابة حالة جديدة',
          'write_status_hint': 'بماذا تفكر الآن؟ اكتب حالتك هنا...',
          'publish_status': 'نشر الحالة',
          'clear_status': 'حذف حالتي الحالية',
          'recent_statuses': 'حالات الأصدقاء والمستخدمين',
          'no_statuses_yet': 'لا توجد حالات مكتوبة حالياً',
          'no_statuses_subtitle':
              'كن أول من يشارك حالة مكتوبة مع أصدقائك اليوم!',
          'status_published': 'تم نشر حالتك المكتوبة بنجاح ✨',
          'status_cleared': 'تم حذف حالتك المكتوبة',
          'reply_to_status': 'مراسلة صاحب الحالة',

          // Profile Tab (قسم البروفايل المستقل)
          'profile_section_title': 'الملف الشخصي',
          'personal_info': 'المعلومات الشخصية',
          'bio_label': 'النبذة الشخصية (Bio)',
          'bio_hint': 'اكتب نبذة قصيرة تعرّف بك...',
          'save_changes': 'حفظ التغييرات',
          'copy_username': 'نسخ المعرّف',
          'username_copied': 'تم نسخ المعرّف إلى الحافظة',
          'account_id_readonly': 'معرّف الحساب الفريد (لا يمكن تغييره)',
          'email_readonly': 'البريد الإلكتروني المرتبط',
          'member_since': 'تاريخ الانضمام',
          'online_now': 'متصل الآن',
          'offline': 'غير متصل',

          // Settings Tab (قسم الإعدادات المستقل)
          'settings_section_title': 'الإعدادات',
          'appearance_and_lang': 'المظهر واللغة',
          'dark_mode_title': 'الوضع الليلي (Dark Mode)',
          'dark_mode_on': 'مفعّل حالياً',
          'dark_mode_off': 'الوضع الفاتح مفعّل حالياً',
          'language_title': 'لغة التطبيق (Language)',
          'lang_ar': 'العربية',
          'lang_en': 'English',
          'custom_bg_title': 'خلفية التطبيق المخصصة',
          'custom_bg_sub': 'اختر صورة من جهازك لتكون خلفية لجميع شاشات التطبيق والمحادثات',
          'upload_bg_btn': 'رفع صورة للخلفية',
          'change_bg_btn': 'تغيير الصورة',
          'reset_bg_btn': 'استعادة الخلفية الافتراضية',
          'bg_dim_label': 'درجة تعتيم الخلفية لوضوح الزجاج',
          'bg_updated_msg': 'تم تحديث خلفية التطبيق بنجاح ✨',
          'bg_reset_msg': 'تمت استعادة الخلفية الزجاجية الافتراضية',
          'privacy_and_security': 'الخصوصية والأمان',
          'discoverable_title': 'رؤية حسابي للأشخاص الآخرين',
          'discoverable_on_sub':
              'حسابك عام ويمكن للآخرين البحث عنك عبر @username وعرض ملفك',
          'discoverable_off_sub':
              'حسابك مخفي ولن يظهر للآخرين في نتائج البحث أو الحالات',
          'storage_and_cache': 'التخزين المحلي والعمل بدون إنترنت',
          'offline_storage_title': 'حفظ المحادثات محلياً (Offline Mode)',
          'offline_storage_sub':
              'يتم حفظ المحادثات والرسائل تلقائياً لفتحها حتى بدون اتصال بالإنترنت',
          'clear_local_cache': 'مسح الذاكرة المؤقتة المحلية',
          'clear_local_cache_sub': 'إعادة مزامنة الرسائل من الخادم عند الاتصال',
          'cache_cleared_msg': 'تم مسح الذاكرة المؤقتة المحلية بنجاح',
          'account_section': 'الحساب والجلسة',
          'sign_out': 'تسجيل الخروج',
          'sign_out_confirm_title': 'تأكيد تسجيل الخروج',
          'sign_out_confirm_body':
              'سيتم إنهاء الجلسة الحالية وتدمير بيانات الدخول المحفوظة محلياً على هذا الجهاز.',
          'cancel': 'إلغاء',

          // Chat Screen
          'typing_now': 'يكتب الآن...',
          'search_in_chat_hint': 'ابحث داخل هذه المحادثة...',
          'starred_only_banner': 'عرض الرسائل المميزة بنجمة فقط',
          'clear_filter': 'إلغاء الفلتر',
          'type_message_hint': 'اكتب رسالتك هنا...',
          'uploading_voice': 'جارٍ رفع وإرسال الرسالة الصوتية...',
          'voice_note_label': 'رسالة صوتية',
          'reply_to': 'الرد على',
          'you': 'أنت',
          'reply_action': 'الرد على الرسالة',
          'copy_text_action': 'نسخ النص',
          'star_action': 'تمييز الرسالة بنجمة ⭐',
          'unstar_action': 'إزالة من الرسائل المميزة بنجمة',
          'delete_msg_action': 'حذف الرسالة',
          'start_chat_Sub':
              'أرسل رسالة نصية أو سجّل رسالة صوتية عبر زر الميكروفون.',
          'no_matching_messages': 'لا توجد رسائل مطابقة',
          'view_profile': 'عرض الحساب',
          'message_btn': 'مراسلة',
          'Suggested_users': 'مستخدمون مقترحون في @Me',
          'only_admins_can_send_banner':
              'إرسال الرسائل مقتصر على مشرفي المجموعة فقط 🔒',
          'pending_offline_msg':
              'سيتم إرسال الرسالة تلقائياً عند توفر الإنترنت',
          'private_code_copied': 'تم نسخ كود الإضافة الخاص',
          'private_link_copied': 'تم نسخ رابط الدعوة الخاص',
          'built_in_wallpapers': 'خلفيات التطبيق المدمجة',
          'my_status_wa': 'حالتي',
          'recent_updates': 'التحديثات الحديثة',
          'viewed_updates': 'التحديثات التي تمت مشاهدتها',
          'reply_status_hint': 'الرد على الحالة...',
          'group_info': 'معلومات المجموعة',
          'group_owner': 'مدير الجروب 👑',
          'group_admin': 'مشرف ⭐',
        },
        'en': <String, String>{
          // Navigation
          'nav_chats': 'Chats',
          'nav_statuses': 'Statuses',
          'nav_profile': 'Profile',
          'nav_settings': 'Settings',

          // Auth
          'welcome_title': 'Welcome 👋',
          'welcome_subtitle':
              'Sign in using only your email address,\nand we will send you a 6-digit verification code.',
          'email_label': 'Email Address',
          'send_otp_btn': 'Send Verification Code',
          'privacy_note':
              'We never ask for your phone number. Friends find you via @username only, and your email stays private.',
          'verify_email_title': 'Check Your Email ✉️',
          'verify_email_subtitle':
              'Enter the 6-digit verification code sent to:',
          'edit': 'Edit',
          'verify_otp_btn': 'Verify & Continue',
          'resend_in': 'You can resend the code in ',
          'resend_code': 'Resend Code',
          'setup_account_title': 'Account Setup',
          'switch_account': 'Switch Account',
          'complete_profile_title': 'Complete Your @Me Profile',
          'complete_profile_subtitle':
              'Choose a display name and a unique @username so friends can find you easily.',
          'display_name_label': 'Display Name',
          'display_name_hint': 'e.g. Ahmed Mohammed',
          'username_label': 'Unique Handle (@username)',
          'username_rules':
              'Lowercase letters (a-z), digits (0-9), and underscores (_) from 3 to 20 characters.',
          'save_and_start': 'Save & Start Messaging',

          // Home & Chats
          'search_chats_hint': 'Search your chats or messages...',
          'filter_all': 'All',
          'filter_unread': 'Unread',
          'filter_online': 'Online',
          'filter_pinned': 'Pinned 📌',
          'mark_all_read': 'Mark all as read',
          'new_chat_tooltip': 'New chat via @username',
          'no_chats_title': 'No conversations yet',
          'no_chats_subtitle':
              'Find your friends via their @username and start chatting with text or voice notes.',
          'search_by_username': 'Search by @username',
          'start_chat_now': 'Start chatting now 👋',
          'draft_prefix': 'Draft',
          'yesterday': 'Yesterday',
          'today': 'Today',
          'retry': 'Retry',
          'show_all_chats': 'Show all chats',
          'no_filter_matches': 'No conversations match the current filter',
          'offline_cached_banner':
              'Offline Mode — Showing locally saved conversations',

          // Conversation Context Menu
          'pin_chat': 'Pin conversation to top',
          'unpin_chat': 'Unpin conversation',
          'mute_chat': 'Mute notifications',
          'unmute_chat': 'Unmute notifications',
          'mark_as_read': 'Mark messages as read',
          'delete_chat': 'Delete conversation',

          // Written Statuses
          'statuses_title': 'Written Statuses',
          'my_status': 'My Written Status',
          'tap_to_add_status': 'Tap to write a new status...',
          'write_status_title': 'Write a Status',
          'write_status_hint': 'What is on your mind? Write your status...',
          'publish_status': 'Publish Status',
          'clear_status': 'Delete Current Status',
          'recent_statuses': 'Friends & Community Statuses',
          'no_statuses_yet': 'No written statuses yet',
          'no_statuses_subtitle':
              'Be the first to share a written status with your friends today!',
          'status_published': 'Your written status is now live ✨',
          'status_cleared': 'Your written status was removed',
          'reply_to_status': 'Message User',

          // Profile Tab
          'profile_section_title': 'My Profile',
          'personal_info': 'Personal Information',
          'bio_label': 'Bio / About Me',
          'bio_hint': 'Write a short bio about yourself...',
          'save_changes': 'Save Changes',
          'copy_username': 'Copy Handle',
          'username_copied': 'Handle copied to clipboard',
          'account_id_readonly': 'Unique Handle (Read-only)',
          'email_readonly': 'Linked Email Address',
          'member_since': 'Member Since',
          'online_now': 'Online now',
          'offline': 'Offline',

          // Settings Tab
          'settings_section_title': 'Settings',
          'appearance_and_lang': 'Appearance & Language',
          'dark_mode_title': 'Dark Mode',
          'dark_mode_on': 'Currently enabled',
          'dark_mode_off': 'Light mode is active',
          'language_title': 'App Language (اللغة)',
          'lang_ar': 'العربية',
          'lang_en': 'English',
          'custom_bg_title': 'Custom App Wallpaper',
          'custom_bg_sub': 'Upload a photo from your device as the background across all screens',
          'upload_bg_btn': 'Upload Wallpaper',
          'change_bg_btn': 'Change Photo',
          'reset_bg_btn': 'Reset Default',
          'bg_dim_label': 'Wallpaper Dimming & Glass Contrast',
          'bg_updated_msg': 'App wallpaper updated ✨',
          'bg_reset_msg': 'Restored default glassmorphism background',
          'privacy_and_security': 'Privacy & Visibility',
          'discoverable_title': 'Allow Others to See My Account',
          'discoverable_on_sub':
              'Your account is public and searchable via @username',
          'discoverable_off_sub':
              'Your account is hidden from @username search and statuses',
          'storage_and_cache': 'Offline Storage & Cache',
          'offline_storage_title': 'Offline Chat Persistence',
          'offline_storage_sub':
              'Chats and messages are automatically saved locally so they open without internet',
          'clear_local_cache': 'Clear Local Cache',
          'clear_local_cache_sub': 'Re-sync messages from server when online',
          'cache_cleared_msg': 'Local offline cache cleared',
          'account_section': 'Account & Session',
          'sign_out': 'Sign Out',
          'sign_out_confirm_title': 'Confirm Sign Out',
          'sign_out_confirm_body':
              'Your current session and locally cached login credentials on this device will be destroyed.',
          'cancel': 'Cancel',

          // Chat Screen
          'typing_now': 'typing...',
          'search_in_chat_hint': 'Search in this conversation...',
          'starred_only_banner': 'Showing starred messages only',
          'clear_filter': 'Clear filter',
          'type_message_hint': 'Type a message...',
          'uploading_voice': 'Uploading & sending voice note...',
          'voice_note_label': 'Voice note',
          'reply_to': 'Reply to',
          'you': 'You',
          'reply_action': 'Reply',
          'copy_text_action': 'Copy text',
          'star_action': 'Star message ⭐',
          'unstar_action': 'Remove star',
          'delete_msg_action': 'Delete message',
          'start_chat_Sub':
              'Send a text message or record a voice note using the microphone button.',
          'no_matching_messages': 'No matching messages',
          'view_profile': 'View Profile',
          'message_btn': 'Message',
          'Suggested_users': 'Suggested Users on @Me',
          'only_admins_can_send_banner':
              'Only group admins can send messages 🔒',
          'pending_offline_msg':
              'Message will be sent automatically when you are back online',
          'private_code_copied': 'Private invite code copied',
          'private_link_copied': 'Private invite link copied',
          'built_in_wallpapers': 'Built-in Wallpapers',
          'my_status_wa': 'My Status',
          'recent_updates': 'Recent updates',
          'viewed_updates': 'Viewed updates',
          'reply_status_hint': 'Reply to status...',
          'group_info': 'Group Info',
          'group_owner': 'Owner 👑',
          'group_admin': 'Admin ⭐',
        },
      };
}
