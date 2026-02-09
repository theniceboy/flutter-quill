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

  void loadAll() {
    for (final lang in supportedLanguages) {
      loadLanguage(lang);
    }
  }

  Future<void> loadLanguage(String language) async {
    if (_dictionaries.containsKey(language) || _loading.contains(language)) {
      return;
    }
    _loading.add(language);

    try {
      await Future.delayed(Duration.zero);
      final words = await rootBundle.loadString('$_assetPrefix/$language.dic');
      final dict = _parseDictionary(words);
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

  static final _removeDicCharacter = RegExp(r'/(\S+)?');

  static Map<String, int> _parseDictionary(String words) {
    final entries = const LineSplitter().convert(words);
    final dict = <String, int>{};
    for (final entry in entries) {
      final clean = entry
          .replaceAll(_removeDicCharacter, '')
          .trim()
          .toLowerCase();
      if (clean.isNotEmpty) {
        dict[clean] = 1;
      }
    }
    return dict;
  }
}
