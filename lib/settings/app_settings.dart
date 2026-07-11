import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../i18n/strings.dart';

/// 앱 설정: 언어 + 초보자 모드(점수제 끔).
///
/// 최초 실행 시 기기 언어를 따르고(지원 안 하면 영어),
/// 사용자가 바꾸면 shared_preferences에 저장해 다음 실행에 유지한다.
/// 저장 실패(테스트 환경 등)는 무시한다 — 설정은 세션 안에서는 항상 동작.
class AppSettings extends ChangeNotifier {
  static const _langKey = 'lang';
  static const _simpleKey = 'simpleMode';
  static const _nameKey = 'playerName';

  AppLang _lang;
  bool _simpleMode;
  String _playerName;

  AppSettings(
      {AppLang? lang, this._simpleMode = false, this._playerName = ''})
      : _lang = lang ?? deviceLang();

  /// 기기 언어에서 초기 언어 결정 (ko/zh 외에는 영어).
  static AppLang deviceLang() =>
      langFromCode(ui.PlatformDispatcher.instance.locale.languageCode);

  AppLang get lang => _lang;

  bool get simpleMode => _simpleMode;

  /// LAN 대전에서 쓰는 표시 이름 (빈 문자열이면 미설정).
  String get playerName => _playerName;

  Strings get strings => stringsOf(_lang);

  void setLang(AppLang value) {
    if (value == _lang) return;
    _lang = value;
    notifyListeners();
    _save();
  }

  void setSimpleMode(bool value) {
    if (value == _simpleMode) return;
    _simpleMode = value;
    notifyListeners();
    _save();
  }

  void setPlayerName(String value) {
    final trimmed = value.trim();
    if (trimmed == _playerName) return;
    _playerName = trimmed;
    notifyListeners();
    _save();
  }

  static Future<AppSettings> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_langKey);
      return AppSettings(
        lang: code == null ? null : langFromCode(code),
        simpleMode: prefs.getBool(_simpleKey) ?? false,
        playerName: prefs.getString(_nameKey) ?? '',
      );
    } catch (_) {
      return AppSettings();
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_langKey, _lang.name);
      await prefs.setBool(_simpleKey, _simpleMode);
      await prefs.setString(_nameKey, _playerName);
    } catch (_) {
      // 저장 실패는 무시 (다음 실행에 기본값으로 복귀)
    }
  }
}
