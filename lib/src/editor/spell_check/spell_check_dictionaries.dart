import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

final spellCheckDictionaries = SpellCheckDictionaries();

class SpellCheckDictionaries {
  final _dictionaries = <String, Map<String, int>>{};
  final _loadedLanguages = <String>{};
  final _loading = <String>{};
  final _onLoaded = ChangeNotifier();

  Set<String> get loadedLanguages => Set.unmodifiable(_loadedLanguages);
  Listenable get onLoaded => _onLoaded;
  bool get isReady => _loadedLanguages.isNotEmpty;
  bool get isLoading => _loading.isNotEmpty;

  Map<String, int>? getDictionary(String language) => _dictionaries[language];
  bool containsLanguage(String language) => _dictionaries.containsKey(language);

  static const supportedLanguages = [
    'en',
    'es',
    'fr',
    'de',
    'it',
    'pt',
    'nl',
    'ru',
    'ar',
    'da',
    'bg',
    'ca',
    'et',
    'he',
  ];

  String _assetPrefix = 'assets/dictionaries';

  void setAssetPrefix(String prefix) {
    _assetPrefix = prefix;
  }

  void learnWord(String language, String word) {
    final dict = _dictionaries[language];
    if (dict == null) return;
    dict[word.toLowerCase()] = 1;
  }

  void unlearnWordFromAll(String word) {
    final lower = word.toLowerCase();
    for (final dict in _dictionaries.values) {
      dict.remove(lower);
    }
  }

  void applyLearnedWords(List<String> words) {
    for (final dict in _dictionaries.values) {
      for (final word in words) {
        dict[word.toLowerCase()] = 1;
      }
    }
  }

  bool _loadAllStarted = false;

  /// Loads every supported language one after another, so at most one
  /// dictionary is being parsed at a time.
  Future<void> loadAll() async {
    if (_loadAllStarted) return;
    _loadAllStarted = true;
    for (final lang in supportedLanguages) {
      await loadLanguage(lang);
    }
  }

  Future<void> loadLanguage(String language) async {
    if (_dictionaries.containsKey(language) || _loading.contains(language)) {
      return;
    }
    _loading.add(language);

    try {
      await Future.delayed(Duration.zero);
      final data = await rootBundle.load('$_assetPrefix/$language.dic');
      final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      // Parsing millions of words runs off the UI isolate (same thread on web).
      final dict = await compute(_parseDictionaryBytes, bytes);
      _dictionaries[language] = dict;
      _loadedLanguages.add(language);
      // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
      _onLoaded.notifyListeners();
    } catch (e) {
      debugPrint('Failed to load dictionary for $language: $e');
    } finally {
      _loading.remove(language);
    }
  }

}

final _removeDicCharacter = RegExp(r'/(\S+)?');

Map<String, int> _parseDictionaryBytes(Uint8List data) {
  final words = utf8.decode(data);
  final entries = const LineSplitter().convert(words);
  final dict = <String, int>{};
  for (final entry in entries) {
    final clean = entry.replaceAll(_removeDicCharacter, '').trim().toLowerCase();
    if (clean.isNotEmpty) {
      dict[clean] = 1;
    }
  }
  return dict;
}
