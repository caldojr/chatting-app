import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:g11chat_app/models/chat_model.dart';
import 'package:g11chat_app/models/message_model.dart';

class ChatService {
  ChatService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  String chatId(String uid1, String uid2) {
    final ids = [uid1, uid2]..sort();
    return ids.join('_');
  }

  Stream<List<MessageModel>> messagesStream(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('sentAt', descending: true)
        .limit(100)
        .snapshots(includeMetadataChanges: true)
        .map((snapshot) {
          final messages = snapshot.docs.map(MessageModel.fromFirestore).toList();
          messages.sort((a, b) {
            final aMs = a.sentAt?.millisecondsSinceEpoch ?? 0;
            final bMs = b.sentAt?.millisecondsSinceEpoch ?? 0;
            return aMs.compareTo(bMs);
          });
          return messages;
        });
  }

  Stream<ChatModel?> chatStream(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .snapshots(includeMetadataChanges: true)
        .map((doc) => doc.exists ? ChatModel.fromFirestore(doc) : null);
  }

  Stream<List<ChatModel>> chatsForUserStream(String userId, {int limit = 120}) {
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: userId)
        .orderBy('lastMessageAt', descending: true)
        .limit(limit)
        .snapshots(includeMetadataChanges: true)
        .map((snapshot) => snapshot.docs.map(ChatModel.fromFirestore).toList());
  }

  Future<Map<String, dynamic>> _participantMetaByUser({
    required String userA,
    required String userB,
  }) async {
    final usersSnapshot = await _firestore
        .collection('users')
        .where(FieldPath.documentId, whereIn: [userA, userB])
        .get();

    final meta = <String, dynamic>{};
    for (final doc in usersSnapshot.docs) {
      final data = doc.data();
      meta[doc.id] = {
        'name': (data['name'] ?? '').toString(),
        'email': (data['email'] ?? '').toString(),
        'photoUrl': (data['photoUrl'] ?? '').toString(),
        'photoBase64': (data['photoBase64'] ?? '').toString(),
      };
    }
    return meta;
  }

  Future<void> sendMessage({
    required String senderId,
    required String receiverId,
    required String text,
    String? chatIdOverride,
  }) async {
    final id = (chatIdOverride != null && chatIdOverride.trim().isNotEmpty)
        ? chatIdOverride.trim()
        : chatId(senderId, receiverId);
    final chatRef = _firestore.collection('chats').doc(id);
    final messagesRef = chatRef.collection('messages');
    final now = Timestamp.now();
    final participantMeta = await _participantMetaByUser(
      userA: senderId,
      userB: receiverId,
    );

    await chatRef.set({
      'participants': [senderId, receiverId],
      'participantMetaByUser': participantMeta,
      'lastMessage': text,
      // Client timestamp makes chat list update instantly after sending.
      'lastMessageAt': now,
      'lastMessageAtServer': FieldValue.serverTimestamp(),
      'unreadCountByUser.$senderId': 0,
      'unreadCountByUser.$receiverId': FieldValue.increment(1),
      'typingByUser.$senderId': false,
    }, SetOptions(merge: true));

    await messagesRef.add({
      'text': text,
      'senderId': senderId,
      'receiverId': receiverId,
      'sentAt': now,
      'sentAtServer': FieldValue.serverTimestamp(),
      'deliveredAt': FieldValue.serverTimestamp(),
      'readAt': null,
      'imageBase64': "",
    });
  }

  Future<void> sendImageMessage({
    required String senderId,
    required String receiverId,
    required String imageBase64,
    String? chatIdOverride,
  }) async {
    final id = (chatIdOverride != null && chatIdOverride.trim().isNotEmpty)
        ? chatIdOverride.trim()
        : chatId(senderId, receiverId);
    final chatRef = _firestore.collection('chats').doc(id);
    final messagesRef = chatRef.collection('messages');
    final now = Timestamp.now();
    final participantMeta = await _participantMetaByUser(
      userA: senderId,
      userB: receiverId,
    );

    await chatRef.set({
      'participants': [senderId, receiverId],
      'participantMetaByUser': participantMeta,
      'lastMessage': 'Picha',
      'lastMessageAt': now,
      'lastMessageAtServer': FieldValue.serverTimestamp(),
      'unreadCountByUser.$senderId': 0,
      'unreadCountByUser.$receiverId': FieldValue.increment(1),
      'typingByUser.$senderId': false,
    }, SetOptions(merge: true));

    await messagesRef.add({
      'text': '',
      'imageBase64': imageBase64,
      'senderId': senderId,
      'receiverId': receiverId,
      'sentAt': now,
      'sentAtServer': FieldValue.serverTimestamp(),
      'deliveredAt': FieldValue.serverTimestamp(),
      'readAt': null,
    });
  }

  Future<void> setTypingStatus({
    required String currentUserId,
    required String otherUserId,
    required bool isTyping,
    String? chatIdOverride,
  }) async {
    final id = (chatIdOverride != null && chatIdOverride.trim().isNotEmpty)
        ? chatIdOverride.trim()
        : chatId(currentUserId, otherUserId);
    final chatRef = _firestore.collection('chats').doc(id);
    await chatRef.set({
      'participants': [currentUserId, otherUserId],
      'typingByUser.$currentUserId': isTyping,
    }, SetOptions(merge: true));
  }

  Future<void> markChatAsRead({
    required String currentUserId,
    required String otherUserId,
    String? chatIdOverride,
  }) async {
    final id = (chatIdOverride != null && chatIdOverride.trim().isNotEmpty)
        ? chatIdOverride.trim()
        : chatId(currentUserId, otherUserId);
    final chatRef = _firestore.collection('chats').doc(id);

    await chatRef.set({
      'participants': [currentUserId, otherUserId],
      'unreadCountByUser.$currentUserId': 0,
    }, SetOptions(merge: true));

    final unreadForCurrentUser = await chatRef
        .collection('messages')
        .where('receiverId', isEqualTo: currentUserId)
        .where('readAt', isNull: true)
        .get();

    if (unreadForCurrentUser.docs.isEmpty) return;

    final batch = _firestore.batch();
    for (final msg in unreadForCurrentUser.docs) {
      batch.update(msg.reference, {'readAt': FieldValue.serverTimestamp()});
    }
    await batch.commit();
  }

  Future<void> deleteChat({
    required String currentUserId,
    required String otherUserId,
    String? chatIdOverride,
  }) async {
    final id = (chatIdOverride != null && chatIdOverride.trim().isNotEmpty)
        ? chatIdOverride.trim()
        : chatId(currentUserId, otherUserId);
    final chatRef = _firestore.collection('chats').doc(id);
    final messages = await chatRef.collection('messages').get();

    if (messages.docs.isNotEmpty) {
      final batch = _firestore.batch();
      for (final doc in messages.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }

    await chatRef.delete();
  }

  Future<void> deleteMessage({
    required String currentUserId,
    required String otherUserId,
    required String messageId,
    String? chatIdOverride,
  }) async {
    final id = (chatIdOverride != null && chatIdOverride.trim().isNotEmpty)
        ? chatIdOverride.trim()
        : chatId(currentUserId, otherUserId);
    final chatRef = _firestore.collection('chats').doc(id);
    final messageRef = chatRef.collection('messages').doc(messageId);
    await messageRef.delete();
    await _refreshChatSummary(chatRef);
  }

  Future<void> deleteMessageForMe({
    required String currentUserId,
    required String otherUserId,
    required String messageId,
    String? chatIdOverride,
  }) async {
    final id = (chatIdOverride != null && chatIdOverride.trim().isNotEmpty)
        ? chatIdOverride.trim()
        : chatId(currentUserId, otherUserId);
    final messageRef = _firestore
        .collection('chats')
        .doc(id)
        .collection('messages')
        .doc(messageId);

    await messageRef.set({
      'deletedFor': FieldValue.arrayUnion([currentUserId]),
    }, SetOptions(merge: true));
  }

  Future<void> _refreshChatSummary(DocumentReference<Map<String, dynamic>> chatRef) async {
    final latestMessageSnapshot = await chatRef
        .collection('messages')
        .orderBy('sentAt', descending: true)
        .limit(1)
        .get();

    if (latestMessageSnapshot.docs.isEmpty) {
      await chatRef.delete();
      return;
    }

    final latestData = latestMessageSnapshot.docs.first.data();
    final latestText = (latestData['text'] ?? '').toString();
    final latestImage = (latestData['imageBase64'] ?? '').toString();
    await chatRef.set({
      'lastMessage': latestText.isNotEmpty
          ? latestText
          : (latestImage.isNotEmpty ? "Picha" : ""),
      'lastMessageAt': latestData['sentAt'],
      'lastMessageAtServer': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

