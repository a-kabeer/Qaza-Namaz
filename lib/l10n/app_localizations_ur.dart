// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Urdu (`ur`).
class AppLocalizationsUr extends AppLocalizations {
  AppLocalizationsUr([String locale = 'ur']) : super(locale);

  @override
  String get appTitle => 'قضا نماز';

  @override
  String get navHome => 'ہوم';

  @override
  String get navQaza => 'قضا';

  @override
  String get navKnowledge => 'معلومات';

  @override
  String get navSettings => 'ترتیبات';

  @override
  String get prayerFajr => 'فجر';

  @override
  String get prayerZuhr => 'ظہر';

  @override
  String get prayerAsr => 'عصر';

  @override
  String get prayerMaghrib => 'مغرب';

  @override
  String get prayerIsha => 'عشاء';

  @override
  String get prayerWitr => 'وتر';

  @override
  String get statusPending => 'باقی';

  @override
  String get statusDeleted => 'حالیہ حذف شدہ';

  @override
  String get statusCompleted => 'مکمل';

  @override
  String qazaConfirmBulkTitle(String count) {
    return '$count ریکارڈ مکمل کریں؟';
  }

  @override
  String qazaConfirmBulkMessage(String count) {
    return 'اس سے $count زیر التوا نمازیں مکمل شمار ہوں گی۔ آپ فوراً بعد واپس کر سکتے ہیں، بعد میں نہیں۔';
  }

  @override
  String get qazaConfirmBulkAction => 'مکمل کریں';

  @override
  String get errorNetwork =>
      'کوئی رابطہ نہیں۔ آپ کی قضا اس ڈیوائس پر محفوظ ہیں اور آن لائن ہوتے ہی سنک ہو جائیں گی۔';

  @override
  String get errorTimeout => 'بہت وقت لگ گیا۔ تھوڑی دیر بعد دوبارہ کوشش کریں۔';

  @override
  String get errorPermission =>
      'اس کے لیے اجازت درکار ہے۔ سیٹنگز میں جا کر اجازت دیں۔';

  @override
  String get errorAuthentication => 'اس کے لیے سائن ان ہونا ضروری ہے۔';

  @override
  String get errorValidation =>
      'یہ انپٹ قبول نہیں ہوئی۔ جانچ کر دوبارہ کوشش کریں۔';

  @override
  String get errorMalformedData => 'یہ فائل قضا بیک اپ نہیں، یا خراب ہے۔';

  @override
  String get errorStorage =>
      'ڈیوائس تبدیلی محفوظ نہیں کر سکا۔ کچھ جگہ خالی کر کے دوبارہ کوشش کریں۔';

  @override
  String get errorUnknown => 'کچھ غلط ہو گیا۔';

  @override
  String get homeTartibCheckingTitle => 'نماز کی ترتیب جانچی جا رہی ہے';

  @override
  String get homeTartibCheckingBody =>
      'صاحب الترتیب طے کرتا ہے کہ اگلی فرض نماز کون سی ہے۔ ایک لمحہ۔';

  @override
  String get homeTartibFailedTitle => 'نماز کی ترتیب جانچی نہیں جا سکی';

  @override
  String get homeTartibFailedBody =>
      'ترتیب معلوم ہونے تک فرض نمازیں روک لی گئی ہیں تاکہ کوئی نماز بے ترتیب مکمل نہ ہو۔ وتر اب بھی مینیو سے مکمل کی جا سکتی ہے۔';

  @override
  String get qazaSortOldestFirst => 'پہلے پرانی';

  @override
  String get qazaSortNewestFirst => 'پہلے نئی';

  @override
  String get filterAll => 'سب';

  @override
  String get commonRetry => 'دوبارہ کوشش کریں';

  @override
  String get commonVersion => 'ورژن';

  @override
  String get stateErrorTitle => 'کچھ غلط ہو گیا';

  @override
  String get commonClose => 'بند کریں';

