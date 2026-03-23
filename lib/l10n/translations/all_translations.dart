// Barrel file — imports every language map and exposes a single lookup.

import 'package:billeasy/screens/language_selection_screen.dart';

import 'en.dart';
import 'hi.dart';
import 'as.dart';
import 'gu.dart';
import 'ta.dart';
import 'bn.dart';
import 'te.dart';
import 'mr.dart';
import 'kn.dart';
import 'ml.dart';
import 'or_.dart';
import 'pa.dart';
import 'ur.dart';
import 'sd.dart';
import 'ks.dart';
import 'ne.dart';
import 'mai.dart';
import 'sa.dart';
import 'kok.dart';
import 'doi.dart';
import 'mni.dart';
import 'brx.dart';
import 'sat.dart';

/// Master map: AppLanguage → translation map.
const Map<AppLanguage, Map<String, String>> allTranslations = {
  AppLanguage.english: enTranslations,
  AppLanguage.hindi: hiTranslations,
  AppLanguage.assamese: asTranslations,
  AppLanguage.gujarati: guTranslations,
  AppLanguage.tamil: taTranslations,
  AppLanguage.bengali: bnTranslations,
  AppLanguage.telugu: teTranslations,
  AppLanguage.marathi: mrTranslations,
  AppLanguage.kannada: knTranslations,
  AppLanguage.malayalam: mlTranslations,
  AppLanguage.odia: or_Translations,
  AppLanguage.punjabi: paTranslations,
  AppLanguage.urdu: urTranslations,
  AppLanguage.sindhi: sdTranslations,
  AppLanguage.kashmiri: ksTranslations,
  AppLanguage.nepali: neTranslations,
  AppLanguage.maithili: maiTranslations,
  AppLanguage.sanskrit: saTranslations,
  AppLanguage.konkani: kokTranslations,
  AppLanguage.dogri: doiTranslations,
  AppLanguage.manipuri: mniTranslations,
  AppLanguage.bodo: brxTranslations,
  AppLanguage.santali: satTranslations,
};
