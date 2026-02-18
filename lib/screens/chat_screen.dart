import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:g11chat_app/models/app_user_model.dart';
import 'package:g11chat_app/models/chat_model.dart';
import 'package:g11chat_app/models/message_model.dart';
import 'package:g11chat_app/screens/message_bubble.dart';
import 'package:g11chat_app/screens/users_screen.dart';
import 'package:g11chat_app/services/auth_service.dart';
import 'package:g11chat_app/services/chat_service.dart';
import 'package:g11chat_app/theme/app_colors.dart';
import 'package:g11chat_app/theme/app_text_styles.dart';
import 'package:image_picker/image_picker.dart';

class ChatScreen extends StatefulWidget {
  final String receiverId;
  final String receiverEmail;
  final String? chatIdOverride;

  const ChatScreen({
    super.key,
    required this.receiverId,
    required this.receiverEmail,
    this.chatIdOverride,
  });

  const ChatScreen.empty({
    super.key,
  }) : receiverId = "",
       receiverEmail = "",
       chatIdOverride = null;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final AuthService _authService = AuthService();
  final ChatService _chatService = ChatService();
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _sending = false;
  bool _isMarkingRead = false;
  bool _didInitialScroll = false;
  bool _scrollAfterSend = false;
  bool _isTyping = false;
  bool _handledMissingUser = false;
  bool _isReadMarkQueued = false;
  Timer? _typingDebounce;
  bool get _hasActiveChat => widget.receiverId.trim().isNotEmpty;
  String _chatIdFor(String currentUserId) {
    final override = widget.chatIdOverride?.trim() ?? "";
    if (override.isNotEmpty) return override;
    return _chatService.chatId(currentUserId, widget.receiverId);
  }

  @override
  void initState() {
    super.initState();
    if (_hasActiveChat) {
      _markChatAsRead();
      _messageController.addListener(_handleTypingChanged);
    }
  }

  @override
  void dispose() {
    if (_hasActiveChat && _isTyping) {
      final currentUser = _authService.currentUser;
      if (currentUser != null) {
        unawaited(
          _chatService.setTypingStatus(
            currentUserId: currentUser.uid,
            otherUserId: widget.receiverId,
            isTyping: false,
            chatIdOverride: _chatIdFor(currentUser.uid),
          ),
        );
      }
    }
    _typingDebounce?.cancel();
    _messageController.removeListener(_handleTypingChanged);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _markChatAsRead() async {
    final currentUser = _authService.currentUser;
    if (currentUser == null || _isMarkingRead) return;

    _isMarkingRead = true;

    try {
      await _chatService.markChatAsRead(
        currentUserId: currentUser.uid,
        otherUserId: widget.receiverId,
        chatIdOverride: _chatIdFor(currentUser.uid),
      ).timeout(const Duration(seconds: 12));
    } finally {
      _isMarkingRead = false;
    }
  }

  Future<void> _sendMessage() async {
    final currentUser = _authService.currentUser;
    if (currentUser == null || _sending || !_hasActiveChat) return;

    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final receiverDoc = await FirebaseFirestore.instance
        .collection("users")
        .doc(widget.receiverId)
        .get();
    if (!receiverDoc.exists) {
      if (mounted && !_handledMissingUser) {
        _handledMissingUser = true;
        Navigator.of(context).maybePop();
      }
      if (!mounted) return;
      return;
    }

    setState(() => _sending = true);

    try {
      await _chatService.sendMessage(
        senderId: currentUser.uid,
        receiverId: widget.receiverId,
        text: text,
        chatIdOverride: _chatIdFor(currentUser.uid),
      ).timeout(const Duration(seconds: 15));

      _messageController.clear();
      await _setTyping(false);
      _scrollAfterSend = true;
    } on TimeoutException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Mtandao ni wa polepole. Jaribu tena.")),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Imeshindikana kutuma ujumbe.")),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickAndSendImage() async {
    final currentUser = _authService.currentUser;
    if (currentUser == null || _sending || !_hasActiveChat) return;

    final receiverDoc = await FirebaseFirestore.instance
        .collection("users")
        .doc(widget.receiverId)
        .get();
    if (!receiverDoc.exists) {
      if (mounted && !_handledMissingUser) {
        _handledMissingUser = true;
        Navigator.of(context).maybePop();
      }
      return;
    }

    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 55,
      maxWidth: 1280,
      maxHeight: 1280,
    );
    if (file == null) return;

