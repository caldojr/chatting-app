import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:g11chat_app/services/auth_service.dart';
import 'package:g11chat_app/theme/app_colors.dart';
import 'package:g11chat_app/theme/app_text_styles.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    final name = value?.trim() ?? "";
    if (name.isEmpty) return "Name inahitajika";
    if (name.length < 2) return "Name iwe na herufi angalau 2";
    return null;
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? "";
    if (email.isEmpty) return "Email inahitajika";
    final emailRegex = RegExp(r"^[^@\s]+@[^@\s]+\.[^@\s]+$");
    if (!emailRegex.hasMatch(email)) return "Weka email sahihi";
    return null;
  }

  String? _validatePassword(String? value) {
    final password = value ?? "";
    if (password.isEmpty) return "Password inahitajika";
    if (password.length < 8) return "Password iwe na angalau herufi 8";
    if (!RegExp(r"[A-Z]").hasMatch(password)) {
      return "Weka angalau herufi kubwa 1";
    }
    if (!RegExp(r"[a-z]").hasMatch(password)) {
      return "Weka angalau herufi ndogo 1";
    }
    if (!RegExp(r"\d").hasMatch(password)) return "Weka angalau namba 1";
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if ((value ?? "").isEmpty) return "Thibitisha password";
    if (value != _passwordController.text) return "Password hazifanani";
    return null;
  }

  Future<void> _register() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid || _isLoading) return;

    setState(() => _isLoading = true);

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    var createdUser = false;

    try {
      final authUser = await _authService.register(email: email, password: password);
      createdUser = true;
      await _authService.updateDisplayName(name);

      // --- ANZA: LOGIC YA KURUDISHA DATA ZA ZAMANI (AUTO-RESTORE) ---
      try {
        // 1. Angalia kama kuna user wa zamani mwenye email hii kwenye Firestore
        final oldUserSnapshot = await FirebaseFirestore.instance
            .collection("users")
            .where("email", isEqualTo: email)
            .get();

        for (final oldDoc in oldUserSnapshot.docs) {
          final oldUid = oldDoc.id;
          // Hakikisha hatugusi data ya user huyu mpya
          if (oldUid == authUser.uid) continue;

          // 2. Tafuta chats zote za UID ya zamani
          final oldChatsSnapshot = await FirebaseFirestore.instance
              .collection("chats")
              .where("participants", arrayContains: oldUid)
              .get();

          for (final chatDoc in oldChatsSnapshot.docs) {
            final data = chatDoc.data();
            final participants = List<dynamic>.from(data["participants"] ?? []);

            // Badilisha Old UID iwe New UID
            participants.remove(oldUid);
            if (!participants.contains(authUser.uid)) {
              participants.add(authUser.uid);
            }

            await chatDoc.reference.update({"participants": participants});
          }

          // 3. Futa document ya user wa zamani ili isilete mkanganyiko
          await oldDoc.reference.delete();
        }
      } catch (e) {
        debugPrint("Kosa wakati wa kurudisha data: $e");
      }
      // --- MWISHO: LOGIC YA KURUDISHA DATA ---

      await FirebaseFirestore.instance.collection("users").doc(authUser.uid).set(
        {
          "uid": authUser.uid,
          "name": name,
          "email": email,
          "isOnline": true,
          "lastSeen": FieldValue.serverTimestamp(),
          "createdAt": FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      _passwordController.clear();
      _confirmPasswordController.clear();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Usajili umefanikiwa.")),
      );
      // Return to previous screen; AuthGate handles redirect to chat list.
      Navigator.of(context).pop();
    } on AuthServiceException catch (e) {
      var message = "Imeshindikana ku-register. Jaribu tena.";
      if (e.code == "weak-password") {
        message = "Password ni dhaifu. Tumia password yenye nguvu.";
      } else if (e.code == "email-already-in-use") {
        message = "Email tayari imesajiliwa.";
      } else if (e.code == "invalid-email") {
        message = "Email si sahihi.";
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Kuna tatizo limetokea. Jaribu tena.")),
      );

      if (createdUser) {
        await _authService.deleteCurrentUser();
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _backToLogin() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.bgTop, AppColors.bgBottom],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Card(
                  color: AppColors.card,
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Icon(
                            Icons.person_add_alt_1_rounded,
                            size: 42,
                            color: AppColors.primaryDarkBlue,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            "Tengeneza Akaunti",
                            textAlign: TextAlign.center,
                            style: AppTextStyles.screenTitle,
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            "Jaza taarifa zako kuanza kutumia app",
                            textAlign: TextAlign.center,
                            style: AppTextStyles.screenSubtitle,
                          ),
                          const SizedBox(height: 24),
                          TextFormField(
                            controller: _nameController,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.name],
                            decoration: InputDecoration(
                              labelText: "Name",
                              labelStyle: AppTextStyles.fieldLabel,
                              prefixIcon: const Icon(Icons.person_outline),
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
                            validator: _validateName,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email],
                            decoration: InputDecoration(
                              labelText: "Email",
                              labelStyle: AppTextStyles.fieldLabel,
                              prefixIcon: const Icon(Icons.email_outlined),
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
                            validator: _validateEmail,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.newPassword],
                            decoration: InputDecoration(
                              labelText: "Password",
                              labelStyle: AppTextStyles.fieldLabel,
                              prefixIcon: const Icon(Icons.lock_outline),
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
                              suffixIcon: IconButton(
                                onPressed: () {
                                  setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  );
                                },
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                              ),
                            ),
                            validator: _validatePassword,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: _obscureConfirmPassword,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.newPassword],
                            onFieldSubmitted: (_) => _register(),
                            decoration: InputDecoration(
                              labelText: "Confirm Password",
                              labelStyle: AppTextStyles.fieldLabel,
                              prefixIcon: const Icon(Icons.lock_reset_outlined),
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
                              suffixIcon: IconButton(
                                onPressed: () {
                                  setState(
                                    () => _obscureConfirmPassword =
                                        !_obscureConfirmPassword,
                                  );
                                },
                                icon: Icon(
                                  _obscureConfirmPassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                              ),
                            ),
                            validator: _validateConfirmPassword,
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _register,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryDarkBlue,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      "Create Account",
                                      style: AppTextStyles.buttonLabel,
                                    ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text("Una akaunti tayari?"),
                              TextButton(
                                onPressed: _isLoading ? null : _backToLogin,
                                child: const Text(
                                  "Login",
                                  style: TextStyle(
                                    color: AppColors.primaryDarkBlue,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
