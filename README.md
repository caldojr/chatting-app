 # G11Chat App
-MUSA JOSEPHAT MALIFEDHA
NIT/BIT/2023/2288(Pesamussa1)
( He is not available because he is at his father's funeral)

-SAMWEL SIKUJUA SICHIMATA  NIT/BIT/2023/2378 (8sasisi)

-BARAKA WAMBURA MAGAIWA  NIT/BIT/2023/2348 (barakamatrix)

-JACKSON MAIKO MTEWELE-NIT/BIT/2023/2336-(jackson3646)

-ANGEL EMMANUEL MWATISI
NIT/BIT/2023/2165(Angel2004-ang)

-NIT/BIT/2023/2198
THOMAS CHARLES NGULUGULU 
(tcharlii25)

-ACKLINEJ.ZUMBA
NIT/BIT/2022/1899(acklinezumba1)
-MWAJABU IDDI MTAMBO
NIT/BIT/2023/2150(Mwajabu27
A modern, real-time messaging application built with Flutter and Firebase. G11Chat enables seamless peer-to-peer communication with rich features like typing indicators, message read receipts, media sharing, and presence tracking.

---

## 📋 Table of Contents

- [Features](#features)
- [Project Architecture](#project-architecture)
- [Technology Stack](#technology-stack)
- [Project Structure](#project-structure)
- [Installation & Setup](#installation--setup)
- [Development Phases](#development-phases)
- [Firebase Configuration](#firebase-configuration)
- [Contributing](#contributing)

---

## ✨ Features

- **User Authentication** - Secure email/password authentication with Firebase Auth
- **Real-time Messaging** - Instant message delivery with Firestore real-time synchronization
- **Message Status Tracking** - Sent, delivered, and read receipts
- **Text & Media Messages** - Support for text messages and image sharing (base64 encoded)
- **Typing Indicators** - Real-time typing status display
- **Unread Count Badges** - Real-time notification badges for unread messages
- **User Presence** - Online/offline status with last seen timestamps
- **User Profiles** - Edit profile information and upload profile pictures
- **Chat List** - Organized chat list ordered by last message time
- **Multi-platform Support** - Runs on Android, iOS, Web, Linux, macOS, and Windows

---

## 🏗️ Project Architecture

```
G11Chat App
├── Frontend Layer (Flutter UI)
│   ├── Screens (LoginScreen, ChatListScreen, ChatScreen, ProfileScreen)
│   ├── Theme Management (Colors, TextStyles)
│   └── Widget Components (MessageBubble, NotificationDot)
│
├── Business Logic Layer (Services)
│   ├── AuthService - Firebase authentication management
│   ├── ChatService - Chat and message operations
│   └── PresenceService - User online/offline tracking
│
├── Data Layer (Models)
│   ├── AuthUserModel - Authentication user data
│   ├── AppUserModel - Application user profile
│   ├── ChatModel - Chat conversation data
│   └── MessageModel - Individual message data
│
└── Backend Infrastructure (Firebase)
    ├── Authentication - Firebase Auth
    ├── Firestore Database - Real-time data synchronization
    └── Cloud Storage - User data persistence
```

---

## 🛠️ Technology Stack

### **Phase 1: Frontend Development**

| Technology | Purpose | Details |
|---|---|---|
| **Flutter** | Cross-platform UI framework | `^3.11.0` - Builds native apps for iOS, Android, Web, Linux, macOS, Windows |
| **Dart** | Programming language | Object-oriented, JIT/AOT compiled language |
| **Material Design** | UI Design system | Flutter's Material Design implementation for consistent UI |
| **CupertinoIcons** | Icon library | iOS-style icons for UI components |

### **Phase 2: Backend & Data Management**

| Technology | Purpose | Details |
|---|---|---|
| **Firebase Core** | Firebase initialization | `^4.4.0` - Initializes Firebase services |
| **Firebase Auth** | User authentication | `^6.1.4` - Email/password authentication, user session management |
| **Cloud Firestore** | NoSQL Database | `^6.1.2` - Real-time document database for chats, messages, user profiles |

### **Phase 3: Device Features & Media**

| Technology | Purpose | Details |
|---|---|---|
| **Image Picker** | Media selection | `^1.1.2` - Pick images from device camera or gallery |
| **Dart Convert** | Encoding/Decoding | Base64 encoding for image transmission |

### **Phase 4: Development Tools & Infrastructure**

| Technology | Purpose | Details |
|---|---|---|
| **Flutter Lints** | Code quality | `^6.0.0` - Dart linting rules for clean code |
| **Flutter Launcher Icons** | App branding | `^0.13.1` - Generate app icons for all platforms |
| **Gradle** | Build automation | Android app compilation and packaging |
| **Xcode** | iOS development | Apple platform compilation and debugging |
| **CMake** | Build system | Linux, macOS, and Windows app compilation |

### **Phase 5: Development Environment**

| Component | Purpose | Details |
|---|---|---|
| **Firebase Console** | Backend management | Configure authentication, Firestore rules, indexes |
| **Firestore Rules** | Security & access control | Define read/write permissions for database collections |
| **Firestore Indexes** | Query optimization | Speed up complex queries and filtering |
| **Firebase CLI** | Deployment tool | Deploy Firestore rules and manage Firebase resources |

---

## 📁 Project Structure

```
chatting-app/
├── lib/
│   ├── main.dart                 # App entry point and routing
│   ├── models/
│   │   ├── auth_user_model.dart     # Firebase auth user data model
│   │   ├── app_user_model.dart      # Application user profile model
│   │   ├── chat_model.dart          # Chat conversation model
│   │   └── message_model.dart       # Individual message model
│   ├── services/
│   │   ├── auth_service.dart        # Firebase authentication service
│   │   ├── chat_service.dart        # Chat operations & Firestore queries
│   │   └── presence_service.dart    # User online/offline tracking
│   ├── screens/
│   │   ├── login_screen.dart        # Login page
│   │   ├── register_screen.dart     # Registration page
│   │   ├── chatlist_screen.dart     # List of all chats
│   │   ├── chat_screen.dart         # Individual chat interface
│   │   ├── profile_screen.dart      # User profile management
│   │   ├── message_bubble.dart      # Message UI component
│   │   ├── users_screen.dart        # User discovery/selection
│   │   └── notific.dart             # Notification system
│   └── theme/
│       ├── app_colors.dart          # Color constants
│       └── app_text_styles.dart     # Typography styles
├── assets/                          # App images and resources
├── android/                         # Android-specific configuration
├── ios/                            # iOS-specific configuration
├── web/                            # Web-specific configuration
├── linux/                          # Linux-specific configuration
├── macos/                          # macOS-specific configuration
├── windows/                        # Windows-specific configuration
├── test/                           # Unit and widget tests
├── pubspec.yaml                    # Project dependencies and metadata
├── pubspec.lock                    # Locked dependency versions
├── analysis_options.yaml           # Dart analyzer configuration
├── firebase.json                   # Firebase configuration
├── firestore.rules                 # Firestore security rules
├── firestore.indexes.json          # Firestore index definitions
└── README.md                       # This file
```

---

## 🚀 Installation & Setup

### Prerequisites
- Flutter SDK (v3.11.0 or higher)
- Dart SDK (included with Flutter)
- Android Studio or Xcode (depending on target platform)
- Firebase account and project

### Steps

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd chatting-app
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Firebase**
   - Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
   - Download `google-services.json` (Android) and place in `android/app/`
   - Download `GoogleService-Info.plist` (iOS) and place in `ios/Runner/`
   - Enable Email/Password authentication in Firebase Console
   - Create Firestore database in production mode

4. **Set up Firestore collections**
   - Create collections: `users`, `chats`
   - Add Firestore security rules from `firestore.rules`

5. **Run the app**
   ```bash
   flutter run              # Default platform
   flutter run -d android   # Android
   flutter run -d ios       # iOS
   flutter run -d chrome    # Web
   ```

6. **Build for release**
   ```bash
   flutter build apk        # Android APK
   flutter build ios        # iOS app
   flutter build web        # Web version
   ```

---

## 📊 Development Phases

### **Phase 1: Frontend UI/UX Development**
- Design and implement user interface screens
- Create reusable widgets and components
- Implement theme and styling system
- **Technologies:** Flutter, Dart, Material Design

### **Phase 2: Backend Infrastructure**
- Set up Firebase project and configuration
- Configure authentication system
- Design and create Firestore data structure
- Set up security rules
- **Technologies:** Firebase Auth, Cloud Firestore

### **Phase 3: Core Features Implementation**
- Implement user authentication (login/register)
- Build real-time messaging system
- Add chat list and message history
- Implement typing indicators and status tracking
- **Technologies:** Firebase Auth, Firestore, Real-time Streams

### **Phase 4: Advanced Features**
- Media sharing (images with base64 encoding)
- User presence tracking (online/offline)
- Read receipts and delivery status
- Unread message notifications
- **Technologies:** Image Picker, Firestore batch operations

### **Phase 5: Polish & Optimization**
- Code refactoring and optimization
- Error handling and validation
- Performance optimization
- Testing and debugging
- **Technologies:** Flutter Lints, Dart analyzer

### **Phase 6: Deployment & Maintenance**
- Build and release for multiple platforms
- Firebase deployment and management
- App store submissions
- User feedback and updates
- **Technologies:** Gradle, Xcode, CMake, Firebase CLI

---

## 🔐 Firebase Configuration

### Firestore Database Structure

```
/users/{uid}
├─ name: string
├─ email: string
├─ photoUrl: string
├─ photoBase64: string
├─ createdAt: timestamp
├─ isOnline: boolean
└─ lastSeen: timestamp

/chats/{chatId}
├─ participants: array[uid]
├─ participantMetaByUser: map
├─ lastMessage: string
├─ lastMessageAt: timestamp
├─ unreadCountByUser: map{uid: count}
├─ typingByUser: map{uid: boolean}
└─ /messages/{messageId}
    ├─ text: string
    ├─ imageBase64: string
    ├─ senderId: string
    ├─ receiverId: string
    ├─ sentAt: timestamp
    ├─ deliveredAt: timestamp
    ├─ readAt: timestamp
    └─ deletedFor: array[uid]
```

### Security Rules
Security rules are defined in `firestore.rules` to ensure:
- Only authenticated users can read/write
- Users can only access their own chats
- Messages belong to specific chats
- User profile privacy protection

---

## 👥 Contributing

To contribute to this project:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

---

## 📞 Support

For issues, questions, or contributions, please reach out to the development team.

**Happy coding! 🚀**
