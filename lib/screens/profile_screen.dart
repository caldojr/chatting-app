import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:g11chat_app/models/app_user_model.dart';
import 'package:g11chat_app/services/auth_service.dart';
import 'package:g11chat_app/services/presence_service.dart';
import 'package:g11chat_app/theme/app_colors.dart';
import 'package:g11chat_app/theme/app_text_styles.dart';
import 'package:image_picker/image_picker.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final PresenceService _presenceService = PresenceService();
  final ImagePicker _picker = ImagePicker();

  Future<void> _editName(String currentName) async {
    final controller = TextEditingController(text: currentName);
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Edit Full Name"),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: "Weka jina kamili"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Cancel"),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryDarkBlue,
              ),
              onPressed: () => Navigator.of(context).pop(controller.text.trim()),
              child: const Text("Save"),
            ),
          ],
        );
      },
    );

    if (result == null || result.isEmpty) return;
    final user = _authService.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance.collection("users").doc(user.uid).set({
      "name": result,
    }, SetOptions(merge: true));
    await _authService.updateDisplayName(result);
  }

  Future<void> _pickAndSavePhoto(ImageSource source) async {
    final file = await _picker.pickImage(
      source: source,
      imageQuality: 70,
      maxWidth: 720,
      maxHeight: 720,
    );
    if (file == null) return;

    final user = _authService.currentUser;
    if (user == null) return;

    final bytes = await file.readAsBytes();
    final base64Image = base64Encode(bytes);

    await FirebaseFirestore.instance.collection("users").doc(user.uid).set({
      "photoBase64": base64Image,
    }, SetOptions(merge: true));
  }

  Future<void> _openImageSourcePicker() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text("Chagua kutoka Gallery"),
                onTap: () => Navigator.of(context).pop(ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text("Piga picha kwa Camera"),
                onTap: () => Navigator.of(context).pop(ImageSource.camera),
              ),
            ],
          ),
        );
      },
    );

    if (source == null) return;

    try {
      await _pickAndSavePhoto(source);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Imeshindikana kusasisha picha.")),
      );
    }
  }

  ImageProvider<Object>? _avatarImageProvider({
    required String photoBase64,
    required String photoUrl,
  }) {
    if (photoBase64.isNotEmpty) {
      try {
        final Uint8List bytes = base64Decode(photoBase64);
        return MemoryImage(bytes);
      } catch (_) {
        return null;
      }
    }
    if (photoUrl.isNotEmpty) {
      return NetworkImage(photoUrl);
    }
    return null;
  }

  Future<void> _confirmLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Confirm Logout"),
          content: const Text("Una uhakika unataka kutoka kwenye akaunti?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text("Cancel"),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryDarkBlue,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text("Logout"),
            ),
          ],
        );
      },
    );

    if (shouldLogout != true) return;

    final userId = _authService.currentUser?.uid;
    if (userId != null) {
      try {
        await _presenceService.setOffline(userId);
      } catch (_) {}
    }

    await _authService.signOut();
    if (!mounted) return;
    // Keep AuthGate as source of truth for post-auth navigation.
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("No authenticated user")),
      );
    }

    final userDocStream = FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text("Profile"),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.bgTop, AppColors.bgBottom],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: userDocStream,
          builder: (context, snapshot) {
            final appUser = snapshot.hasData
                ? AppUserModel.fromFirestore(snapshot.data!)
                : AppUserModel(
                    uid: user.uid,
                    name: user.displayName ?? "",
                    email: user.email ?? "",
                    photoUrl: user.photoUrl ?? "",
                  );
            final fullName = appUser.name.isEmpty
                ? (user.displayName ?? "")
                : appUser.name;
            final email = appUser.email.isEmpty ? (user.email ?? "") : appUser.email;
            final photoUrl = appUser.photoUrl.isEmpty
                ? (user.photoUrl ?? "")
                : appUser.photoUrl;
            final photoBase64 = appUser.photoBase64;
            final avatarImage = _avatarImageProvider(
              photoBase64: photoBase64,
              photoUrl: photoUrl,
            );

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              children: [
                Center(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CircleAvatar(
                        radius: 56,
                        backgroundColor: AppColors.card,
                        backgroundImage: avatarImage,
                        child: avatarImage == null
                            ? const Icon(
                                Icons.person,
                                size: 54,
                                color: AppColors.primaryDarkBlue,
                              )
                            : null,
                      ),
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Material(
                          color: AppColors.primaryDarkBlue,
                          shape: const CircleBorder(),
                          child: IconButton(
                            icon: const Icon(
                              Icons.edit,
                              color: Colors.white,
                              size: 18,
                            ),
                            onPressed: _openImageSourcePicker,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Card(
                  color: AppColors.card.withValues(alpha: 0.92),
                  child: ListTile(
                    title: const Text(
                      "Full Name",
                      style: AppTextStyles.sectionTitle,
                    ),
                    subtitle: Text(
                      fullName.isEmpty ? "No name" : fullName,
                      style: AppTextStyles.listSubtitle,
                    ),
                    trailing: IconButton(
                      icon: const Icon(
                        Icons.edit_outlined,
                        color: AppColors.primaryDarkBlue,
                      ),
                      onPressed: () => _editName(fullName),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  color: AppColors.card.withValues(alpha: 0.92),
                  child: ListTile(
                    title: const Text(
                      "Email",
                      style: AppTextStyles.sectionTitle,
                    ),
                    subtitle: Text(
                      email.isEmpty ? "No email" : email,
                      style: AppTextStyles.listSubtitle,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _confirmLogout,
                    icon: const Icon(Icons.logout),
                    label: const Text("Logout"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFB3261E),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
