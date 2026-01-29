import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:simple_spell_checker_ar_lan/simple_spell_checker_ar_lan.dart';
import 'package:simple_spell_checker_bg_lan/simple_spell_checker_bg_lan.dart';
import 'package:simple_spell_checker_ca_lan/simple_spell_checker_ca_lan.dart';
import 'package:simple_spell_checker_da_lan/simple_spell_checker_da_lan.dart';
import 'package:simple_spell_checker_de_lan/simple_spell_checker_de_lan.dart';
import 'package:simple_spell_checker_en_lan/simple_spell_checker_en_lan.dart';
import 'package:simple_spell_checker_es_lan/simple_spell_checker_es_lan.dart';
import 'package:simple_spell_checker_et_lan/simple_spell_checker_et_lan.dart';
import 'package:simple_spell_checker_fr_lan/simple_spell_checker_fr_lan.dart';
import 'package:simple_spell_checker_he_lan/simple_spell_checker_he_lan.dart';
import 'package:simple_spell_checker_it_lan/simple_spell_checker_it_lan.dart';
import 'package:simple_spell_checker_nl_lan/simple_spell_checker_nl_lan.dart';
import 'package:simple_spell_checker_pt_lan/simple_spell_checker_pt_lan.dart';
import 'package:simple_spell_checker_ru_lan/simple_spell_checker_ru_lan.dart';

final spellCheckDictionaries = SpellCheckDictionaries();

class SpellCheckDictionaries {
  final _loadedLanguages = <String>{};
  final _onLoaded = ChangeNotifier();

  Set<String> get loadedLanguages => Set.unmodifiable(_loadedLanguages);
  Listenable get onLoaded => _onLoaded;
  bool get isReady => _loadedLanguages.isNotEmpty;

  bool _started = false;

  void loadAll() {
    if (_started) return;
    _started = true;

    final registrations = <String, void Function()>{
      'en': () => SimpleSpellCheckerEnRegister.registerLan(),
      'es': () => SimpleSpellCheckerEsRegister.registerLan(),
      'fr': () => SimpleSpellCheckerFrRegister.registerLan(),
      'de': () => SimpleSpellCheckerDeRegister.registerLan(),
      'it': () => SimpleSpellCheckerItRegister.registerLan(),
      'pt': () => SimpleSpellCheckerPtRegister.registerLan(),
      'nl': () => SimpleSpellCheckerNlRegister.registerLan(),
      'ru': () => SimpleSpellCheckerRuRegister.registerLan(),
      'ar': () => SimpleSpellCheckerArRegister.registerLan(),
      'da': () => SimpleSpellCheckerDaRegister.registerLan(),
      'bg': () => SimpleSpellCheckerBgRegister.registerLan(),
      'ca': () => SimpleSpellCheckerCaRegister.registerLan(),
      'et': () => SimpleSpellCheckerEtRegister.registerLan(),
      'he': () => SimpleSpellCheckerHeRegister.registerLan(),
    };

    _loadSequentially(registrations.entries.toList());
  }

  static const _maxRetries = 3;

  Future<void> _loadSequentially(
      List<MapEntry<String, void Function()>> entries) async {
    final failed = <MapEntry<String, void Function()>>[];

    for (final entry in entries) {
      await Future.delayed(Duration.zero);
      if (!_tryRegister(entry)) {
        failed.add(entry);
      }
    }

    for (var attempt = 1;
        attempt <= _maxRetries && failed.isNotEmpty;
        attempt++) {
      await Future.delayed(Duration(seconds: attempt * 2));
      failed.removeWhere(_tryRegister);
    }
  }

  bool _tryRegister(MapEntry<String, void Function()> entry) {
    try {
      entry.value();
      _loadedLanguages.add(entry.key);
      // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
      _onLoaded.notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }
}
