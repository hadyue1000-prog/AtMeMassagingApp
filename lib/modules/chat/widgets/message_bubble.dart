import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/supabase_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/other_user_profile_sheet.dart';
import '../../../data/models/message_model.dart';
import '../../../data/models/profile_model.dart';
import '../../home/home_controller.dart';
import '../chat_controller.dart';
import 'voice_message_player.dart';

/// Glassmorphism Chat Bubble matching the reference image:
/// - Outgoing (`isMine: true`): luminous cyan-ice frosted surface (`#D4F1FF` in dark
///   glass mode) with dark navy text and cyan double-ticks (`✓✓`).
/// - Incoming (`isMine: false`): deep translucent navy frosted surface (`#0D234A`)
///   with crisp white text and subtle cyan/white border.
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    required this.timeLabel,
    this.isStarred = false,
    this.senderDisplayName,
    this.onLongPress,
    this.onReplySwipe,
  });

  final MessageModel message;
  final bool isMine;
  final String timeLabel;
  final bool isStarred;
  final String? senderDisplayName;
  final VoidCallback? onLongPress;
  final VoidCallback? onReplySwipe;

  @override
  Widget build(BuildContext context) {
    final bool isDark = AppColors.isDark;
    final Color textColor =
        isMine ? AppColors.outgoingText : AppColors.incomingText;
    final Color metaColor = isMine
        ? AppColors.outgoingText.withValues(alpha: 0.72)
        : AppColors.textSecondary;

    final BorderRadius borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(20),
      topRight: const Radius.circular(20),
      bottomLeft: Radius.circular(isMine ? 6 : 20),
      bottomRight: Radius.circular(isMine ? 20 : 6),
    );

    final Gradient bubbleGradient = isMine
        ? (isDark
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  Color(0xE6E0F5FF),
                  Color(0xD9BBE6FF),
                ],
              )
            : AppColors.cyanButtonGradient)
        : (isDark
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  Color(0xD9102A5C),
                  Color(0xCC0A1C3E),
                ],
              )
            : AppColors.lightGlassCardGradient);

    final Color borderColor = isMine
        ? Colors.white.withValues(alpha: 0.65)
        : (isDark
            ? AppColors.aqua.withValues(alpha: 0.28)
            : AppColors.lightBorder);

    final Widget bubble = Align(
      alignment: isMine
          ? AlignmentDirectional.centerStart
          : AlignmentDirectional.centerEnd,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        child: GestureDetector(
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 14),
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 9, 14, 7),
              decoration: BoxDecoration(
                gradient: bubbleGradient,
                borderRadius: borderRadius,
                border: Border.all(color: borderColor, width: 1.0),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: isDark ? 0.16 : 0.05,
                    ),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  // Group Chat Sender Name Header
                  if (!isMine &&
                      senderDisplayName != null &&
                      senderDisplayName!.trim().isNotEmpty) ...<Widget>[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        senderDisplayName!,
                        style: const TextStyle(
                          color: AppColors.aqua,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],

                  // Quoted Reply Box (if this message is a reply)
                      if (message.hasReply) ...<Widget>[
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isMine
                                ? AppColors.deepNavy.withValues(alpha: 0.10)
                                : Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: BorderDirectional(
                              start: BorderSide(
                                color: isMine
                                    ? AppColors.royalBlue
                                    : AppColors.electricCyan,
                                width: 3.5,
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                message.replySenderName ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isMine
                                      ? AppColors.royalBlue
                                      : AppColors.aqua,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                message.replySnippet ?? '',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: textColor.withValues(alpha: 0.85),
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Message content (Text or Voice Note Player)
                      if (message.isAudio)
                        VoiceMessagePlayer(message: message, isMine: isMine)
                      else
                        _buildMentionRichText(
                          text: message.bodyText,
                          defaultTextColor: textColor,
                          isMine: isMine,
                          context: context,
                        ),

                      const SizedBox(height: 4),

                      // Starred badge + Timestamp + Read receipts (✓ sent / ✓✓ read)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: <Widget>[
                          if (isStarred) ...<Widget>[
                            const Icon(
                              Icons.star_rounded,
                              size: 13.5,
                              color: Colors.amber,
                            ),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            timeLabel,
                            style: TextStyle(
                              color: metaColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (isMine) ...<Widget>[
                            const SizedBox(width: 4),
                            Icon(
                              message.isPending
                                  ? Icons.schedule_rounded
                                  : (message.isRead
                                        ? Icons.done_all_rounded
                                        : Icons.done_rounded),
                              size: 15.5,
                              color: message.isPending
                                  ? Colors.amber.shade700
                                  : (message.isRead
                                        ? AppColors.readTickOnBubble
                                        : AppColors.unreadTickOnBubble),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );

    if (onReplySwipe == null) return bubble;

    return Dismissible(
      key: ValueKey<String>('swipe_reply_${message.id}'),
      direction: DismissDirection.startToEnd,
      confirmDismiss: (_) async {
        onReplySwipe?.call();
        return false;
      },
      background: Container(
        alignment: AlignmentDirectional.centerStart,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.electricCyan.withValues(alpha: 0.22),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.reply_rounded,
            color: AppColors.aqua,
            size: 20,
          ),
        ),
      ),
      child: bubble,
    );
  }

  Widget _buildMentionRichText({
    required String text,
    required Color defaultTextColor,
    required bool isMine,
    required BuildContext context,
  }) {
    final RegExp mentionRegex = RegExp(r'(@[a-zA-Z0-9_]{3,20})');
    if (!mentionRegex.hasMatch(text)) {
      return Text(
        text,
        style: TextStyle(
          color: defaultTextColor,
          fontSize: 15.5,
          height: 1.4,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    final List<InlineSpan> spans = <InlineSpan>[];
    int lastEnd = 0;

    for (final Match match in mentionRegex.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(
          TextSpan(
            text: text.substring(lastEnd, match.start),
            style: TextStyle(
              color: defaultTextColor,
              fontSize: 15.5,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      }

      final String mentionToken = match.group(0)!;
      final String cleanUsername = mentionToken.substring(1);

      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: GestureDetector(
            onTap: () => _handleMentionTap(cleanUsername),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(
                color: isMine
                    ? AppColors.deepNavy.withValues(alpha: 0.14)
                    : AppColors.electricCyan.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isMine
                      ? AppColors.royalBlue.withValues(alpha: 0.35)
                      : AppColors.aqua.withValues(alpha: 0.55),
                  width: 0.8,
                ),
              ),
              child: Text(
                mentionToken,
                style: TextStyle(
                  color: isMine ? AppColors.royalBlue : AppColors.aqua,
                  fontWeight: FontWeight.w900,
                  fontSize: 14.5,
                ),
              ),
            ),
          ),
        ),
      );

      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(lastEnd),
          style: TextStyle(
            color: defaultTextColor,
            fontSize: 15.5,
            height: 1.4,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return Text.rich(
      TextSpan(children: spans),
    );
  }

  void _handleMentionTap(String username) async {
    ProfileModel? found;
    if (Get.isRegistered<ChatController>()) {
      final ChatController chat = Get.find<ChatController>();
      for (final ProfileModel m in chat.groupMembersList) {
        if (m.username.toLowerCase() == username.toLowerCase()) {
          found = m;
          break;
        }
      }
      if (found == null &&
          chat.otherUser.value?.username.toLowerCase() ==
              username.toLowerCase()) {
        found = chat.otherUser.value;
      }
    }

    if (found == null && Get.isRegistered<HomeController>()) {
      final HomeController home = Get.find<HomeController>();
      for (final c in home.conversations) {
        if (c.otherUser?.username.toLowerCase() == username.toLowerCase()) {
          found = c.otherUser;
          break;
        }
      }
      if (found == null) {
        for (final s in home.statusUsers) {
          if (s.username.toLowerCase() == username.toLowerCase()) {
            found = s;
            break;
          }
        }
      }
    }

    if (found == null) {
      try {
        final Map<String, dynamic>? row = await supabase
            .from(SupabaseConstants.profilesTable)
            .select(SupabaseConstants.publicProfileColumns)
            .eq('username', username.toLowerCase())
            .maybeSingle();
        if (row != null) {
          found = ProfileModel.fromJson(row);
        }
      } catch (_) {}
    }

    if (found != null) {
      showOtherUserProfileSheet(
        user: found,
        onMessageTap: () {
          if (Get.isRegistered<HomeController>()) {
            Get.find<HomeController>().openOrStartChatWithUser(found!);
          }
        },
      );
    }
  }
}

/// Alias for `MessageBubble` to support `GlassMessageBubble` naming across the design system.
typedef GlassMessageBubble = MessageBubble;