  @override
  String get commonCancel => 'منسوخ کریں';

  @override
  String get commonDone => 'مکمل';

  @override
  String get commonReset => 'ری سیٹ';

  @override
  String get commonClear => 'صاف کریں';

  @override
  String get commonContinue => 'جاری رکھیں';

  @override
  String get commonLoading => 'لوڈ ہو رہا ہے...';

  @override
  String hijriDate(Object day, Object month, Object year) {
    return '$day $month $year ھ';
  }

  @override
  String get homeTitle => 'ہوم';

  @override
  String get homeProfileTooltip => 'پروفائل';

  @override
  String get homeHeadingSetup => 'اپنا قضا سفر شروع کریں';

  @override
  String get homeSetupMessage => 'آپ نے اب تک کوئی قضا نماز شامل نہیں کی۔';

  @override
  String get homeCompleteQaza => 'قضا ادا کریں';

  @override
  String get homeStatTotal => 'کل';

  @override
  String get homeProgressError =>
      'آپ کی قضا کی پیش رفت لوڈ نہیں ہو سکی۔ دوبارہ کوشش کے لیے نیچے کھینچیں۔';

  @override
  String get homeQazaPlan => 'قضا کا منصوبہ';

  @override
  String get homeAuto => 'خودکار';

  @override
  String get homeDailyTarget => 'روزانہ ہدف';

  @override
  String homePerDay(int count) {
    return 'روزانہ $count';
  }

  @override
  String homeEstimatedCompletion(String date) {
    return 'متوقع تکمیل: $date';
  }

  @override
  String get homeNextQaza => 'اگلی قضا';

  @override
  String get homeDailyProgressError => 'آج کی پیش رفت لوڈ نہیں ہو سکی۔';

  @override
  String progressCompletedPending(String completed, String pending) {
    return '$completed مکمل • $pending باقی';
  }

  @override
  String get qazaTitle => 'قضا';

  @override
  String get qazaProgressLabel => 'پیش رفت';

  @override
  String get qazaDateFilterAny => 'اصل تاریخ: کوئی بھی';

  @override
  String get qazaDateFilterHelp => 'اصل قضا تاریخ کے مطابق فلٹر کریں';

  @override
  String qazaDateFilterRange(String from, String to) {
    return '$from — $to';
  }

  @override
  String get qazaEmptyTitle => 'ابھی کوئی قضا ریکارڈ نہیں';

  @override
  String get qazaEmptyMessage =>
      'شروع کرنے کے لیے چھوٹی ہوئی نمازیں شامل کریں یا اندازہ لگائیں۔';

  @override
  String get qazaFilteredEmptyTitle => 'ان فلٹرز سے کوئی ریکارڈ نہیں ملا';

  @override
  String get qazaFilteredEmptyMessage =>
      'مختلف حالت، نماز یا تاریخ کی حد آزمائیں۔';

  @override
  String get qazaResetFilters => 'فلٹرز ری سیٹ کریں';

  @override
  String qazaTartibRequiredMessage(int count, String prayer) {
    return 'آپ کے ذمہ $count فرض نمازیں قضا باقی ہیں۔ اس حکم کے مطابق دوسری باقی قضا نمازوں سے پہلے $prayer کی قضا ادا کریں۔';
  }

  @override
  String qazaTartibBlocked(String prayer) {
    return 'قضا میں ترتیب لازم ہے۔ پہلے $prayer کی قضا ادا کریں۔';
  }

  @override
  String qazaCompletedOn(String date) {
    return '$date کو مکمل';
  }

