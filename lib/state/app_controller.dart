import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../data/guide_parser.dart';
import '../models/guide.dart';
import '../services/local_search_service.dart';
import '../services/settings_service.dart';

/// Central app state: loads the guide, tracks the reading position and
/// exposes search helpers.
class AppController extends ChangeNotifier {
  AppController(this._settings);

  final SettingsService _settings;
  final LocalSearchService _search = const LocalSearchService();

  GuideDocument? _document;
  bool _loading = true;
  String? _error;

  GuideDocument? get document => _document;
  bool get loading => _loading;
  String? get error => _error;
  SettingsService get settings => _settings;

  List<GuideChapter> get chapters => _document?.chapters ?? const <GuideChapter>[];

  List<SearchHit> search(String query) {
    final doc = _document;
    if (doc == null) return const <SearchHit>[];
    return _search.search(doc, query);
  }

  List<String> relatedTerms(String query) {
    final doc = _document;
    if (doc == null) return const <String>[];
    return _search.relatedTerms(doc, query);
  }

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final String raw =
          await rootBundle.loadString('assets/guideline.md');
      _document = GuideParser().parse(raw);
    } catch (e) {
      _error = 'গাইডলাইন লোড করা যায়নি: $e';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> setThemeMode(String mode) async {
    await _settings.setThemeMode(mode);
    notifyListeners();
  }

  Future<void> setFontScale(double value) async {
    await _settings.setFontScale(value);
    notifyListeners();
  }

  Future<void> setApiKey(String value) async {
    await _settings.setApiKey(value);
    notifyListeners();
  }

  Future<void> setModel(String value) async {
    await _settings.setModel(value);
    notifyListeners();
  }

  Future<void> setUseGoogleSearch(bool value) async {
    await _settings.setUseGoogleSearch(value);
    notifyListeners();
  }

  Future<void> saveReadingPosition(int globalStepIndex) async {
    await _settings.setLastStepIndex(globalStepIndex);
  }
}
