import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  const MessageModel({
    required this.id,
    required this.text,
    required this.senderId,
    required this.receiverId,
    this.sentAt,
    this.deliveredAt,
    this.readAt,
    this.hasPendingWrites = false,
    this.deletedFor = const [],
    this.imageBase64 = "",
  });

  final String id;
  final String text;
  final String senderId;
  final String receiverId;
  final Timestamp? sentAt;
  final Timestamp? deliveredAt;
  final Timestamp? readAt;
  final bool hasPendingWrites;
  final List<String> deletedFor;
  final String imageBase64;

  bool isDeletedFor(String userId) => deletedFor.contains(userId);

  factory MessageModel.fromFirestore(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return MessageModel(
      id: doc.id,
      text: (data["text"] ?? "").toString(),
      senderId: (data["senderId"] ?? "").toString(),
      receiverId: (data["receiverId"] ?? "").toString(),
      sentAt: (data["sentAt"] ?? data["sentAtServer"]) as Timestamp?,
      deliveredAt: data["deliveredAt"] as Timestamp?,
      readAt: data["readAt"] as Timestamp?,
      hasPendingWrites: doc.metadata.hasPendingWrites,
      deletedFor: List<String>.from(data["deletedFor"] as List? ?? const []),
      imageBase64: (data["imageBase64"] ?? "").toString(),
    );
  }
}
