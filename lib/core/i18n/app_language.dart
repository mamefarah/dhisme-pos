import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLanguage extends ChangeNotifier {
  AppLanguage._();
  static final AppLanguage instance = AppLanguage._();

  static const _key = 'app_language_code';
  String _code = 'so';
  bool _ready = false;

  String get code => _code;
  bool get isSomali => _code == 'so';
  bool get isEnglish => _code == 'en';
  bool get ready => _ready;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _code = prefs.getString(_key) ?? 'so';
    _ready = true;
    notifyListeners();
  }

  Future<void> setLanguage(String code) async {
    final next = code == 'en' ? 'en' : 'so';
    if (_code == next) return;
    _code = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, _code);
    notifyListeners();
  }

  Future<void> toggle() => setLanguage(isSomali ? 'en' : 'so');
}

extension AppLanguageX on BuildContext {
  bool get isSomali => AppLanguage.instance.isSomali;
  String tr(String so, String en) => AppLanguage.instance.isSomali ? so : en;
}
