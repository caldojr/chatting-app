# Firestore Schema Documentation

**Version:** 1.0 (Project-Aligned)  
**Last Updated:** February 19, 2026  
**Database:** Cloud Firestore (Production Mode)  
**schema Status:** ✅ Based on actual G11Chat project implementation

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Collections & Data Models](#collections--data-models)
3. [Data Types Reference](#data-types-reference)
4. [Indexing Strategy](#indexing-strategy)
5. [Security Rules](#security-rules)
6. [Best Practices](#best-practices)
7. [Common Queries](#common-queries)
8. [Migration Guide](#migration-guide)

---

## 🎯 Overview

This document defines the Cloud Firestore schema for the **G11Chat** application. This schema is **directly based** on your actual implementation with these features:

- ✅ **Real-time messaging** with text and image support
- ✅ **Message read receipts** (sentAt, deliveredAt, readAt)
- ✅ **Typing indicators** for live feedback
- ✅ **Unread counters** per user in each chat
- ✅ **User presence tracking** (isOnline, lastSeen)
- ✅ **Soft delete support** (messages marked but not removed)
- ✅ **Offline-first architecture** (client + server timestamps)
- ✅ **Base64 image support** for offline access to profile photos

### Database Structure

```
G11Chat Database
├── users/
│   └── {uid}
│       ├── Registration & Auth data
│       ├── Presence tracking
│       └── Profile information
│
└── chats/
    └── {chatId}
        ├── Chat metadata
        ├── Participant cache
        ├── Unread counters
        ├── Typing status
        └── messages/ (subcollection)
            └── {messageId}
                ├── Message content (text + image)
                ├── Sender/receiver info
                ├── Read receipts
                └── Soft-delete tracking
```

---

## 📦 Collections & Data Models

### 1️⃣ **`users` Collection**

**Purpose:** Store user account information, profiles, and presence data.

**Path:** `/users/{uid}`

**Document Structure:**

```javascript
{
  // Authentication & Identity
  "uid": "string (document ID, matches Firebase Auth UID)",
  "email": "string (Unique, synchronized from Firebase Auth)",
  
  // Profile Information
  "name": "string (Full name, required, user-editable)",
  "photoUrl": "string (URL to profile image, defaults to '')",
  "photoBase64": "string (Base64-encoded profile image for offline access, defaults to '')",
  
  // Account Metadata
  "createdAt": "timestamp (Account creation time, set at registration)",
  
  // Presence Tracking
  "isOnline": "boolean (Current online status, updated in real-time)",
  "lastSeen": "timestamp (Last user activity timestamp)"
}
```

**Indexes:**
- Single field: `email` (ascending) - for user lookup/login
- Single field: `isOnline` (descending) - for finding online users
- Single field: `lastSeen` (descending) - for sorting by activity
- Composite: `isOnline` + `lastSeen` - for online user discovery with sorting

**Dart Model Reference:**
```dart
class AppUserModel {
  final String uid;              // Document ID
  final String name;             // Required
  final String email;            // Required
  final String photoUrl;         // Optional, default ""
  final String photoBase64;      // Optional, default ""
  final Timestamp? createdAt;    // Optional
  final bool isOnline;           // Default false
  final Timestamp? lastSeen;     // Optional
}
```

**Notes:**
- Document ID = Firebase Auth UID (auto-generated)
- Email is unique, enforced by Firebase Auth
- `photoBase64` supports offline-first architecture
- `photoBase64` limited to ~900KB (Firestore doc size: 1MB max)
- `isOnline` updated via PresenceService
- `lastSeen` updated on every user activity

**Example Document:**
```json
{
  "uid": "user_abc123",
  "email": "john@example.com",
  "name": "John Doe",
  "photoUrl": "https://storage.googleapis.com/...",
  "photoBase64": "iVBORw0KGgoAAAANSUhEUgAAA...",
  "createdAt": "2026-02-10T08:30:00Z",
  "isOnline": true,
  "lastSeen": "2026-02-19T15:45:22Z"
}
```

---

### 2️⃣ **`chats` Collection**

**Purpose:** Store conversation metadata between two users.

**Path:** `/chats/{chatId}`

**Document Structure:**

```javascript
{
  // Chat Metadata
  "id": "string (Document ID, generated as sorted uid1_uid2)",
  "participants": "array[string] (Exactly 2 UIDs: [uid1, uid2])",
  
  // Participant Information (Denormalized Cache)
  "participantMetaByUser": {
    "{uid1}": {
      "uid": "string",
      "name": "string",
      "email": "string",
      "photoUrl": "string",
      "photoBase64": "string"
    },
    "{uid2}": {
      "uid": "string",
      "name": "string",
      "email": "string",
      "photoUrl": "string",
      "photoBase64": "string"
    }
  },
  
  // Last Message Information (for chat list preview)
  "lastMessage": "string (Text of last message, 'Picha' if image-only)",
  "lastMessageAt": "timestamp (Client timestamp for instant local updates)",
  "lastMessageAtServer": "timestamp (Server timestamp for reliable ordering)",
  
  // Unread Message Counter (per user)
  "unreadCountByUser": {
    "{uid1}": "integer (Unread count for user 1)",
    "{uid2}": "integer (Unread count for user 2)"
  },
  
  // Real-time Typing Indicator
  "typingByUser": {
    "{uid1}": "boolean (True if user 1 is typing)",
    "{uid2}": "boolean (True if user 2 is typing)"
  }
}
```

**Indexes:**
- Composite (PRIMARY): `participants` (CONTAINS) + `lastMessageAtServer` (DESCENDING)
- Single field: `participants` (array-contains)

**Dart Model Reference:**
```dart
class ChatModel {
  final String id;                                          // Document ID
  final List<String> participants;                          // Exactly [uid1, uid2]
  final String lastMessage;                                 // Preview text
  final Timestamp? lastMessageAt;                          // Client timestamp
  final Map<String, int> unreadCountByUser;               // {uid: count}
  final Map<String, bool> typingByUser;                   // {uid: isTyping}
  final Map<String, ChatParticipantMeta> participantMetaByUser;
}

class ChatParticipantMeta {
  final String uid;
  final String name;                                        // Default ""
  final String email;                                       // Default ""
  final String photoUrl;                                    // Default ""
  final String photoBase64;                                 // Default ""
}
```

**Notes:**
- Chat ID format: Sorted UIDs joined by `_` (e.g., "user_abc_user_xyz")
- Prevents duplicate chats between same users
- `participantMetaByUser` enables offline-first: load chat without fetching user docs
- `unreadCountByUser` incremented on message creation, reset on read
- `typingByUser` managed in real-time, auto-clears on app lifecycle changes
- `lastMessageAt` used for instant UI updates
- `lastMessageAtServer` used for reliable ordering in queries

**Example Document:**
```json
{
  "id": "user_abc123_user_xyz789",
  "participants": ["user_abc123", "user_xyz789"],
  "participantMetaByUser": {
    "user_abc123": {
      "uid": "user_abc123",
      "name": "John Doe",
      "email": "john@example.com",
      "photoUrl": "https://...",
      "photoBase64": "iVBORw0KGgo..."
    },
    "user_xyz789": {
      "uid": "user_xyz789",
      "name": "Jane Smith",
      "email": "jane@example.com",
      "photoUrl": "https://...",
      "photoBase64": "iVBORw0KGgo..."
    }
  },
  "lastMessage": "See you tomorrow!",
  "lastMessageAt": "2026-02-19T15:30:00Z",
  "lastMessageAtServer": "2026-02-19T15:30:05Z",
  "unreadCountByUser": {
    "user_abc123": 0,
    "user_xyz789": 3
  },
  "typingByUser": {
    "user_abc123": false,
    "user_xyz789": false
  }
}
```

---

### 3️⃣ **`chats/{chatId}/messages` Subcollection**

**Purpose:** Store individual messages within a conversation.

**Path:** `/chats/{chatId}/messages/{messageId}`

**Document Structure:**

```javascript
{
  // Message Content
  "id": "string (Document ID, auto-generated by Firestore)",
  "text": "string (Message text, can be empty if image-only)",
  "imageBase64": "string (Base64-encoded image, defaults to '')",
  
  // Sender/Receiver Information
  "senderId": "string (UID of message sender, required)",
  "receiverId": "string (UID of message recipient, required)",
  
  // Message Timestamps (Dual-timestamp for offline support)
  "sentAt": "timestamp (Client timestamp when message created)",
  "sentAtServer": "timestamp (Server timestamp, used if sentAt missing)",
  "deliveredAt": "timestamp (Delivery receipt from server)",
  "readAt": "timestamp (When message was read, null if unread)",
  
  // Message State
  "deletedFor": "array[string] (UIDs that deleted this message)",
  
  // Firestore Metadata (SDK-managed, not user data)
  "hasPendingWrites": "boolean (True while offline, false once synced)"
}
```

**Indexes:**
- Single field: `sentAtServer` (descending) - for message history ordering
- Single field: `senderId` (ascending) - for filtering by sender
- Composite: `receiverId` + `readAt` - for unread message queries

**Dart Model Reference:**
```dart
class MessageModel {
  final String id;                              // Document ID
  final String text;                            // Required
  final String senderId;                        // Required, UID
  final String receiverId;                      // Required, UID
  final Timestamp? sentAt;                      // Client timestamp
  final Timestamp? deliveredAt;                 // Optional
  final Timestamp? readAt;                      // Optional (null = unread)
  final bool hasPendingWrites;                  // Default false
  final List<String> deletedFor;                // Default []
  final String imageBase64;                     // Default ""
}
```

**Notes:**
- Message ID auto-generated by Firestore
- **Dual timestamps**: `sentAt` (client) + `sentAtServer` (server) for offline-first
  - If `sentAt` missing, falls back to `sentAtServer` in queries
  - Ensures accurate message order even with client clock drift
- **Text XOR Image**: Either `text` (required for all) or `imageBase64` populated
- **Read receipts**: `readAt` null = unread, populated = read
- **Soft delete**: Message kept in DB but marked in `deletedFor` array
  - Prevents display for specific users while preserving data
- **hasPendingWrites**: Firestore SDK metadata (not set by app)
  - Indicates message still syncing to server (offline)

**Example Document (Text Message):**
```json
{
  "id": "msg_doc123",
  "text": "Hey, how are you?",
  "imageBase64": "",
  "senderId": "user_abc123",
  "receiverId": "user_xyz789",
  "sentAt": "2026-02-19T15:28:30Z",
  "sentAtServer": "2026-02-19T15:28:35Z",
  "deliveredAt": "2026-02-19T15:28:36Z",
  "readAt": "2026-02-19T15:29:00Z",
  "deletedFor": [],
  "hasPendingWrites": false
}
```

**Example Document (Image Message):**
```json
{
  "id": "msg_doc456",
  "text": "",
  "imageBase64": "iVBORw0KGgoAAAANSUhEUgAAA...",
  "senderId": "user_xyz789",
  "receiverId": "user_abc123",
  "sentAt": "2026-02-19T15:29:15Z",
  "sentAtServer": "2026-02-19T15:29:18Z",
  "deliveredAt": "2026-02-19T15:29:19Z",
  "readAt": null,
  "deletedFor": [],
  "hasPendingWrites": false
}
```

---

## 📊 Data Types Reference

| Type | Description | Example | Limits |
|------|-------------|---------|--------|
| `string` | UTF-8 text | "Hello World" | 1MB per field |
| `integer` | 64-bit number | 42 | -2^63 to 2^63-1 |
| `boolean` | True/False | true | N/A |
| `timestamp` | RFC 3339 date-time | "2026-02-19T15:30:00Z" | Precision: microseconds |
| `array` | Ordered list | ["uid1", "uid2"] | 20,000 elements max |
| `map` | Key-value pairs | {uid: "abc", name: "John"} | 20,000 keys max |

---

## 🔍 Indexing Strategy

### Composite Indexes (Required)

These indexes are **required** and will prevent "index required" Firestore errors:

```json
{
  "indexes": [
    {
      "name": "chats-participants-lastMessageServer",
      "fields": [
        { "fieldPath": "participants", "arrayConfig": "CONTAINS" },
        { "fieldPath": "lastMessageAtServer", "order": "DESCENDING" }
      ]
    },
    {
      "name": "messages-receiverId-readAt",
      "fields": [
        { "fieldPath": "receiverId", "order": "ASCENDING" },
        { "fieldPath": "readAt", "order": "ASCENDING" }
      ]
    },
    {
      "name": "users-isOnline-lastSeen",
      "fields": [
        { "fieldPath": "isOnline", "order": "DESCENDING" },
        { "fieldPath": "lastSeen", "order": "DESCENDING" }
      ]
    }
  ]
}
```

**Deploy using Firebase CLI:**
```bash
firebase deploy --only firestore:indexes
```

### Single Field Indexes (Auto-created)

Firestore automatically creates these:
- `email` in users
- `createdAt` in users
- `participants` in chats
- `sentAtServer` in messages
- `senderId` in messages

---

## 🔐 Security Rules

Located in `firestore.rules` - enforce:

```
LEVEL 1: Unauthenticated Users
  ❌ No access

LEVEL 2: Authenticated Users
  ✅ Can read all user profiles (discovery)
  ✅ Can only create/update own profile

LEVEL 3: Own Data
  ✅ Full control of user profile
  ❌ Cannot delete account (security)

LEVEL 4: Chat Participant
  ✅ Read chat & messages (if 2-way participant)
  ✅ Create/update messages
  ✅ Mark messages as read
  ❌ Send messages as another user
```

---

## ✅ Best Practices

### 1. Data Organization
- ✅ Use subcollections for 1-to-many (messages in chats)
- ✅ Denormalize `participantMetaByUser` in chats for offline-first
- ✅ Keep documents under 1MB
- ✅ Use arrays only for CONTAINS queries (participants, deletedFor)

### 2. Naming Conventions
- ✅ Collections: lowercase plural (`users`, `chats`)
- ✅ Fields: camelCase (`lastMessageAt`, `photoBase64`)
- ✅ Document IDs: meaningful or UUID
- ✅ Map keys: lowercase with underscores

### 3. Performance Optimization
- ✅ Create composite indexes before querying
- ✅ Limit results: `.limit(50)` for chat lists
- ✅ Use pagination with cursor-based navigation
- ✅ Batch writes for multi-document updates
- ✅ Use `lastMessageAtServer` for ordering (not client `lastMessageAt`)

### 4. Data Consistency
- ✅ Use server timestamps for ordering
- ✅ Validate in security rules
- ✅ Use transactions for atomic operations
- ✅ Implement optimistic updates (update UI, then sync)

### 5. Privacy & Security
- ✅ Never store passwords in Firestore
- ✅ Document IDs = UIDs for user collection
- ✅ Security rules prevent data leaks
- ✅ Encode images as base64 (not external URLs for offline)

### 6. Cost Optimization
- ✅ Batch reads/writes (reduce operation count)
- ✅ Avoid reading entire collections
- ✅ Monitor patterns in Firebase Console
- ✅ Archive old chats after 1 year

---

## 🔎 Common Queries

### User Queries

**Get user by UID (read profile):**
```dart
final docSnapshot = await FirebaseFirestore.instance
    .collection('users')
    .doc(userId)
    .get();
final user = AppUserModel.fromFirestore(docSnapshot);
```

**Get all chats for current user (ordered by last message):**
```dart
final query = FirebaseFirestore.instance
    .collection('chats')
    .where('participants', arrayContains: currentUserId)
    .orderBy('lastMessageAtServer', descending: true)
    .limit(50)
    .snapshots();
```

**Get unread chats for user:**
```dart
final query = FirebaseFirestore.instance
    .collection('chats')
    .where('participants', arrayContains: userId)
    .snapshots()
    .map((snapshot) {
      return snapshot.docs
          .map(ChatModel.fromFirestore)
          .where((chat) => chat.unreadCountFor(userId) > 0);
    });
```

### Message Queries

**Get last 50 messages in a chat:**
```dart
final query = FirebaseFirestore.instance
    .collection('chats')
    .doc(chatId)
    .collection('messages')
    .orderBy('sentAtServer', descending: true)
    .limit(50)
    .snapshots();
```

**Get unread messages for user in a chat:**
```dart
final query = FirebaseFirestore.instance
    .collection('chats')
    .doc(chatId)
    .collection('messages')
    .where('receiverId', isEqualTo: userId)
    .where('readAt', isNull: true)
    .get();
```

**Mark all messages as read in chat:**
```dart
final batch = FirebaseFirestore.instance.batch();
final unreadMessages = await FirebaseFirestore.instance
    .collection('chats')
    .doc(chatId)
    .collection('messages')
    .where('receiverId', isEqualTo: userId)
    .where('readAt', isNull: true)
    .get();

for (final msg in unreadMessages.docs) {
  batch.update(msg.reference, {'readAt': FieldValue.serverTimestamp()});
}
await batch.commit();
```

---

## 🔄 Migration Guide

### Phase 1: Create Collections
```bash
firebase firestore:delete collections users --recursive
firebase firestore:delete collections chats --recursive
```
Then manually create through Firebase Console or app on first user signup.

### Phase 2: Deploy Indexes
```bash
firebase deploy --only firestore:indexes
```

### Phase 3: Deploy Security Rules
```bash
firebase deploy --only firestore:rules
```

### Phase 4: Test Data
Create test users and chats in Firebase Console for testing.

### Phase 5: Enable Backups
Configure in Firebase Console → Firestore → Backups.

---

## 📈 Scalability Roadmap

| Users | Actions | Costs |
|-------|---------|-------|
| **1K** | Monitor read/write patterns | ~$1-5/month |
| **10K** | Index optimization, archive old chats | ~$10-30/month |
| **100K** | Consider real-time database for presence, archive monthly | ~$50-200/month |
| **1M+** | Evaluate hybrid approach (Firestore + Realtime DB) | $500+/month |

---

## 📞 Support & References

- 📖 [Cloud Firestore Documentation](https://firebase.google.com/docs/firestore)
- 🛡️ [Firestore Security Rules](https://firebase.google.com/docs/firestore/security/start)
- ⚡ [Firestore Best Practices](https://firebase.google.com/docs/firestore/best-practices)
- 🔍 [Firestore Pricing](https://firebase.google.com/pricing)

**Last Reviewed:** February 19, 2026  
**Next Review:** August 19, 2026  
**Schema Version:** 1.0 (Project-Aligned)
