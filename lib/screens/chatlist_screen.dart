import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:g11chat_app/models/app_user_model.dart';
import 'package:g11chat_app/models/auth_user_model.dart';
import 'package:g11chat_app/models/chat_model.dart';
import 'package:g11chat_app/screens/chat_screen.dart';
import 'package:g11chat_app/screens/profile_screen.dart';
import 'package:g11chat_app/screens/notific.dart';
import 'package:g11chat_app/services/auth_service.dart';
import 'package:g11chat_app/services/chat_service.dart';
import 'package:g11chat_app/theme/app_colors.dart';
import 'package:g11chat_app/theme/app_text_styles.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final AuthService _authService = AuthService();
  final ChatService _chatService = ChatService();
  final TextEditingController _searchController = TextEditingController();
  List<ChatModel> _cachedChats = const [];
  final Map<String, AppUserModel> _userPreviewCache = {};
  final Set<String> _loadingUserPreviews = <String>{};
  String _query = "";
  bool _isOpeningChat = false;

  bool _hasPreviewMeta(ChatParticipantMeta? meta) {
    if (meta == null) return false;
    return meta.name.trim().isNotEmpty ||
        meta.email.trim().isNotEmpty ||
        meta.photoUrl.trim().isNotEmpty ||
        meta.photoBase64.trim().isNotEmpty;
  }

  AppUserModel _chatPreviewUser({
    required ChatModel chat,
    required String receiverId,
  }) {
    final meta = chat.participantMetaFor(receiverId);
    if (_hasPreviewMeta(meta)) {
      return AppUserModel(
        uid: receiverId,
        name: meta!.name,
        email: meta.email,
        photoUrl: meta.photoUrl,
        photoBase64: meta.photoBase64,
      );
    }
    return _userPreviewCache[receiverId] ??
        AppUserModel(uid: receiverId, name: "", email: receiverId);
  }

  Future<void> _ensureUserPreviewsLoaded({
    required List<ChatModel> chats,
    required String currentUserId,
  }) async {
    final missingIds = <String>{};
    for (final chat in chats) {
      final receiverId = chat.receiverIdFor(currentUserId);
      if (receiverId.isEmpty) continue;
      if (_hasPreviewMeta(chat.participantMetaFor(receiverId))) continue;
      if (_userPreviewCache.containsKey(receiverId)) continue;
      if (_loadingUserPreviews.contains(receiverId)) continue;
      missingIds.add(receiverId);
    }
    if (missingIds.isEmpty) return;

    _loadingUserPreviews.addAll(missingIds);
    final loaded = <String, AppUserModel>{};
    try {
      final ids = missingIds.toList(growable: false);
      for (var i = 0; i < ids.length; i += 10) {
        var end = i + 10;
        if (end > ids.length) end = ids.length;
        final chunk = ids.sublist(i, end);
        final snap = await FirebaseFirestore.instance
            .collection("users")
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        for (final doc in snap.docs) {
          loaded[doc.id] = AppUserModel.fromFirestore(doc);
        }
      }
    } finally {
      _loadingUserPreviews.removeAll(missingIds);
    }

    if (!mounted || loaded.isEmpty) return;
    setState(() {
      _userPreviewCache.addAll(loaded);
    });
  }

  String _normalizeBase64(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return "";
    final commaIndex = trimmed.indexOf(',');
    final withoutPrefix =
        trimmed.startsWith("data:image") && commaIndex >= 0
            ? trimmed.substring(commaIndex + 1)
            : trimmed;
    return withoutPrefix.replaceAll(RegExp(r"\s+"), "");
  }

  ImageProvider<Object>? _avatarImageProvider(AppUserModel user) {
    final normalizedBase64 = _normalizeBase64(user.photoBase64);
    if (normalizedBase64.isNotEmpty) {
      try {
        final Uint8List bytes = base64Decode(normalizedBase64);
        return MemoryImage(bytes);
      } catch (_) {
        // Try photoUrl fallback below.
      }
    }
    if (user.photoUrl.isNotEmpty) {
      return NetworkImage(user.photoUrl);
    }
    return null;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openProfile(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
  }

  Future<void> _openChat({
    required BuildContext context,
    required String receiverId,
    required String receiverEmail,
    String? chatIdOverride,
  }) async {
    if (_isOpeningChat) return;
    setState(() => _isOpeningChat = true);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          receiverId: receiverId,
          receiverEmail: receiverEmail,
          chatIdOverride: chatIdOverride,
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _isOpeningChat = false);
  }

  Future<void> _openUnreadNotificationChat({
    required BuildContext context,
    required AuthUserModel currentUser,
  }) async {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(sheetContext).size.height * 0.72,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.mark_chat_unread_outlined,
                        color: AppColors.primaryDarkBlue,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Unread messages",
                        style: AppTextStyles.sectionTitle,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: StreamBuilder<List<ChatModel>>(
                    stream: _chatService.chatsForUserStream(currentUser.uid),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return const Center(
                          child: Text("Imeshindikana kupakia notifications."),
                        );
                      }

                      final unreadChats = (snapshot.data ?? const <ChatModel>[])
                          .where((chat) => chat.unreadCountFor(currentUser.uid) > 0)
                          .toList(growable: false)
                        ..sort((a, b) {
                          final unreadDiff = b
                              .unreadCountFor(currentUser.uid)
                              .compareTo(a.unreadCountFor(currentUser.uid));
                          if (unreadDiff != 0) return unreadDiff;
                          final aMs = a.lastMessageAt?.millisecondsSinceEpoch ?? 0;
                          final bMs = b.lastMessageAt?.millisecondsSinceEpoch ?? 0;
                          return bMs.compareTo(aMs);
                        });

                      if (unreadChats.isEmpty) {
                        return const Center(
                          child: Text("Hakuna notification mpya."),
                        );
                      }

                      unawaited(
                        _ensureUserPreviewsLoaded(
                          chats: unreadChats,
                          currentUserId: currentUser.uid,
                        ),
                      );

                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
                        itemCount: unreadChats.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final chat = unreadChats[index];
                          final receiverId = chat.receiverIdFor(currentUser.uid);
                          if (receiverId.isEmpty) {
                            return const SizedBox.shrink();
                          }

                          final appUser = _chatPreviewUser(
                            chat: chat,
                            receiverId: receiverId,
                          );
                          final avatarImage = _avatarImageProvider(appUser);
                          final unreadCount = chat.unreadCountFor(currentUser.uid);
                          final preview = chat.lastMessage.isEmpty
                              ? "Ujumbe mpya"
                              : chat.lastMessage;

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.card,
                              backgroundImage: avatarImage,
                              child: avatarImage == null
                                  ? const Icon(
                                      Icons.person,
                                      color: AppColors.primaryDarkBlue,
                                    )
                                  : null,
                            ),
                            title: Text(
                              appUser.displayName,
                              style: AppTextStyles.listTitle,
                            ),
                            subtitle: Text(
                              preview,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.listSubtitle,
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: Color(0xFFE53935),
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 24,
                                minHeight: 24,
                              ),
                              child: Text(
                                unreadCount > 99 ? "99+" : unreadCount.toString(),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            onTap: () async {
                              Navigator.of(sheetContext).pop();
                              await _openChat(
                                context: context,
                                receiverId: receiverId,
                                receiverEmail: appUser.email,
                                chatIdOverride: chat.id,
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDeleteChat({
    required BuildContext context,
    required String currentUserId,
    required String receiverId,
    required String receiverTitle,
    String? chatIdOverride,
  }) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Futa chat"),
          content: Text('Una uhakika unataka kufuta chat na "$receiverTitle"?'),
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

    try {
      await _chatService.deleteChat(
        currentUserId: currentUserId,
        otherUserId: receiverId,
        chatIdOverride: chatIdOverride,
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Imeshindikana kufuta chat. Jaribu tena.")),
      );
    }
  }

  bool _isRecentlyActive(Timestamp? timestamp) {
    if (timestamp == null) return false;
    final diff = DateTime.now().difference(timestamp.toDate()).inSeconds;
    return diff <= 70;
  }

  bool _isUserOnline(AppUserModel user) {
    return user.isOnline && _isRecentlyActive(user.lastSeen);
  }

  void _openStartChatSheet({
    required BuildContext context,
    required AuthUserModel currentUser,
    required bool onlineOnly,
    required String title,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(sheetContext).size.height * 0.7,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                  child: Text(title, style: AppTextStyles.sectionTitle),
                ),
                Expanded(
                  child: _PaginatedUsersList(
                    currentUserId: currentUser.uid,
                    onlineOnly: onlineOnly,
                    isUserOnline: _isUserOnline,
                    avatarImageProvider: _avatarImageProvider,
                    onUserTap: (user) async {
                      final receiverEmail = user.email;
                      Navigator.of(sheetContext).pop();
                      await _openChat(
                        context: context,
                        receiverId: user.uid,
                        receiverEmail: receiverEmail,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _navItem({
    required Widget icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(height: 3),
            Text(
              label,
              style: AppTextStyles.navLabel,
            ),
          ],
        ),
      ),
    );
  }

  Widget _notificationNavIcon() {
    return UnreadCountBuilder(
      builder: (context, unreadCount) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(
              Icons.chat_bubble_outline_rounded,
              color: AppColors.primaryDarkBlue,
              size: 29,
            ),
            if (unreadCount > 0)
              Positioned(
                right: -8,
                top: -6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE53935),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.card, width: 1),
                  ),
                  child: Text(
                    unreadCount > 99 ? "99+" : unreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
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

    final chatsStream = _chatService.chatsForUserStream(currentUser.uid);

    final width = MediaQuery.of(context).size.width;
    final frameRadius = width < 380 ? 34.0 : 42.0;
    const frameTop = Color(0xFF9ED2E0);
    const frameBottom = Color(0xFF78C2D8);

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
                  colors: [frameTop, frameBottom],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(frameRadius),
                border: Border.all(color: AppColors.borderBlue, width: 2),
              ),
              child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 14, 10),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          "chats list",
                          style: TextStyle(
                            color: AppColors.primaryDarkBlue,
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => _openProfile(context),
                        icon: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance
                              .collection("users")
                              .doc(currentUser.uid)
                              .snapshots(),
                          builder: (context, snapshot) {
                            final appUser = snapshot.hasData
                                ? AppUserModel.fromFirestore(snapshot.data!)
                                : AppUserModel(
                                    uid: currentUser.uid,
                                    name: currentUser.displayName ?? "",
                                    email: currentUser.email ?? "",
                                    photoUrl: currentUser.photoUrl ?? "",
                                  );
                            final avatarImage = _avatarImageProvider(appUser);
                            return Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.primaryDarkBlue,
                                  width: 2,
                                ),
                              ),
                              child: CircleAvatar(
                                backgroundColor: AppColors.card,
                                backgroundImage: avatarImage,
                                child: avatarImage == null
                                    ? const Icon(
                                        Icons.person_outline_rounded,
                                        color: AppColors.primaryDarkBlue,
                                        size: 30,
                                      )
                                    : null,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Container(
                    height: 56,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      color: AppColors.card.withValues(alpha: 0.35),
                      border: Border.all(color: AppColors.borderBlue, width: 2),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.search_rounded,
                          color: AppColors.primaryDarkBlue,
                          size: 30,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            onChanged: (value) => setState(
                              () => _query = value.trim().toLowerCase(),
                            ),
                            style: const TextStyle(
                              color: AppColors.primaryDarkBlue,
                              fontSize: 16,
                            ),
                            decoration: const InputDecoration(
                              hintText: "Search",
                              hintStyle: TextStyle(
                                color: AppColors.accentText,
                                fontSize: 16,
                              ),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: StreamBuilder<List<ChatModel>>(
                    stream: chatsStream,
                    builder: (context, snapshot) {
                      final liveChats = snapshot.data ?? const <ChatModel>[];
                      if (snapshot.hasData) {
                        _cachedChats = liveChats;
                        unawaited(
                          _ensureUserPreviewsLoaded(
                            chats: liveChats,
                            currentUserId: currentUser.uid,
                          ),
                        );
                      }
                      var chats = snapshot.hasData ? liveChats : _cachedChats;

                      // Panga chats: Zenye unread messages zikae juu, kisha muda.
                      if (chats.isNotEmpty) {
                        chats = List.from(chats); // Tengeneza copy inayoweza kubadilika
                        chats.sort((a, b) {
                          final unreadA = a.unreadCountByUser[currentUser.uid] ?? 0;
                          final unreadB = b.unreadCountByUser[currentUser.uid] ?? 0;
                          final hasUnreadA = unreadA > 0;
                          final hasUnreadB = unreadB > 0;

                          // 1. Prioritize Unread (Zenye unread zinakaa juu)
                          if (hasUnreadA && !hasUnreadB) return -1;
                          if (!hasUnreadA && hasUnreadB) return 1;

                          // 2. Kama zote ni sawa (zote unread au zote read), tumia muda (mpya juu)
                          // List asili kutoka Firestore tayari imepangwa kwa muda, lakini hii inahakikisha.
                          final tA = a.lastMessageAt?.toDate().millisecondsSinceEpoch ?? 0;
                          final tB = b.lastMessageAt?.toDate().millisecondsSinceEpoch ?? 0;
                          return tB.compareTo(tA);
                        });
                      }

                      if (snapshot.connectionState == ConnectionState.waiting &&
                          chats.isEmpty) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (chats.isEmpty) {
                        return const Center(
                          child: Text(
                            "Hakuna chats kwa sasa",
                            style: TextStyle(color: AppColors.accentText),
                          ),
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(10, 2, 10, 8),
                        itemCount: chats.length,
                        separatorBuilder: (_, _) => const Divider(
                          height: 1,
                          color: AppColors.borderBlue,
                        ),
                        itemBuilder: (context, index) {
                          final chat = chats[index];
                          final receiverId = chat.receiverIdFor(currentUser.uid);
                          if (receiverId.isEmpty) {
                            return const SizedBox.shrink();
                          }

                          final lastMessage = chat.lastMessage;

                          final appUser = _chatPreviewUser(
                            chat: chat,
                            receiverId: receiverId,
                          );
                          final receiverEmail = appUser.email;
                          final receiverTitle = appUser.displayName;
                          final avatarImage = _avatarImageProvider(appUser);

                          final matched = _query.isEmpty ||
                              receiverTitle.toLowerCase().contains(_query) ||
                              receiverEmail.toLowerCase().contains(_query) ||
                              lastMessage.toLowerCase().contains(_query);
                          if (!matched) {
                            return const SizedBox.shrink();
                          }

                          final int unreadCount =
                              chat.unreadCountByUser[currentUser.uid] ?? 0;

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            leading: CircleAvatar(
                              radius: 20,
                              backgroundColor: AppColors.card,
                              backgroundImage: avatarImage,
                              child: avatarImage == null
                                  ? const Icon(
                                      Icons.person,
                                      color: AppColors.primaryDarkBlue,
                                    )
                                  : null,
                            ),
                            title: Text(
                              receiverTitle,
                              style: const TextStyle(
                                color: AppColors.primaryDarkBlue,
                              ).merge(AppTextStyles.listTitle),
                            ),
                            subtitle: Text(
                              lastMessage.isEmpty ? "Anza mazungumzo" : lastMessage,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.listSubtitle,
                            ),
                            trailing: unreadCount > 0
                                ? Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFE53935),
                                      shape: BoxShape.circle,
                                    ),
                                    constraints: const BoxConstraints(
                                      minWidth: 24,
                                      minHeight: 24,
                                    ),
                                    child: Text(
                                      unreadCount > 99 ? "99+" : unreadCount.toString(),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  )
                                : const Icon(
                                    Icons.chevron_right_rounded,
                                    color: AppColors.primaryDarkBlue,
                                    size: 24,
                                  ),
                            onTap: () {
                              _openChat(
                                context: context,
                                receiverId: receiverId,
                                receiverEmail: receiverEmail,
                                chatIdOverride: chat.id,
                              );
                            },
                            onLongPress: () {
                              _confirmDeleteChat(
                                context: context,
                                currentUserId: currentUser.uid,
                                receiverId: receiverId,
                                receiverTitle: receiverTitle,
                                chatIdOverride: chat.id,
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
                Container(
                  height: 88,
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: AppColors.borderBlue, width: 1.2),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _navItem(
                        icon: _notificationNavIcon(),
                        label: "message",
                        onTap: () => _openUnreadNotificationChat(
                          context: context,
                          currentUser: currentUser,
                        ),
                      ),
                      _navItem(
                        icon: const Icon(
                          Icons.add,
                          color: AppColors.primaryDarkBlue,
                          size: 32,
                        ),
                        label: "add",
                        onTap: () => _openStartChatSheet(
                          context: context,
                          currentUser: currentUser,
                          onlineOnly: true,
                          title: "Online users",
                        ),
                      ),
                      _navItem(
                        icon: const Icon(
                          Icons.groups_2_outlined,
                          color: AppColors.primaryDarkBlue,
                          size: 29,
                        ),
                        label: "members",
                        onTap: () => _openStartChatSheet(
                          context: context,
                          currentUser: currentUser,
                          onlineOnly: false,
                          title: "Members wote",
                        ),
                      ),
                    ],
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

class _PaginatedUsersList extends StatefulWidget {
  const _PaginatedUsersList({
    required this.currentUserId,
    required this.onlineOnly,
    required this.isUserOnline,
    required this.avatarImageProvider,
    required this.onUserTap,
  });

  final String currentUserId;
  final bool onlineOnly;
  final bool Function(AppUserModel user) isUserOnline;
  final ImageProvider<Object>? Function(AppUserModel user) avatarImageProvider;
  final Future<void> Function(AppUserModel user) onUserTap;

  @override
  State<_PaginatedUsersList> createState() => _PaginatedUsersListState();
}

class _PaginatedUsersListState extends State<_PaginatedUsersList> {
  static const int _pageSize = 20;
  static const int _searchPageSize = 25;

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final List<AppUserModel> _users = [];
  final Set<String> _seenUserIds = <String>{};

  DocumentSnapshot<Map<String, dynamic>>? _lastDoc;
  bool _loading = false;
  bool _initialLoading = true;
  bool _hasMore = true;
  String _query = "";
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    unawaited(_loadNextPage());
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool _matchesUserFilters(AppUserModel user) {
    if (user.uid == widget.currentUserId) return false;
    if (widget.onlineOnly && !widget.isUserOnline(user)) return false;
    return true;
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final nextQuery = value.trim();
      if (nextQuery == _query) return;
      setState(() {
        _query = nextQuery;
        _users.clear();
        _seenUserIds.clear();
        _lastDoc = null;
        _hasMore = true;
        _initialLoading = true;
      });
      unawaited(_loadNextPage());
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (!_hasMore || _loading) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 160) {
      unawaited(_loadNextPage());
    }
  }

  Future<void> _loadNextPage() async {
    if (_loading || !_hasMore) return;
    setState(() => _loading = true);

    try {
      if (_query.isNotEmpty) {
        final queryPrefix = _query;
        final queryPrefixLower = queryPrefix.toLowerCase();
        final usersRef = FirebaseFirestore.instance.collection("users");
        final futures = <Future<QuerySnapshot<Map<String, dynamic>>>>[
          usersRef
              .orderBy("email")
              .startAt([queryPrefix])
              .endAt(["$queryPrefix\uf8ff"])
              .limit(_searchPageSize)
              .get(),
          usersRef
              .orderBy("name")
              .startAt([queryPrefix])
              .endAt(["$queryPrefix\uf8ff"])
              .limit(_searchPageSize)
              .get(),
        ];
        if (queryPrefixLower != queryPrefix) {
          futures.add(
            usersRef
                .orderBy("email")
                .startAt([queryPrefixLower])
                .endAt(["$queryPrefixLower\uf8ff"])
                .limit(_searchPageSize)
                .get(),
          );
          futures.add(
            usersRef
                .orderBy("name")
                .startAt([queryPrefixLower])
                .endAt(["$queryPrefixLower\uf8ff"])
                .limit(_searchPageSize)
                .get(),
          );
        }

        final results = await Future.wait(futures);
        if (!mounted) return;
        if (queryPrefix != _query) return;

        final merged = <String, AppUserModel>{};
        for (final snap in results) {
          for (final doc in snap.docs) {
            final user = AppUserModel.fromFirestore(doc);
            if (!_matchesUserFilters(user)) continue;
            merged[user.uid] = user;
          }
        }

        final loaded = merged.values.toList(growable: false)
          ..sort((a, b) => a.displayName.toLowerCase().compareTo(
                b.displayName.toLowerCase(),
              ));

        setState(() {
          _users
            ..clear()
            ..addAll(loaded);
          _seenUserIds
            ..clear()
            ..addAll(loaded.map((u) => u.uid));
          _lastDoc = null;
          _hasMore = false;
          _loading = false;
          _initialLoading = false;
        });
        return;
      }

      Query<Map<String, dynamic>> query = FirebaseFirestore.instance
          .collection("users")
          .orderBy("email")
          .limit(_pageSize);

      if (_lastDoc != null) {
        query = query.startAfterDocument(_lastDoc!);
      }

      final snap = await query.get();
      if (snap.docs.isNotEmpty) {
        _lastDoc = snap.docs.last;
      }

      final loaded = snap.docs
          .map(AppUserModel.fromFirestore)
          .where(_matchesUserFilters)
          .where((user) => !_seenUserIds.contains(user.uid))
          .toList(growable: false);

      if (mounted) {
        setState(() {
          for (final user in loaded) {
            _seenUserIds.add(user.uid);
            _users.add(user);
          }
          _hasMore = snap.docs.length == _pageSize;
          _loading = false;
          _initialLoading = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _initialLoading = false;
        _hasMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_initialLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: AppColors.card.withValues(alpha: 0.35),
              border: Border.all(color: AppColors.borderBlue, width: 1.6),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.search_rounded,
                  color: AppColors.primaryDarkBlue,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: const InputDecoration(
                      hintText: "Search member",
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: _users.isEmpty
              ? Center(
                  child: Text(
                    _query.isNotEmpty
                        ? "Hakuna member aliyepatikana."
                        : (widget.onlineOnly
                            ? "Hakuna users walio online kwa sasa."
                            : "Hakuna users kwa sasa."),
                  ),
                )
              : ListView.separated(
                  controller: _scrollController,
                  itemCount: _users.length + (_hasMore ? 1 : 0),
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    if (index >= _users.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    final user = _users[index];
                    final receiverEmail = user.email;
                    final receiverTitle = user.displayName;
                    final avatarImage = widget.avatarImageProvider(user);

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: avatarImage,
                        child: avatarImage == null
                            ? Icon(
                                Icons.person,
                                color: widget.isUserOnline(user)
                                    ? const Color(0xFF1B8F3F)
                                    : AppColors.primaryDarkBlue,
                              )
                            : null,
                      ),
                      title: Text(receiverTitle),
                      subtitle: Text(receiverEmail),
                      trailing: const Icon(Icons.chat_bubble_outline),
                      onTap: () => widget.onUserTap(user),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
