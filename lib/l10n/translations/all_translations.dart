// Barrel file — imports every language map and exposes a single lookup.

import 'package:billeasy/screens/language_selection_screen.dart';

import 'en.dart';
import 'hi.dart';
import 'as.dart';
import 'gu.dart';
import 'ta.dart';

/// Master map: AppLanguage → translation map.
const Map<AppLanguage, Map<String, String>> allTranslations = {
  AppLanguage.english: enTranslations,
  AppLanguage.hindi: hiTranslations,
  AppLanguage.assamese: asTranslations,
  AppLanguage.gujarati: guTranslations,
  AppLanguage.tamil: taTranslations,
};
