import 'package:cloud_firestore/cloud_firestore.dart';

class PresenceService {
  PresenceService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<void> setOnline(String userId) {
    return _firestore.collection("users").doc(userId).set({
      "isOnline": true,
      "lastSeen": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> setOffline(String userId) {
    return _firestore.collection("users").doc(userId).set({
      "isOnline": false,
      "lastSeen": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