    setState(() => _sending = true);
    try {
      final bytes = await file.readAsBytes();
      final imageBase64 = base64Encode(bytes);

      await _chatService.sendImageMessage(
        senderId: currentUser.uid,
        receiverId: widget.receiverId,
        imageBase64: imageBase64,
        chatIdOverride: _chatIdFor(currentUser.uid),
      ).timeout(const Duration(seconds: 20));

      _scrollAfterSend = true;
    } on TimeoutException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Mtandao ni wa polepole. Jaribu tena.")),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Imeshindikana kutuma picha.")),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _setTyping(bool value) async {
    if (!_hasActiveChat || _isTyping == value) return;
    final currentUser = _authService.currentUser;
    if (currentUser == null) return;
    _isTyping = value;
    try {
      await _chatService.setTypingStatus(
        currentUserId: currentUser.uid,
        otherUserId: widget.receiverId,
        isTyping: value,
        chatIdOverride: _chatIdFor(currentUser.uid),
      );
    } catch (_) {}
  }

  void _handleTypingChanged() {
    final hasText = _messageController.text.trim().isNotEmpty;
    _typingDebounce?.cancel();
    _typingDebounce = Timer(const Duration(milliseconds: 260), () {
      if (!mounted) return;
      if (hasText != _isTyping) {
        unawaited(_setTyping(hasText));
      }
    });
  }

  void _queueMarkChatAsRead() {
    if (_isReadMarkQueued || _isMarkingRead) return;
    _isReadMarkQueued = true;
    Timer(const Duration(milliseconds: 180), () async {
      if (!mounted) return;
      _isReadMarkQueued = false;
      await _markChatAsRead();
    });
  }

  void _scrollToBottom({bool animated = false}) {
    if (!_scrollController.hasClients) return;
    final target = _scrollController.position.maxScrollExtent;
    if (animated) {
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
      return;
    }
    _scrollController.jumpTo(target);
  }

  String _formatMessageTime(Timestamp? timestamp) {
    if (timestamp == null) return "";
    final dt = timestamp.toDate();
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return "$hh:$mm";
  }

  String _lastSeenLabel(Timestamp? timestamp) {
    if (timestamp == null) return "Offline";
    final dt = timestamp.toDate();
    final now = DateTime.now();
    final isToday =
        dt.year == now.year && dt.month == now.month && dt.day == now.day;
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    if (isToday) return "Last seen $hh:$mm";
    final dd = dt.day.toString().padLeft(2, '0');
    final mo = dt.month.toString().padLeft(2, '0');
    return "Last seen $dd/$mo $hh:$mm";
  }

  bool _isRecentlyActive(Timestamp? timestamp) {
    if (timestamp == null) return false;
    final secondsSinceLastSeen =
        DateTime.now().difference(timestamp.toDate()).inSeconds;
    return secondsSinceLastSeen <= 70;
  }

  bool _hasUnreadIncoming({
    required List<MessageModel> messages,
    required String currentUserId,
  }) {
    for (final message in messages) {
      final isIncoming = message.receiverId == currentUserId;
      final unread = message.readAt == null;
      if (isIncoming && unread) return true;
    }
    return false;
  }

  MessageDeliveryStatus _messageStatus(MessageModel message) {
    if (message.hasPendingWrites) return MessageDeliveryStatus.sent;
    if (message.readAt != null) return MessageDeliveryStatus.read;
    if (message.deliveredAt != null) return MessageDeliveryStatus.delivered;
    return MessageDeliveryStatus.sent;
  }

  Future<void> _confirmDeleteMessage({
    required BuildContext context,
    required MessageModel message,
    required String currentUserId,
  }) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Delete for me"),
          content: const Text(
            "Ujumbe huu utaondoka kwako tu. Kwa mwingine utaendelea kuwepo.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text("Cancel"),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text("Delete"),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;

    await _chatService.deleteMessageForMe(
      currentUserId: currentUserId,
      otherUserId: widget.receiverId,
      messageId: message.id,
      chatIdOverride: _chatIdFor(currentUserId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _authService.currentUser;
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text("No authenticated user")),
      );
    }

    if (!_hasActiveChat) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.bgTop, AppColors.bgBottom],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(36),
                border: Border.all(color: AppColors.borderBlue, width: 2),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 52,
                    color: AppColors.primaryDarkBlue,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Bado hujaanza mazungumzo.",
                    textAlign: TextAlign.center,
                    style: AppTextStyles.listSubtitle,
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const UsersScreen()),
                      );
                    },
                    child: const Text("Anza Chat"),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final chatId = _chatIdFor(currentUser.uid);
    final messagesStream = _chatService.messagesStream(chatId);

    return Scaffold(
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.bgTop, AppColors.bgBottom],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF9ED2E0), Color(0xFF78C2D8)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(42),
                border: Border.all(color: AppColors.borderBlue, width: 2),
              ),
              child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 12, 12, 10),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: AppColors.primaryDarkBlue,
                          size: 30,
                        ),
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      const CircleAvatar(
                        radius: 18,
                        backgroundColor: AppColors.card,
                        child: Icon(
                          Icons.person,
                          color: AppColors.primaryDarkBlue,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance
                              .collection("users")
                              .doc(widget.receiverId)
                              .snapshots(),
                          builder: (context, userSnapshot) {
                            final userDoc = userSnapshot.data;
                            final userDeleted = userDoc != null && !userDoc.exists;
                            if (userDeleted) {
                              if (!_handledMissingUser) {
                                _handledMissingUser = true;
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  if (!mounted) return;
                                  Navigator.of(context).maybePop();
                                });
                              }
                              return const SizedBox.shrink();
                            }
                            if (!userSnapshot.hasData) return const SizedBox.shrink();
                            final user = AppUserModel.fromFirestore(userDoc!);

                            final resolvedTitle = user.displayName.isEmpty
                                ? widget.receiverEmail
                                : user.displayName;

                            return StreamBuilder<ChatModel?>(
                              stream: _chatService.chatStream(chatId),
                              builder: (context, chatSnapshot) {
                                final chat = chatSnapshot.data;
                                final receiverTyping =
                                    chat?.isTyping(widget.receiverId) ?? false;
                                final isOnline = user.isOnline &&
                                    _isRecentlyActive(user.lastSeen);
                                final statusLabel = receiverTyping
                                    ? "typing..."
                                    : isOnline
                                        ? "Online"
                                        : _lastSeenLabel(user.lastSeen);
                                final statusColor = receiverTyping
                                    ? AppColors.primaryDarkBlue
                                    : isOnline
                                        ? const Color(0xFF1B8F3F)
                                        : AppColors.accentText;

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      resolvedTitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AppColors.primaryDarkBlue,
                                        fontSize: 28,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: statusColor,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          statusLabel,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: statusColor,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: StreamBuilder<List<MessageModel>>(
                    stream: messagesStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primaryDarkBlue,
                          ),
                        );
                      }
                      if (snapshot.hasError) {
                        return const Center(
                          child: Text(
                            "Imeshindikana kupakia chat.",
                            style: TextStyle(color: AppColors.accentText),
                          ),
                        );
                      }

                      final messages = (snapshot.data ?? const <MessageModel>[])
                          .where((m) => !m.isDeletedFor(currentUser.uid))
                          .toList();
                      if (messages.isEmpty) {
                        return const Center(
                          child: Text(
                            "Anza mazungumzo sasa.",
                            style: TextStyle(color: AppColors.accentText),
                          ),
                        );
                      }

                      if (!_didInitialScroll) {
                        _didInitialScroll = true;
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _scrollToBottom();
                        });
                      }

                      if (_scrollAfterSend) {
                        _scrollAfterSend = false;
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _scrollToBottom(animated: true);
                        });
                      }

                      if (_hasUnreadIncoming(
                        messages: messages,
                        currentUserId: currentUser.uid,
                      )) {
                        _queueMarkChatAsRead();
                      }

                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[index];
                          final isMe = message.senderId == currentUser.uid;
                          final status = _messageStatus(message);
                          final timeLabel = _formatMessageTime(message.sentAt);

                          return MessageBubble(
                            text: message.text,
                            isMe: isMe,
                            timeLabel: timeLabel,
                            status: status,
                            imageBase64: message.imageBase64,
                            onLongPress: () => _confirmDeleteMessage(
                              context: context,
                              message: message,
                              currentUserId: currentUser.uid,
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.card.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(36),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 10,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: _sending ? null : _pickAndSendImage,
                          icon: const Icon(
                            Icons.image_outlined,
                            color: AppColors.primaryDarkBlue,
                            size: 30,
                          ),
                        ),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: TextField(
                              controller: _messageController,
                              textInputAction: TextInputAction.send,
                              minLines: 1,
                              maxLines: 5,
                              onSubmitted: (_) => _sendMessage(),
                              decoration: const InputDecoration(
                                hintText: "Text Message...",
                                hintStyle: TextStyle(color: Colors.black54),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _sending ? null : _sendMessage,
                          icon: _sending
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(
                                  Icons.send_rounded,
                                  color: AppColors.primaryDarkBlue,
                                  size: 28,
                                ),
                        ),
                      ],
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
