import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where the chat secret key lives. Never the plain database, never a backup.
abstract class SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// For tests.
class MemorySecretStore implements SecretStore {
  final Map<String, String> _data = {};
  @override
  Future<String?> read(String key) async => _data[key];
  @override
  Future<void> write(String key, String value) async => _data[key] = value;
  @override
  Future<void> delete(String key) async => _data.remove(key);
}

/// The real phone: Android Keystore through flutter_secure_storage.
class SecureSecretStore implements SecretStore {
  SecureSecretStore() : _s = const FlutterSecureStorage();
  final FlutterSecureStorage _s;
  @override
  Future<String?> read(String key) => _s.read(key: key);
  @override
  Future<void> write(String key, String value) => _s.write(key: key, value: value);
  @override
  Future<void> delete(String key) => _s.delete(key: key);
}
