import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Manages secure storage and retrieval of the Gemini API key.
///
/// The key is stored under [_kKeyName] using flutter_secure_storage,
/// which on Android uses the Android Keystore / encrypted SharedPreferences
/// and on iOS uses the Keychain.
class ApiKeyService {
  ApiKeyService._();
  static final ApiKeyService instance = ApiKeyService._();

  static const _kKeyName = 'gemini_api_key';

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  /// Returns the stored API key, or null if none has been saved yet.
  Future<String?> getApiKey() async {
    final key = await _storage.read(key: _kKeyName);
    if (key == null || key.trim().isEmpty) return null;
    return key.trim();
  }

  /// Saves [key] to secure storage.
  Future<void> saveApiKey(String key) async {
    await _storage.write(key: _kKeyName, value: key.trim());
  }

  /// Removes the stored API key.
  Future<void> deleteApiKey() async {
    await _storage.delete(key: _kKeyName);
  }
}