  @override
  String qazaCompleteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count قضا مکمل کریں',
      one: '1 قضا مکمل کریں',
    );
    return '$_temp0';
  }

  @override
  String get qazaEditRecordTitle => 'قضا میں ترمیم';

  @override
  String get qazaEditPrayer => 'نماز';

  @override
  String get qazaEditDate => 'اصل تاریخ';

  @override
  String get qazaEditDateHelp => 'قضا کی اصل تاریخ منتخب کریں';

  @override
  String get qazaSaveChanges => 'تبدیلیاں محفوظ کریں';

  @override
  String get qazaUndoAction => 'واپس کریں';

  @override
  String qazaUndoAvailable(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'حالیہ تکمیلات واپس کی جا سکتی ہیں۔',
      one: 'حالیہ تکمیل واپس کی جا سکتی ہے۔',
    );
    return '$_temp0';
  }

  @override
  String get splashTagline => 'نماز کی پابندی کے لیے ایک پُرسکون جگہ';

  @override
  String get addQazaNothingNew =>
      'شامل کرنے کو کچھ نیا نہیں — یہ مجموعے پہلے سے ریکارڈ ہیں۔';

  @override
  String get addQazaExistingLabel => 'پہلے سے موجود جوڑ';

  @override
  String get addQazaNewRecordsLabel => 'نئے ریکارڈ';

  @override
  String get addQazaInProgress => 'قضا شامل ہو رہی ہے...';

  @override
  String addQazaCreatedMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ریکارڈ آپ کے کھاتے میں شامل ہو گئے۔',
      one: '1 ریکارڈ آپ کے کھاتے میں شامل ہو گیا۔',
    );
    return '$_temp0';
  }

  @override
  String get completeLoadError => 'آپ کا قضا ریکارڈ لوڈ نہیں ہو سکا۔';

  @override
  String get completeNoPendingTitle => 'اس نماز کی کوئی قضا باقی نہیں۔';

  @override
  String get completeNoPendingMessage =>
      'کوئی اور نماز منتخب کریں یا پہلے قضا ریکارڈ شامل کریں۔';

  @override
  String get completeInProgress => 'مکمل ہو رہا ہے...';

  @override
  String get completeFailed => 'قضا مکمل نہیں ہو سکی۔ دوبارہ کوشش کریں۔';

  @override
  String get knowledgeBaseTitle => 'معلومات';

  @override
  String get knowledgeBaseSearchHint => 'مسائل و مغالطے تلاش کریں';

  @override
  String get knowledgeBaseClearSearch => 'تلاش صاف کریں';

  @override
  String get knowledgeCategoryMasail => 'مسائل';

  @override
  String get knowledgeCategoryMugalat => 'مغالطے';

  @override
  String get knowledgeBaseTopicAll => 'تمام موضوعات';

  @override
  String get knowledgeTopicBasic => 'بنیادی باتیں';

  @override
  String get knowledgeTopicPrayerUnits => 'رکعات';

  @override
  String get knowledgeTopicSleepForgetfulness => 'نیند اور بھول';

  @override
  String get knowledgeTopicIntentionalOmission => 'جان بوجھ کر ترک';

  @override
  String get knowledgeTopicFriday => 'جمعہ';

  @override
  String get knowledgeTopicMenstruation => 'حیض';

  @override
  String get knowledgeTopicNifas => 'نفاس';

  @override
  String get knowledgeTopicMenstruationNifas => 'حیض و نفاس';

  @override
  String get knowledgeTopicMisconceptions => 'مغالطے';

  @override
  String get knowledgeBaseEmptyTitle => 'کوئی مضمون نہیں ملا';

  @override
  String get knowledgeBaseEmptyMessage => 'کوئی اور تلاش یا زمرہ آزمائیں۔';

  @override
  String get knowledgeBaseLoadError => 'معلومات لوڈ نہیں ہو سکیں۔';

  @override
  String get knowledgeBaseLanguage => 'نولج بیس کی زبان';

  @override
  String get knowledgeArticleTitle => 'مضمون';

  @override
  String get knowledgeArticleReferences => 'حوالہ جات';

  @override
  String get knowledgeArticleRelated => 'متعلقہ مضامین';

  @override
  String get knowledgeArticleNotFound => 'مضمون نہیں ملا۔';

  @override
  String get settingsResetCounterTitle => 'قضا کاؤنٹر ری سیٹ کریں';

  @override
  String get settingsResetCounterSubtitle =>
      'درج شدہ تمام قضا نمازیں حذف کرکے گنتی دوبارہ صفر سے شروع کریں۔';

  @override
  String get settingsResetCounterEmpty =>
      'ری سیٹ کرنے کے لیے کوئی قضا ریکارڈ موجود نہیں۔';

  @override
  String get settingsResetCounterDialogTitle => 'کیا قضا کاؤنٹر ری سیٹ کریں؟';

  @override
  String get settingsResetCounterDialogMessage =>
      'اس اکاؤنٹ کے تمام قضا ریکارڈز — باقی اور مکمل دونوں — اس ڈیوائس اور آپ کے کلاؤڈ بیک اپ سے ہمیشہ کے لیے حذف ہو جائیں گے۔\n\nآپ کا کاؤنٹر صفر پر آ جائے گا اور اب تک کی گئی پیش رفت ضائع ہو جائے گی۔ یہ عمل واپس نہیں ہو سکتا۔ اگر دوبارہ ضرورت پڑ سکتی ہے تو پہلے اپنا ڈیٹا برآمد کر لیں۔';

  @override
  String settingsResetCounterAcknowledge(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'میں سمجھتا/سمجھتی ہوں کہ $count قضا ریکارڈز ہمیشہ کے لیے حذف ہو جائیں گے',
      one: 'میں سمجھتا/سمجھتی ہوں کہ 1 قضا ریکارڈ ہمیشہ کے لیے حذف ہو جائے گا',
    );
    return '$_temp0';
  }

  @override
  String get settingsResetCounterConfirm => 'کاؤنٹر ری سیٹ کریں';

  @override
  String get settingsResetCounterDone => 'قضا کاؤنٹر ری سیٹ ہو گیا۔';

  @override
  String settingsResetCounterFailed(String error) {
    return 'قضا کاؤنٹر ری سیٹ نہیں ہو سکا: $error';
  }

  @override
  String get settingsAboutSection => 'تعارف';

  @override
  String settingsAboutRowSubtitle(String version) {
    return 'قضا نماز • ورژن $version';
  }

  @override
  String get settingsAppDescription => 'اسلامی نماز قضا ٹریکر';

  @override
  String get settingsTitle => 'ترتیبات';

  @override
  String get settingsLanguage => 'زبان';

  @override
  String get settingsLanguageSubtitle =>
      'ایپ میں استعمال ہونے والی زبان منتخب کریں۔';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageUrdu => 'اردو';

  @override
  String get homeTodayProgressHeader => 'آج کی پیش رفت';

  @override
  String get homeOldestPending => 'سب سے پرانی باقی';

  @override
  String get homeOverallQaza => 'مجموعی قضا';

  @override
  String get homePendingByPrayer => 'نماز کے لحاظ سے باقی';

  @override
  String get homePrayerBreakdown => 'نماز وار جائزہ';

  @override
  String get homeViewDetails => 'تفصیلات دیکھیں';

  @override
  String get homeViewAll => 'سب دیکھیں';

  @override
  String get homeCompleted => 'مکمل';

  @override
  String get homePending => 'باقی';

  @override
  String get homeDetailedStatistics => 'تفصیلی اعداد و شمار';

  @override
  String homeSahibOrderLabel(String prayer) {
    return 'صاحبِ ترتیب: $prayer';
  }

  @override
  String get profileLanguageTitle => 'اپنی زبان منتخب کریں';

  @override
  String get profileLanguageIntro =>
      'ایپ میں استعمال ہونے والی زبان منتخب کریں۔';

  @override
  String get profileSetupTitle => 'اپنا پروفائل مکمل کریں';

  @override
  String get profileTitle => 'پروفائل';

  @override
  String get profileIntro =>
      'یہ معلومات آپ کے قضا پلان اور نماز سے متعلق قواعد کے لیے استعمال ہوں گی۔';

  @override
  String get profileSettingsSubtitle =>
      'آپ کی نماز پروفائل اور قضا پلان کی ترتیبات۔';

  @override
  String get profileGender => 'صنف';

  @override
  String get profileMale => 'مرد';

  @override
  String get profileFemale => 'خاتون';

  @override
  String get profileMadhab => 'مذہب / فقہی مکتب';

  @override
  String get profileHanafi => 'حنفی';

  @override
  String get profileShafi => 'شافعی';

  @override
  String get profileMaliki => 'مالکی';

  @override
  String get profileHanbali => 'حنبلی';

  @override
  String get profileOther => 'دیگر';

  @override
  String get profileDateOfBirth => 'تاریخ پیدائش';

  @override
  String get profileSelectDate => 'تاریخ منتخب کریں';

  @override
  String get profileSelectDobHelp => 'اپنی تاریخ پیدائش منتخب کریں';

  @override
  String get profilePubertyAge => 'بلوغت کی عمر';

  @override
  String get profileStartPrayingAge => 'نماز شروع کرنے کی عمر';

  @override
  String get profileSelectGenderFirst => 'پہلے صنف منتخب کریں';

  @override
  String get profileSelectPubertyFirst => 'پہلے بلوغت کی عمر منتخب کریں';

  @override
  String get profileSelectDobFirst => 'پہلے تاریخ پیدائش منتخب کریں';

  @override
  String get profileWitr => 'وتر';

  @override
  String get profileWitrOptional =>
      'دیگر کے لیے آپ منتخب کر سکتے ہیں کہ وتر شامل ہوں یا نہیں۔';

  @override
  String get profileWitrIncluded => 'شامل';

  @override
  String get profileWitrExcluded => 'شامل نہیں';

  @override
  String get profileSubmit => 'جاری رکھیں';

  @override
  String get profileSave => 'تبدیلیاں محفوظ کریں';

  @override
  String get qazaReviewTitle => 'اپنا قضا پلان دیکھیں';

  @override
  String get qazaReviewSubtitle =>
      'قضا ٹریکر میں شامل کرنے سے پہلے اپنی تفصیلات کا جائزہ لیں۔';

  @override
  String get qazaReviewTotal => 'کل اندازاً قضا نمازیں';

  @override
  String get qazaReviewPeriod => 'قضا کی مدت';

  @override
  String get qazaReviewBreakdown => 'نماز وار تفصیل';

  @override
  String get qazaReviewNote =>
      'یہ آپ کے پروفائل کی معلومات کی بنیاد پر قضا نمازوں کا اندازہ ہے۔';

  @override
  String get qazaReviewEdit => 'اپنی تفصیلات میں ترمیم کریں';

  @override
  String get qazaReviewAdd => 'قضا کو میرے ٹریکر میں شامل کریں';

  @override
  String get qazaReviewAdding => 'قضا شامل ہو رہی ہے…';

  @override
  String get qazaReviewError => 'قضا شامل نہیں ہو سکی۔ دوبارہ کوشش کریں۔';

  @override
  String get profileErrorLanguage => 'براہ کرم زبان منتخب کریں۔';

  @override
  String get profileErrorGender => 'براہ کرم اپنی صنف منتخب کریں۔';

  @override
  String get profileErrorMadhab => 'براہ کرم اپنا فقہی مکتب منتخب کریں۔';

  @override
  String get profileErrorDob => 'براہ کرم درست تاریخ پیدائش درج کریں۔';

  @override
  String get profileErrorPuberty =>
      'منتخب صنف کے لیے درست بلوغت کی عمر منتخب کریں۔';

  @override
  String get profileErrorStartPraying =>
      'براہ کرم نماز شروع کرنے کی درست عمر منتخب کریں۔';

  @override
  String get profileErrorWitr => 'براہ کرم وتر کی درست ترتیب منتخب کریں۔';
}
