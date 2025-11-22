import 'package:shared_preferences/shared_preferences.dart';

class AuthStorage {
  static const String _otpTokenKey = 'otp_token';
  static const String _authTokenKey = 'auth_token';

  static Future<void> saveOtpToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_otpTokenKey, token);
  }

  static Future<String?> getOtpToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_otpTokenKey);
  }

  static Future<void> saveAuthToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_authTokenKey, token);
  }

  static Future<String?> getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_authTokenKey);
  }

  static Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_otpTokenKey);
    await prefs.remove(_authTokenKey);
  }
}
