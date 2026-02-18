import 'package:cloud_firestore/cloud_firestore.dart';

class ChatParticipantMeta {
  const ChatParticipantMeta({
    required this.uid,
    this.name = "",
    this.email = "",
    this.photoUrl = "",
    this.photoBase64 = "",
  });

  final String uid;
  final String name;
  final String email;
  final String photoUrl;
  final String photoBase64;

  String get displayName => name.trim().isEmpty ? email : name.trim();

  factory ChatParticipantMeta.fromMap(String uid, Map<String, dynamic> data) {
    return ChatParticipantMeta(
      uid: uid,
      name: (data["name"] ?? "").toString(),
      email: (data["email"] ?? "").toString(),
      photoUrl: (data["photoUrl"] ?? "").toString(),
      photoBase64: (data["photoBase64"] ?? "").toString(),
    );
  }
}

class ChatModel {
  const ChatModel({
    required this.id,
    required this.participants,
    required this.lastMessage,
    this.lastMessageAt,
    required this.unreadCountByUser,
    required this.typingByUser,
    required this.participantMetaByUser,
  });

  final String id;
  final List<String> participants;
  final String lastMessage;
  final Timestamp? lastMessageAt;
  final Map<String, int> unreadCountByUser;
  final Map<String, bool> typingByUser;
  final Map<String, ChatParticipantMeta> participantMetaByUser;

  String receiverIdFor(String currentUserId) {
    return participants.firstWhere((id) => id != currentUserId, orElse: () => "");
  }

  int unreadCountFor(String userId) => unreadCountByUser[userId] ?? 0;
  bool isTyping(String userId) => typingByUser[userId] == true;
  ChatParticipantMeta? participantMetaFor(String userId) =>
      participantMetaByUser[userId];

  factory ChatModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final rawUnread =
        data["unreadCountByUser"] as Map<String, dynamic>? ??
        const <String, dynamic>{};

    final unread = <String, int>{};
    rawUnread.forEach((key, value) {
      if (value is num) unread[key] = value.toInt();
    });
    final rawTyping =
        data["typingByUser"] as Map<String, dynamic>? ??
        const <String, dynamic>{};
    final typing = <String, bool>{};
    rawTyping.forEach((key, value) {
      if (value is bool) typing[key] = value;
    });
    final rawMeta =
        data["participantMetaByUser"] as Map<String, dynamic>? ??
        const <String, dynamic>{};
    final participantMeta = <String, ChatParticipantMeta>{};
    rawMeta.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        participantMeta[key] = ChatParticipantMeta.fromMap(key, value);
      } else if (value is Map) {
        participantMeta[key] = ChatParticipantMeta.fromMap(
          key,
          Map<String, dynamic>.from(value),
        );
      }
    });

    return ChatModel(
      id: doc.id,
      participants: List<String>.from(data["participants"] as List? ?? const []),
      lastMessage: (data["lastMessage"] ?? "").toString(),
      lastMessageAt:
          (data["lastMessageAt"] ?? data["lastMessageAtServer"]) as Timestamp?,
      unreadCountByUser: unread,
      typingByUser: typing,
      participantMetaByUser: participantMeta,
    );
  }
}
