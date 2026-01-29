import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:simple_spell_checker/simple_spell_checker.dart';

import '../../controller/quill_controller.dart';
import 'spell_check_dictionaries.dart';

class SpellError {
  final int offset;
  final int length;
  final String word;
  final List<String> suggestions;

  const SpellError(this.offset, this.length, this.word, this.suggestions);
}

class QuillSpellCheckController extends ChangeNotifier {
  QuillSpellCheckController({
    required QuillController controller,
    String defaultLanguage = 'en',
    List<String> supportedLanguages = const [
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
    ],
    Listenable? dictionariesLoaded,
  })  : _controller = controller,
        _defaultLanguage = defaultLanguage,
        _supportedLanguages = supportedLanguages,
        _spellChecker = SimpleSpellChecker(language: defaultLanguage) {
    _subscription = _controller.changes.listen((_) => _scheduleCheck());
    final listenable = dictionariesLoaded ?? spellCheckDictionaries.onLoaded;
    _dictionariesLoaded = listenable;
    listenable.addListener(_scheduleCheck);
    _scheduleCheck();
  }

  final QuillController _controller;
  final SimpleSpellChecker _spellChecker;
  final String _defaultLanguage;
  final List<String> _supportedLanguages;
  late final Listenable _dictionariesLoaded;
  StreamSubscription? _subscription;
  Timer? _debounce;

  QuillController get controller => _controller;

  List<SpellError> _errors = const [];
  List<SpellError> get errors => _errors;

  String? _detectedLanguage;
  String? get detectedLanguage => _detectedLanguage;

  static final _wordPattern = RegExp(
      r"[a-zA-Z\u00C0-\u024F\u0400-\u04FF\u0590-\u05FF\u0600-\u06FF\uAC00-\uD7AF']+");
  static const _alphabet = 'abcdefghijklmnopqrstuvwxyz';
  static const _sampleSize = 50;

  List<String> _getLoadedLanguages() {
    return _supportedLanguages
        .where((lang) => SimpleSpellChecker.containsLanguage(lang))
        .toList();
  }

  void _scheduleCheck() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _runCheck);
  }

  void _runCheck() {
    final loadedLanguages = _getLoadedLanguages();
    if (loadedLanguages.isEmpty) return;

    final text = _controller.document.toPlainText();
    final allWords = _wordPattern.allMatches(text).toList();

    final language = _detectLanguage(allWords, loadedLanguages);
    _detectedLanguage = language;

    _spellChecker.setNewLanguageToState(language);
    final dictionary = _spellChecker.getDictionary();
    if (dictionary == null) return;

    final newErrors = <SpellError>[];
    for (final match in allWords) {
      final word = match.group(0)!;
      if (word.length < 2) continue;
      if (dictionary.containsKey(word.toLowerCase())) continue;

      final suggestions = _generateSuggestions(word.toLowerCase(), dictionary);
      newErrors.add(SpellError(match.start, word.length, word, suggestions));
    }

    _errors = newErrors;
    notifyListeners();
  }

  String _detectLanguage(
      List<RegExpMatch> allWords, List<String> loadedLanguages) {
    if (loadedLanguages.length == 1) return loadedLanguages.first;

    final sampleWords = allWords
        .take(_sampleSize)
        .map((m) => m.group(0)!.toLowerCase())
        .where((w) => w.length >= 2)
        .toList();

    if (sampleWords.isEmpty) {
      return loadedLanguages.contains(_defaultLanguage)
          ? _defaultLanguage
          : loadedLanguages.first;
    }

    String bestLanguage = loadedLanguages.first;
    int bestScore = -1;

    for (final lang in loadedLanguages) {
      _spellChecker.setNewLanguageToState(lang);
      final dict = _spellChecker.getDictionary();
      if (dict == null) continue;

      int score = 0;
      for (final word in sampleWords) {
        if (dict.containsKey(word)) score++;
      }
      if (score > bestScore) {
        bestScore = score;
        bestLanguage = lang;
      }
    }

    return bestLanguage;
  }

  List<String> _generateSuggestions(
    String word,
    Map<String, int> dictionary,
  ) {
    final candidates = <String>{};

    for (var i = 0; i <= word.length; i++) {
      if (i < word.length) {
        candidates.add(word.substring(0, i) + word.substring(i + 1));
      }
      for (var c = 0; c < _alphabet.length; c++) {
        candidates.add(word.substring(0, i) + _alphabet[c] + word.substring(i));
        if (i < word.length) {
          candidates.add(
            word.substring(0, i) + _alphabet[c] + word.substring(i + 1),
          );
        }
      }
      if (i < word.length - 1) {
        candidates.add(
          word.substring(0, i) + word[i + 1] + word[i] + word.substring(i + 2),
        );
      }
    }

    final results = candidates.where((c) => dictionary.containsKey(c)).toList();

    if (results.length < 5) {
      final dist2 = <String>{};
      for (final c1 in results.take(10)) {
        for (var i = 0; i <= c1.length; i++) {
          if (i < c1.length) {
            dist2.add(c1.substring(0, i) + c1.substring(i + 1));
          }
          for (var c = 0; c < _alphabet.length; c++) {
            dist2.add(c1.substring(0, i) + _alphabet[c] + c1.substring(i));
            if (i < c1.length) {
              dist2.add(
                c1.substring(0, i) + _alphabet[c] + c1.substring(i + 1),
              );
            }
          }
          if (i < c1.length - 1) {
            dist2.add(
              c1.substring(0, i) + c1[i + 1] + c1[i] + c1.substring(i + 2),
            );
          }
        }
      }
      for (final c in dist2) {
        if (dictionary.containsKey(c) && !results.contains(c)) {
          results.add(c);
        }
      }
    }

    if (results.length > 5) results.length = 5;
    return results;
  }

  void replaceWord(SpellError error, String replacement) {
    final lengthDiff = replacement.length - error.length;
    _errors = _errors
        .where((e) => e != error)
        .map((e) => e.offset > error.offset
            ? SpellError(e.offset + lengthDiff, e.length, e.word, e.suggestions)
            : e)
        .toList();
    notifyListeners();

    _controller.replaceText(
      error.offset,
      error.length,
      replacement,
      TextSelection.collapsed(offset: error.offset + replacement.length),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _subscription?.cancel();
    _dictionariesLoaded.removeListener(_scheduleCheck);
    _spellChecker.dispose();
    super.dispose();
  }
}
