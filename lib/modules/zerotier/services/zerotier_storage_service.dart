import 'package:shared_preferences/shared_preferences.dart';

class ZeroTierStorageService {
  ZeroTierStorageService({
    Future<SharedPreferences> Function()? preferencesLoader,
  }) : _preferencesLoader = preferencesLoader ?? SharedPreferences.getInstance;

  static const String networkIdPreferenceKey = 'zerotier.network_id';

  final Future<SharedPreferences> Function() _preferencesLoader;
  SharedPreferences? _preferences;

  Future<SharedPreferences> get _prefs async {
    return _preferences ??= await _preferencesLoader();
  }

  Future<String?> loadNetworkId() async {
    final prefs = await _prefs;
    final value = prefs.getString(networkIdPreferenceKey)?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
  }

  Future<void> saveNetworkId(String networkId) async {
    final prefs = await _prefs;
    final normalized = networkId.trim().toLowerCase();
    if (normalized.isEmpty) {
      await prefs.remove(networkIdPreferenceKey);
      return;
    }
    await prefs.setString(networkIdPreferenceKey, normalized);
  }
}
