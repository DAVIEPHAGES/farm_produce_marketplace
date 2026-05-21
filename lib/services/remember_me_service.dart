import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RememberMeService {
  static const String _rememberMeKey = 'remember_me';
  static const String _rememberedEmailKey = 'remembered_email';

  static bool _currentSessionAllowed = false;

  static Future<bool> isRememberMeEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_rememberMeKey) ?? false;
  }

  static Future<String> getRememberedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_rememberedEmailKey) ?? '';
  }

  static Future<void> prepareAuthPersistence(bool rememberMe) async {
    if (!kIsWeb) return;

    try {
      await FirebaseAuth.instance.setPersistence(
        rememberMe ? Persistence.LOCAL : Persistence.SESSION,
      );
    } catch (e) {
      debugPrint('Unable to set auth persistence: $e');
    }
  }

  static Future<void> saveSignInChoice({
    required bool rememberMe,
    required String email,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberMeKey, rememberMe);

    if (rememberMe) {
      await prefs.setString(_rememberedEmailKey, email);
    } else {
      await prefs.remove(_rememberedEmailKey);
    }

    _currentSessionAllowed = true;
  }

  static Future<void> signOutIfCurrentUserWasNotRemembered() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _currentSessionAllowed) return;

    final rememberMe = await isRememberMeEnabled();
    if (!rememberMe) {
      await FirebaseAuth.instance.signOut();
    }
  }

  static void markSignedOut() {
    _currentSessionAllowed = false;
  }
}
