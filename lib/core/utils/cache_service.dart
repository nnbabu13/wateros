import 'package:hive/hive.dart';
import '../constants/app_constants.dart';

class CacheService {
  static final CacheService _instance = CacheService._();
  factory CacheService() => _instance;
  CacheService._();

  Box get _cacheBox => Hive.box(AppConstants.cacheBox);
  Box get _settingsBox => Hive.box(AppConstants.settingsBox);

  // Cache operations
  Future<void> cacheData(String key, dynamic value) async {
    await _cacheBox.put(key, value);
  }

  dynamic getCachedData(String key) {
    return _cacheBox.get(key);
  }

  Future<void> removeCachedData(String key) async {
    await _cacheBox.delete(key);
  }

  Future<void> clearCache() async {
    await _cacheBox.clear();
  }

  // Settings operations
  Future<void> saveSetting(String key, dynamic value) async {
    await _settingsBox.put(key, value);
  }

  dynamic getSetting(String key, {dynamic defaultValue}) {
    return _settingsBox.get(key, defaultValue: defaultValue);
  }

  Future<void> removeSetting(String key) async {
    await _settingsBox.delete(key);
  }

  // Convenience methods
  String? getToken() => getCachedData(AppConstants.tokenKey);
  Future<void> saveToken(String token) => cacheData(AppConstants.tokenKey, token);
  Future<void> removeToken() => removeCachedData(AppConstants.tokenKey);

  String? getBusinessId() => getCachedData(AppConstants.businessKey);
  Future<void> saveBusinessId(String id) => cacheData(AppConstants.businessKey, id);

  bool getDarkMode() => getSetting('dark_mode', defaultValue: false);
  Future<void> saveDarkMode(bool value) => saveSetting('dark_mode', value);

  String getLanguage() => getSetting('language', defaultValue: 'en');
  Future<void> saveLanguage(String value) => saveSetting('language', value);
}
