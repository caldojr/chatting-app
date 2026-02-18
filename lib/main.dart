import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:g11chat_app/models/auth_user_model.dart';
import 'package:g11chat_app/screens/chatlist_screen.dart';
import 'package:g11chat_app/screens/login_screen.dart';
import 'package:g11chat_app/services/auth_service.dart';
import 'package:g11chat_app/services/presence_service.dart';
import 'package:g11chat_app/theme/app_colors.dart';
import 'package:g11chat_app/theme/app_text_styles.dart';

import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'G11 Chat App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primaryDarkBlue,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: AppColors.bgTop,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.primaryDarkBlue,
          foregroundColor: Colors.white,
          centerTitle: false,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.inputFill,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: AppColors.primaryDarkBlue,
              width: 1.3,
            ),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryDarkBlue,
            foregroundColor: Colors.white,
          ),
        ),
        textTheme: ThemeData.light().textTheme.copyWith(
              titleLarge: AppTextStyles.screenTitle,
              titleMedium: AppTextStyles.sectionTitle,
              bodyLarge: AppTextStyles.body,
              bodyMedium: AppTextStyles.listSubtitle,
              labelLarge: AppTextStyles.buttonLabel,
            ),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> with WidgetsBindingObserver {
  static final AuthService _authService = AuthService();
  static final PresenceService _presenceService = PresenceService();
  StreamSubscription<AuthUserModel?>? _authSub;
  Timer? _presenceTimer;
  String? _lastUserId;

  Future<void> _setOnlineSafe(String userId) async {
    try {
      await _presenceService.setOnline(userId);
    } catch (_) {}
  }

  Future<void> _setOfflineSafe(String userId) async {
    try {
      await _presenceService.setOffline(userId);
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _authSub = _authService.authStateChanges().listen((user) {
      final nextUserId = user?.uid;
      if (_lastUserId != null && _lastUserId != nextUserId) {
        unawaited(_setOfflineSafe(_lastUserId!));
      }
      if (nextUserId != null) {
        unawaited(_setOnlineSafe(nextUserId));
        _startPresenceHeartbeat(nextUserId);
      } else {
        _stopPresenceHeartbeat();
      }
      _lastUserId = nextUserId;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final userId = _authService.currentUser?.uid;
    if (userId == null) return;
    if (state == AppLifecycleState.resumed) {
      unawaited(_setOnlineSafe(userId));
      _startPresenceHeartbeat(userId);
      return;
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_setOfflineSafe(userId));
      _stopPresenceHeartbeat();
    }
  }

  void _startPresenceHeartbeat(String userId) {
    _presenceTimer?.cancel();
    _presenceTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(_setOnlineSafe(userId));
    });
  }

  void _stopPresenceHeartbeat() {
    _presenceTimer?.cancel();
    _presenceTimer = null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSub?.cancel();
    _stopPresenceHeartbeat();
    if (_lastUserId != null) {
      unawaited(_setOfflineSafe(_lastUserId!));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthUserModel?>(
      stream: _authService.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          return const ChatListScreen();
        }

        return const LoginScreen();
      },
    );
  }
}
