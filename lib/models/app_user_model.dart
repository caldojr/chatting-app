import 'package:cloud_firestore/cloud_firestore.dart';

class AppUserModel {
  const AppUserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.photoUrl = "",
    this.photoBase64 = "",
    this.createdAt,
    this.isOnline = false,
    this.lastSeen,
  });

  final String uid;
  final String name;
  final String email;
  final String photoUrl;
  final String photoBase64;
  final Timestamp? createdAt;
  final bool isOnline;
  final Timestamp? lastSeen;

  String get displayName => name.trim().isEmpty ? email : name.trim();

  factory AppUserModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return AppUserModel(
      uid: doc.id,
      name: (data["name"] ?? "").toString(),
      email: (data["email"] ?? "").toString(),
      photoUrl: (data["photoUrl"] ?? "").toString(),
      photoBase64: (data["photoBase64"] ?? "").toString(),
      createdAt: data["createdAt"] as Timestamp?,
      isOnline: data["isOnline"] == true,
      lastSeen: data["lastSeen"] as Timestamp?,
    );
  }
}
