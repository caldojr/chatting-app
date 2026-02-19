import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:g11chat_app/models/chat_model.dart';
import 'package:g11chat_app/services/auth_service.dart';

class ChatNotificationRepository {
  const ChatNotificationRepository._();

  static Stream<int> unreadCountStreamForUser(String userId) {
    return FirebaseFirestore.instance
        .collection('chats')
        .where('participants', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
          var total = 0;
          for (final doc in snapshot.docs) {
            total += ChatModel.fromFirestore(doc).unreadCountFor(userId);
          }
          return total;
        });
  }
}

class UnreadCountBuilder extends StatelessWidget {
  static final AuthService _authService = AuthService();
  final Widget Function(BuildContext context, int unreadCount) builder;

  const UnreadCountBuilder({
    super.key,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    final currentUser = _authService.currentUser;
    if (currentUser == null) {
      return builder(context, 0);
    }

    return StreamBuilder<int>(
      stream: ChatNotificationRepository.unreadCountStreamForUser(
        currentUser.uid,
      ),
      builder: (context, snapshot) {
        final unreadCount = snapshot.data ?? 0;
        return builder(context, unreadCount);
      },
    );
  }
}

class MessageNotificationDot extends StatelessWidget {
  final Widget child;

  const MessageNotificationDot({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return UnreadCountBuilder(
      builder: (context, unreadCount) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            child,
            if (unreadCount > 0)
              Positioned(
                right: -1,
                top: -1,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE53935),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
