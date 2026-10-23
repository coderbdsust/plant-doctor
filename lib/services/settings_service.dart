import 'package:shared_preferences/shared_preferences.dart';

/// Persisted user preferences (Gemini API key, model, theme, etc).
class SettingsService {
  SettingsService(this._prefs);

  final SharedPreferences _prefs;

  static const String _kApiKey = 'gemini_api_key';
  static const String _kModel = 'gemini_model';
  static const String _kThemeMode = 'theme_mode';
  static const String _kUseSearch = 'gemini_use_google_search';
  static const String _kFontScale = 'font_scale';
  static const String _kLastStep = 'last_step_index';

  static Future<SettingsService> load() async {
    final prefs = await SharedPreferences.getInstance();
    return SettingsService(prefs);
  }

  String get apiKey => _prefs.getString(_kApiKey) ?? '';

  Future<void> setApiKey(String value) async {
    await _prefs.setString(_kApiKey, value.trim());
  }

  String get model => _prefs.getString(_kModel) ?? 'gemini-3.8-flash';

  Future<void> setModel(String value) async {
    await _prefs.setString(_kModel, value);
  }

  /// 'system' | 'light' | 'dark'
  String get themeMode => _prefs.getString(_kThemeMode) ?? 'system';

  Future<void> setThemeMode(String value) async {
    await _prefs.setString(_kThemeMode, value);
  }

  bool get useGoogleSearch => _prefs.getBool(_kUseSearch) ?? true;

  Future<void> setUseGoogleSearch(bool value) async {
    await _prefs.setBool(_kUseSearch, value);
  }

  double get fontScale => _prefs.getDouble(_kFontScale) ?? 1.0;

  Future<void> setFontScale(double value) async {
    await _prefs.setDouble(_kFontScale, value);
  }

  int get lastStepIndex => _prefs.getInt(_kLastStep) ?? 0;

  Future<void> setLastStepIndex(int value) async {
    await _prefs.setInt(_kLastStep, value);
  }

  bool get hasApiKey => apiKey.isNotEmpty;
}
