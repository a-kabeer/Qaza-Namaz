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
  String get navKnowledge => 'رہنمائی';

  @override
  String get settingsRemindersSection => 'یاد دہانیاں';

  @override
  String get settingsRemindersSubtitle => 'قضا مکمل کرنے کی روزانہ یاد دہانی۔';

  @override
  String get settingsBackupSection => 'ڈیٹا اور اسٹوریج';

  @override
  String get settingsBackupSubtitle => 'کلاؤڈ سنک، برآمد اور درآمد۔';

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
  String get statusCompleted => 'مکمل';

  @override
  String get qazaSelectAllMatching => 'سب مطابق منتخب کریں';

  @override
  String qazaSelectAllMatchingCapped(String count) {
    return 'پہلے $count مطابق ریکارڈ منتخب کر لیے گئے۔';
  }

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
  String get commonOpenSettings => 'سیٹنگز کھولیں';

  @override
  String get qazaSortLabel => 'ترتیب';

  @override
  String get qazaSortOldestFirst => 'پہلے پرانی';

  @override
  String get qazaSortNewestFirst => 'پہلے نئی';

  @override
  String get filterAll => 'سب';

  @override
  String get commonRetry => 'دوبارہ کوشش کریں';

  @override
  String get commonTotal => 'کل';

  @override
  String get commonVersion => 'ورژن';

  @override
  String get stateErrorTitle => 'کچھ غلط ہو گیا';

  @override
  String get prayerRakatFajr => 'فجر • 2 رکعت فرض';

  @override
  String get prayerRakatZuhr => 'ظہر • 4 رکعت فرض';

  @override
  String get prayerRakatAsr => 'عصر • 4 رکعت فرض';

  @override
  String get prayerRakatMaghrib => 'مغرب • 3 رکعت فرض';

  @override
  String get prayerRakatIsha => 'عشاء • 4 رکعت فرض';

  @override
  String get prayerRakatWitr => 'وتر • 3 رکعت واجب • مستقل';

  @override
  String get syncSettingUp => 'ترتیب دی جا رہی ہے';

  @override
  String get syncSettingUpDetail =>
      'اس ڈیوائس پر آپ کے قضا ریکارڈ تیار کیے جا رہے ہیں۔';

  @override
  String get syncRestoring => 'بحال کیا جا رہا ہے';

  @override
  String get syncRestoringDetail =>
      'آپ کے محفوظ قضا ریکارڈ اس ڈیوائس پر لائے جا رہے ہیں۔';

  @override
  String get syncSynced => 'سنک شدہ';

  @override
  String syncSyncedAt(String timestamp) {
    return 'سنک شدہ • $timestamp';
  }

  @override
  String get syncSyncing => 'سنک ہو رہا ہے';

  @override
  String get syncSaved => 'محفوظ';

  @override
  String get syncSavedDetail =>
      'آپ کی تبدیلیاں اس ڈیوائس پر محفوظ ہیں اور خود بخود سنک ہو جائیں گی۔';

  @override
  String get syncErrorLabel => 'سنک میں مسئلہ';

  @override
  String get syncErrorDetail =>
      'آپ کی تبدیلیاں اس ڈیوائس پر محفوظ ہیں۔ ہم خود بخود دوبارہ کوشش کریں گے۔';

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
  String get commonBack => 'واپس';

  @override
  String get commonContinue => 'جاری رکھیں';

  @override
  String get commonLoading => 'لوڈ ہو رہا ہے...';

  @override
  String get commonToday => 'آج';

  @override
  String get commonYesterday => 'کل';

  @override
  String hijriDate(Object day, Object month, Object year) {
    return '$day $month $year ھ';
  }

  @override
  String hijriMonthYear(Object month, Object year) {
    return '$month $year ھ';
  }

  @override
  String get hijriMonthMuharram => 'محرم';

  @override
  String get hijriMonthSafar => 'صفر';

  @override
  String get hijriMonthRabiAlAwwal => 'ربیع الاول';

  @override
  String get hijriMonthRabiAlThani => 'ربیع الثانی';

  @override
  String get hijriMonthJumadaAlAwwal => 'جمادی الاول';

  @override
  String get hijriMonthJumadaAlThani => 'جمادی الثانی';

  @override
  String get hijriMonthRajab => 'رجب';

  @override
  String get hijriMonthShaban => 'شعبان';

  @override
  String get hijriMonthRamadan => 'رمضان';

  @override
  String get hijriMonthShawwal => 'شوال';

  @override
  String get hijriMonthDhulQadah => 'ذوالقعدہ';

  @override
  String get hijriMonthDhulHijjah => 'ذوالحجہ';

  @override
  String get homeTitle => 'ہوم';

  @override
  String get homeProfileTooltip => 'پروفائل';

  @override
  String get homeHeadingSetup => 'اپنا قضا سفر شروع کریں';

  @override
  String get homeHeadingPending => 'جاری رکھیں';

  @override
  String get homeHeadingCompleted => 'آپ کی تمام قضا مکمل ہے';

  @override
  String get homeSetupMessage => 'آپ نے اب تک کوئی قضا نماز شامل نہیں کی۔';

  @override
  String get homeCompleteQaza => 'قضا ادا کریں';

  @override
  String get homeAddNewQaza => 'نئی قضا شامل کریں';

  @override
  String get homeAddManually => 'دستی طور پر قضا شامل کریں';

  @override
  String get homeStatTotal => 'کل';

  @override
  String get homeAddQaza => 'قضا شامل کریں';

  @override
  String homeCompletedCount(int count) {
    return '$count مکمل';
  }

  @override
  String get homeProgressTitle => 'آپ کی پیش رفت';

  @override
  String get homeProgressError =>
      'آپ کی قضا کی پیش رفت لوڈ نہیں ہو سکی۔ دوبارہ کوشش کے لیے نیچے کھینچیں۔';

  @override
  String get homeTodayProgress => 'آج کی پیش رفت';

  @override
  String homeDailyProgress(int completed, int target) {
    return '$completed / $target مکمل';
  }

  @override
  String homeDailyRemaining(int count) {
    return '$count باقی';
  }

  @override
  String get homeQazaPlan => 'قضا کا منصوبہ';

  @override
  String get homeCompleteOldestQaza => 'سب سے پرانی قضا مکمل کریں';

  @override
  String get homeAuto => 'خودکار';

  @override
  String get homeAutoSequence => 'خودکار ترتیب';

  @override
  String get homeQazaTarget => 'قضا کا ہدف';

  @override
  String get homePrayerSelection => 'نماز کا انتخاب';

  @override
  String get homePrayerTimeUnavailable =>
      'نماز کے اوقات سیٹ ہونے تک وقتِ نماز کے مطابق انتخاب دستیاب نہیں۔';

  @override
  String get homeQazaTargetReachedTitle => 'الحمدللہ!';

  @override
  String get homeQazaTargetReachedMessage =>
      'آپ نے آج کا اپنا قضا منصوبہ مکمل کر لیا ہے۔\nاللہ تعالیٰ آپ کی کوششیں قبول فرمائے۔';

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
  String get homeCompleteNextQaza => 'اگلی قضا مکمل کریں';

  @override
  String get homeViewAllQaza => 'تمام قضا دیکھیں';

  @override
  String get homeDailyProgressError => 'آج کی پیش رفت لوڈ نہیں ہو سکی۔';

  @override
  String progressPendingCompleted(String pending, String completed) {
    return '$pending باقی • $completed مکمل';
  }

  @override
  String progressCompletedPending(String completed, String pending) {
    return '$completed مکمل • $pending باقی';
  }

  @override
  String get qazaTitle => 'قضا';

  @override
  String get qazaProgressLabel => 'پیش رفت';

  @override
  String get qazaAddTooltip => 'قضا شامل کریں';

  @override
  String get qazaDateFilterAny => 'اصل تاریخ: کوئی بھی';

  @override
  String get qazaDateFilterHelp => 'اصل قضا تاریخ کے مطابق فلٹر کریں';

  @override
  String qazaDateFilterRange(String from, String to) {
    return '$from — $to';
  }

  @override
  String get qazaLoading => 'آپ کے قضا ریکارڈ لوڈ ہو رہے ہیں...';

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
  String qazaLoadError(String error) {
    return 'آپ کے قضا ریکارڈ لوڈ نہیں ہو سکے: $error';
  }

  @override
  String qazaLoadMoreError(String error) {
    return 'مزید ریکارڈ لوڈ نہیں ہو سکے: $error';
  }

  @override
  String qazaCompleteError(String error) {
    return 'منتخب قضا مکمل نہیں ہو سکی: $error';
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
  String get qazaRecordActions => 'ریکارڈ کے اعمال';

  @override
  String get qazaEditRecord => 'ترمیم';

  @override
  String get qazaDeleteRecord => 'حذف کریں';

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
  String get qazaDeleteRecordTitle => 'قضا ریکارڈ حذف کریں؟';

  @override
  String qazaDeleteRecordMessage(Object date, Object prayer) {
    return '$date کی $prayer قضا مستقل طور پر حذف کریں؟ یہ عمل واپس نہیں ہو سکتا۔';
  }

  @override
  String get qazaRecordUpdated => 'قضا ریکارڈ اپ ڈیٹ ہو گیا۔';

  @override
  String qazaDuplicateRecord(Object date, Object prayer) {
    return '$date کی $prayer قضا پہلے سے موجود ہے۔';
  }

  @override
  String get qazaRecordUpdateFailed =>
      'قضا ریکارڈ اپ ڈیٹ نہیں ہو سکا۔ دوبارہ کوشش کریں۔';

  @override
  String get qazaRecordDeleted => 'قضا مستقل طور پر حذف ہو گئی ہے۔';

  @override
  String get qazaRecordDeleteFailed =>
      'قضا ریکارڈ حذف نہیں ہو سکا۔ دوبارہ کوشش کریں۔';

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
  String qazaUndoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count قضا دوبارہ باقی ہو گئیں۔',
      one: '1 قضا دوبارہ باقی ہو گئی۔',
    );
    return '$_temp0';
  }

  @override
  String qazaCompletedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count قضا مکمل ہو گئیں۔',
      one: '1 قضا مکمل ہو گئی۔',
      zero: 'کچھ مکمل نہیں ہوا۔',
    );
    return '$_temp0';
  }

  @override
  String get calendarSelectYear => 'سال منتخب کریں';

  @override
  String get calendarSelectHint =>
      'منتخب کرنے کے لیے دستیاب تاریخ پر ٹیپ کریں۔';

  @override
  String calendarSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count تاریخیں منتخب۔',
      one: '1 تاریخ منتخب۔',
    );
    return '$_temp0';
  }

  @override
  String get authTitle => 'سائن اِن';

  @override
  String get authWelcomeBack => 'خوش آمدید';

  @override
  String get authSubtitle =>
      'اپنے قضا نماز ٹریکر تک رسائی کے لیے سائن اِن کریں۔';

  @override
  String get authContinueWithGoogle => 'گوگل سے جاری رکھیں';

  @override
  String get authSigningIn => 'سائن اِن ہو رہا ہے...';

  @override
  String get authProviderNote =>
      'اس وقت گوگل ہی منسلک توثیقی فراہم کنندہ ہے۔ سائن اِن کی حالت فائربیس سے خود بخود بحال ہو جاتی ہے۔';

  @override
  String get authHelpTooltip => 'توثیق میں مدد';

  @override
  String get authHelpTitle => 'توثیق';

  @override
  String get authHelpBody =>
      'اس ریلیز میں گوگل سائن اِن ہی منسلک توثیقی طریقہ ہے۔ آپ کا قضا ڈیٹا اسی فائربیس اکاؤنٹ سے منسلک رہتا ہے جس سے آپ سائن اِن کرتے ہیں۔';

  @override
  String get authDismiss => 'بند کریں';

  @override
  String get authFailed => 'سائن اِن نہیں ہو سکا۔ دوبارہ کوشش کریں۔';

  @override
  String get welcomeTagline => 'روحانی عبادت اور نماز کی پابندی';

  @override
  String get welcomeHeadline =>
      'اپنی چھوٹی ہوئی نمازوں کا وضاحت اور تسلسل کے ساتھ حساب رکھیں۔';

  @override
  String get welcomeBody =>
      'اپنی قضا نمازیں درج کریں، ادا کریں اور ان کا حساب رکھیں — ایک ایک نماز کر کے۔';

  @override
  String get welcomeGetStarted => 'شروع کریں';

  @override
  String get welcomeSignIn => 'پہلے سے اکاؤنٹ ہے؟ سائن اِن کریں';

  @override
  String get splashTagline => 'نماز کی پابندی کے لیے ایک پُرسکون جگہ';

  @override
  String get accountChoiceHeadline => 'اپنی قضا کی پیش رفت محفوظ رکھیں';

  @override
  String get accountChoiceDescription =>
      'گوگل سے سائن اِن کریں تاکہ آپ کی پیش رفت مختلف ڈیوائسز پر محفوظ اور بحال ہو سکے۔';

  @override
  String get accountChoiceContinueGoogle => 'گوگل کے ساتھ جاری رکھیں';

  @override
  String get accountChoiceContinueGuest => 'مہمان کے طور پر جاری رکھیں';

  @override
  String get accountChoiceGuestDescription =>
      'مہمان کا ڈیٹا اسی ڈیوائس پر محفوظ رہتا ہے۔ آپ بعد میں گوگل منسلک کر سکتے ہیں۔';

  @override
  String get accountChoiceGoogleFailed =>
      'گوگل سائن اِن مکمل نہیں ہو سکا۔ دوبارہ کوشش کریں۔';

  @override
  String get accountTitle => 'اکاؤنٹ';

  @override
  String get accountProfileChecking =>
      'گوگل اکاؤنٹ کی حالت معلوم کی جا رہی ہے…';

  @override
  String get accountProfileUnavailable => 'گوگل اکاؤنٹ کی حالت دستیاب نہیں';

  @override
  String get accountProfileUnavailableDetail =>
      'آپ کے قضا ریکارڈ اس ڈیوائس پر دستیاب رہیں گے۔';

  @override
  String get accountGuest => 'مہمان';

  @override
  String get accountConnectGoogle => 'گوگل سے منسلک کریں';

  @override
  String get accountSignInMethod => 'سائن اِن کا طریقہ';

  @override
  String get accountGoogleAuth => 'گوگل';

  @override
  String get accountSignedInWithGoogle => 'گوگل سے سائن اِن ہیں';

  @override
  String get accountStatus => 'اکاؤنٹ کی حالت';

  @override
  String get accountSignedIn => 'مقامی';

  @override
  String get accountRecordsRetained =>
      'آپ کے محفوظ قضا ریکارڈ موجود رہیں گے اور اگلی بار سائن اِن پر بحال ہو جائیں گے۔';

  @override
  String get accountDeveloperContext => 'ڈویلپر تفصیلات';

  @override
  String get accountFirebaseUid => 'فائربیس UID';

  @override
  String get accountNotAvailable => 'دستیاب نہیں';

  @override
  String get accountSignOut => 'سائن آؤٹ';

  @override
  String get accountSignOutPrompt => 'سائن آؤٹ کریں؟';

  @override
  String get accountSignOutExplanation =>
      'سائن آؤٹ کرنے سے آپ کا گوگل اکاؤنٹ منقطع ہو جائے گا۔ آپ کی قضا پیش رفت اس ڈیوائس پر برقرار رہے گی۔';

  @override
  String get dataTitle => 'برآمد و درآمد';

  @override
  String get dataExportTitle => 'ڈیٹا برآمد کریں';

  @override
  String get dataExportBody =>
      'اپنے قضا کھاتے کی ایک JSON نقل محفوظ کریں۔ برآمد کرنے سے کچھ اپ لوڈ نہیں ہوتا۔';

  @override
  String get dataExportAction => 'برآمد';

  @override
  String get dataExportDialogTitle => 'قضا ڈیٹا برآمد محفوظ کریں';

  @override
  String get dataExportSaved => 'برآمد کامیابی سے محفوظ ہو گئی۔';

  @override
  String get dataExportCanceled =>
      'برآمد منسوخ ہوئی۔ آپ کا ڈیٹا تبدیل نہیں ہوا۔';

  @override
  String get dataExportSignInRequired =>
      'اپنا قضا ڈیٹا برآمد کرنے سے پہلے سائن اِن کریں۔';

  @override
  String dataExportFailed(String error) {
    return 'برآمد ناکام: $error';
  }

  @override
  String get dataImportTitle => 'ڈیٹا درآمد کریں';

  @override
  String get dataImportBody =>
      'کوئی JSON برآمد کھولیں، اس کی مکمل جانچ کریں، انضمام کا جائزہ لیں، پھر اسے اس اکاؤنٹ پر لاگو کریں۔';

  @override
  String get dataImportAction => 'درآمد';

  @override
  String get dataImportReviewTitle => 'ڈیٹا درآمد کا جائزہ';

  @override
  String get dataImportCanceled =>
      'درآمد منسوخ ہوئی۔ آپ کا ڈیٹا تبدیل نہیں ہوا۔';

  @override
  String get dataImportSignInRequired =>
      'ڈیٹا درآمد کرنے سے پہلے سائن اِن کریں۔';

  @override
  String get dataImportEmptyFile => 'منتخب فائل خالی یا ناقابلِ مطالعہ ہے۔';

  @override
  String dataImportRejected(String error) {
    return 'درآمد مسترد: $error\nکوئی جزوی درآمد لاگو نہیں ہوئی۔';
  }

  @override
  String dataImportComplete(int added, int completed, int unchanged) {
    return 'درآمد مکمل: $added شامل، $completed مکمل، $unchanged بغیر تبدیلی۔';
  }

  @override
  String get dataProcessing => 'ڈیٹا پر کام ہو رہا ہے…';

  @override
  String get dataSafetyTitle => 'ڈیٹا کی حفاظت';

  @override
  String get dataSafetyBody =>
      'برآمد کرنے سے کلاؤڈ ڈیٹا حذف نہیں ہوتا۔ درآمد سے موجودہ ریکارڈ ختم نہیں ہوتے۔ سائن آؤٹ ڈیٹا حذف کرنا نہیں، اور ایپ اَن انسٹال کرنے سے کلاؤڈ ریکارڈ حذف نہیں ہوتے۔';

  @override
  String get dataRemapNote =>
      'درآمد شدہ ریکارڈ موجودہ سائن اِن اکاؤنٹ سے منسلک کر دیے جاتے ہیں۔ اس کے بعد موجودہ لوکل-فرسٹ سنک پرت پس منظر میں فائرسٹور سے تصدیق کرتی ہے۔';

  @override
  String get addQazaTitle => 'قضا شامل کریں';

  @override
  String get addQazaStep1 => 'مرحلہ 1 از 3 • تاریخیں منتخب کریں';

  @override
  String get addQazaStep2 => 'مرحلہ 2 از 3 • چھوٹی ہوئی نمازیں منتخب کریں';

  @override
  String get addQazaStep3 => 'مرحلہ 3 از 3 • جائزہ اور اضافہ';

  @override
  String get addQazaModeSingle => 'ایک';

  @override
  String get addQazaModeRange => 'دورانیہ';

  @override
  String get addQazaModeMultiple => 'متعدد';

  @override
  String get addQazaModeSingleTitle => 'ایک تاریخ';

  @override
  String get addQazaModeRangeTitle => 'تاریخوں کا دورانیہ';

  @override
  String get addQazaModeMultipleTitle => 'متعدد تاریخیں';

  @override
  String get addQazaChooseSingle => 'ایک تاریخ منتخب کریں';

  @override
  String get addQazaChooseRange => 'تاریخوں کا دورانیہ منتخب کریں';

  @override
  String get addQazaChooseMultiple => 'متعدد تاریخیں منتخب کریں';

  @override
  String get addQazaAvailabilityNote =>
      'رینج موڈ میں درست تاریخیں منتخب کی جا سکتی ہیں، چاہے ان پر کوئی قضا باقی نہ ہو؛ جائزہ صرف اہل نمازیں شامل کرتا ہے۔';

  @override
  String get addQazaStepNameDates => 'تاریخیں منتخب کریں';

  @override
  String get addQazaStepNamePrayers => 'قضا نمازیں';

  @override
  String get addQazaStepNameReview => 'جائزہ';

  @override
  String addQazaStepSemantics(int step, String name) {
    return 'مرحلہ $step: $name';
  }

  @override
  String addQazaPartialAvailability(int available, int total) {
    return '$total میں سے $available تاریخوں پر دستیاب';
  }

  @override
  String get addQazaAvailableEveryDate => 'ہر منتخب تاریخ پر دستیاب';

  @override
  String get addQazaEligibleOnlyNote =>
      'صرف اہل تاریخ اور نماز کے مجموعے شامل کیے جائیں گے۔ پہلے سے ریکارڈ شدہ چھوڑ دیے جائیں گے۔';

  @override
  String addQazaAddCount(String count) {
    return '$count قضا شامل کریں';
  }

  @override
  String get addQazaNothingNew =>
      'شامل کرنے کو کچھ نیا نہیں — یہ مجموعے پہلے سے ریکارڈ ہیں۔';

  @override
  String get addQazaChecking => 'آپ کا لیڈجر جانچا جا رہا ہے...';

  @override
  String get addQazaNextPrayers => 'اگلا: جائزہ اور اضافہ';

  @override
  String get addQazaPrayersHeading => 'چھوٹی ہوئی نمازیں';

  @override
  String get addQazaSelectAll => 'سب منتخب کریں';

  @override
  String get addQazaAllSelected => 'سب منتخب ہیں';

  @override
  String get addQazaReviewHeading => 'جائزہ اور اضافہ';

  @override
  String get addQazaReviewNote =>
      'خلاصے کی تصدیق کریں، پھر یہ قضا ریکارڈ اپنے کھاتے میں شامل کریں۔';

  @override
  String get addQazaCombinationNote =>
      'ہر تاریخ اور نماز کا جوڑ ایک الگ باقی ریکارڈ بنتا ہے۔ پہلے سے موجود جوڑ خود بخود چھوڑ دیے جاتے ہیں۔';

  @override
  String get addQazaSelectionLabel => 'انتخاب';

  @override
  String get addQazaDatesLabel => 'تاریخیں';

  @override
  String get addQazaDateCountLabel => 'تاریخوں کی تعداد';

  @override
  String get addQazaDateRangeLabel => 'تاریخوں کا دورانیہ';

  @override
  String get addQazaCombinationCountLabel => 'مجموعے';

  @override
  String get addQazaPrayersLabel => 'نمازیں';

  @override
  String get addQazaPrayersPerDateLabel => 'فی تاریخ نمازیں';

  @override
  String get addQazaExistingLabel => 'پہلے سے موجود جوڑ';

  @override
  String get addQazaNewRecordsLabel => 'نئے ریکارڈ';

  @override
  String get addQazaNewLabel => 'نیا';

  @override
  String get addQazaAlreadyAddedLabel => 'پہلے سے شامل';

  @override
  String get addQazaUnavailableLabel => 'دستیاب نہیں';

  @override
  String get addQazaTimeBlocked => 'نماز کے وقت کے اختتام کے بعد دستیاب ہوگا۔';

  @override
  String get addQazaCancelledTitle => 'قضا شامل کرنا منسوخ ہوا';

  @override
  String get addQazaCancelledMessage =>
      'اضافہ منسوخ کر دیا گیا۔ جو ریکارڈ پہلے ہی محفوظ ہو چکے ہیں وہ برقرار ہیں';

  @override
  String get addQazaNewQazaLabel => 'نئے قضا ریکارڈ';

  @override
  String get addQazaInProgress => 'قضا شامل ہو رہی ہے...';

  @override
  String get qazaImportAdded => 'شامل';

  @override
  String get qazaImportSkipped => 'چھوڑے گئے';

  @override
  String get addQazaCreatedTitle => 'قضا ریکارڈ بن گئے';

  @override
  String addQazaSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count دن منتخب • آپ کی کون سی نمازیں چھوٹیں؟',
      one: '1 دن منتخب • آپ کی کون سی نمازیں چھوٹیں؟',
    );
    return '$_temp0';
  }

  @override
  String qazaHistorySelectedDates(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count منتخب تاریخیں',
      one: '1 منتخب تاریخ',
    );
    return '$_temp0';
  }

  @override
  String qazaHistorySelectionScope(int prayers, int days) {
    return '$prayers نمازیں · $days دن';
  }

  @override
  String qazaHistoryProgressPercentage(int percent) {
    return '$percent%';
  }

  @override
  String qazaHistoryTrackedRecords(int count) {
    return '$count زیرِ نگرانی ریکارڈ';
  }

  @override
  String qazaHistoryAdded(String date) {
    return '$date کو شامل کیا گیا';
  }

  @override
  String get qazaHistoryShowAllDates => 'تمام تاریخیں دکھائیں';

  @override
  String get qazaHistoryHideDates => 'تاریخیں چھپائیں';

  @override
  String get qazaHistoryDeletedStatus => 'حذف شدہ';

  @override
  String get qazaHistoryNoDates => 'کوئی تاریخ نہیں';

  @override
  String addQazaDateCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count تاریخیں',
      one: '1 تاریخ',
    );
    return '$_temp0';
  }

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
  String addQazaUnavailablePrayer(String rakats) {
    return '$rakats • ہر منتخب تاریخ پر پہلے سے درج، ادا شدہ، یا نماز کا وقت ابھی ختم نہیں ہوا';
  }

  @override
  String get commonNone => 'کوئی نہیں';

  @override
  String get completeTitle => 'قضا ادا کریں';

  @override
  String get completeHeading => 'سب سے پرانا باقی ریکارڈ مکمل کریں';

  @override
  String get completeIntro =>
      'ایک وقت میں ایک ریکارڈ مکمل کریں۔ کامیابی کے بعد اگلا پرانا ریکارڈ فوراً دکھایا جاتا ہے۔';

  @override
  String get completeLoading => 'سب سے پرانا باقی ریکارڈ لوڈ ہو رہا ہے…';

  @override
  String get completeLoadError => 'آپ کا قضا ریکارڈ لوڈ نہیں ہو سکا۔';

  @override
  String get completeNoPendingTitle => 'اس نماز کی کوئی قضا باقی نہیں۔';

  @override
  String get completeNoPendingMessage =>
      'کوئی اور نماز منتخب کریں یا پہلے قضا ریکارڈ شامل کریں۔';

  @override
  String get completeOldestSubtitle => 'تازہ ترین باقی ریکارڈ';

  @override
  String get completeOriginalDate => 'اصل چھوٹنے کی تاریخ';

  @override
  String get completeTimestampNote => 'ادائیگی کا وقت الگ محفوظ کیا جاتا ہے۔';

  @override
  String get completeAction => 'تازہ ترین قضا ادا کریں';

  @override
  String get completeInProgress => 'مکمل ہو رہا ہے...';

  @override
  String get completeFailed => 'قضا مکمل نہیں ہو سکی۔ دوبارہ کوشش کریں۔';

  @override
  String completePrayerQaza(String prayer) {
    return '$prayer کی قضا';
  }

  @override
  String completeSuccess(String prayer) {
    return '$prayer کی قضا کامیابی سے مکمل ہوئی۔';
  }

  @override
  String completeSuccessNext(String prayer) {
    return '$prayer کی قضا مکمل ہوئی • اگلا پرانا ریکارڈ تیار ہے۔';
  }

  @override
  String get knowledgeBaseTitle => 'نماز اور قضا کی رہنمائی';

  @override
  String get knowledgeBaseSearchHint =>
      'نماز کے مسائل اور غلط فہمیاں تلاش کریں';

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
  String get knowledgeBaseEmptyTitle => 'رہنمائی کا کوئی مضمون نہیں ملا';

  @override
  String get knowledgeBaseEmptyMessage =>
      'کوئی اور لفظ تلاش کریں یا دوسرا موضوع منتخب کریں۔';

  @override
  String get knowledgeBaseLoadError => 'نماز کی رہنمائی لوڈ نہیں ہو سکی۔';

  @override
  String get knowledgeBaseLanguage => 'رہنمائی کے مضامین کی زبان';

  @override
  String get knowledgeArticleTitle => 'مضمون';

  @override
  String get knowledgeArticleReferences => 'حوالہ جات';

  @override
  String get knowledgeArticleRelated => 'متعلقہ مضامین';

  @override
  String get knowledgeArticleNotFound => 'مضمون نہیں ملا۔';

  @override
  String get settingsAccountSection => 'اکاؤنٹ';

  @override
  String get settingsAccountSubtitle =>
      'اپنے سائن اِن اور اکاؤنٹ کی تفصیلات سنبھالیں۔';

  @override
  String get settingsGoogleSignIn => 'گوگل سائن اِن';

  @override
  String get settingsKnowledgeBaseSubtitle =>
      'نماز کے مسائل اور عام غلط فہمیاں پڑھیں۔';

  @override
  String get settingsDataSection => 'ڈیٹا و اسٹوریج';

  @override
  String get settingsDataSubtitle =>
      'اپنے قضا ڈیٹا کو سنک، بیک اپ، برآمد اور درآمد کریں۔';

  @override
  String get settingsDataCloud => 'ڈیٹا و کلاؤڈ';

  @override
  String get settingsDataCloudSubtitle => 'سنک، برآمد اور درآمد کی حالت';

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
  String get authContinueAsGuest => 'مہمان کے طور پر جاری رکھیں';

  @override
  String get authGuestNote =>
      'اپنی قضا پیش رفت کو اپنے اکاؤنٹ کے ساتھ محفوظ رکھنے کے لیے بعد میں گوگل سے سائن اِن کر سکتے ہیں۔';

  @override
  String get backupPromptTitle => 'اپنی پیش رفت محفوظ رکھیں';

  @override
  String get backupPromptBody =>
      'اپنی قضا پیش رفت کو اپنے اکاؤنٹ کے ساتھ محفوظ رکھنے کے لیے گوگل سے سائن اِن کریں۔';

  @override
  String get backupPromptConfirm => 'گوگل سے جاری رکھیں';

  @override
  String get backupPromptDismiss => 'ابھی نہیں';

  @override
  String get settingsBackupSignIn => 'بیک اپ / سائن ان';

  @override
  String get settingsBackupSignInSubtitle =>
      'آپ مہمان کے طور پر ایپ استعمال کر رہے ہیں۔ قضا کا بیک اپ لینے کے لیے سائن ان کریں۔';

  @override
  String get backupSignInFailed =>
      'سائن ان ناکام رہا۔ آپ کی پیش رفت اب بھی اس ڈیوائس پر محفوظ ہے۔';

  @override
  String get backupSignInCancelled =>
      'سائن ان منسوخ ہو گیا۔ آپ کی پیش رفت اب بھی اس ڈیوائس پر محفوظ ہے۔';

  @override
  String backupSignInFailedReason(String reason) {
    return 'سائن ان ناکام رہا: $reason آپ کی پیش رفت اب بھی اس ڈیوائس پر محفوظ ہے۔';
  }

  @override
  String backupMigrationDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'سائن اِن ہو گیا۔ آپ کی قضا پیش رفت اب آپ کے اکاؤنٹ سے منسلک ہے۔',
      one: 'سائن اِن ہو گیا۔ آپ کی قضا پیش رفت اب آپ کے اکاؤنٹ سے منسلک ہے۔',
      zero: 'سائن اِن ہو گیا۔ آپ کی قضا پیش رفت اب آپ کے اکاؤنٹ سے منسلک ہے۔',
    );
    return '$_temp0';
  }

  @override
  String get settingsAboutSection => 'تعارف';

  @override
  String get settingsAboutSubtitle => 'ایپ کی معلومات اور ورژن کی تفصیل۔';

  @override
  String settingsAboutRowSubtitle(String version) {
    return 'قضا نماز • ورژن $version';
  }

  @override
  String get settingsAppDescription => 'اسلامی نماز قضا ٹریکر';

  @override
  String get cloudSyncTitle => 'کلاؤڈ سنک';

  @override
  String get cloudSyncNow => 'ابھی سنک کریں';

  @override
  String get cloudPendingChanges => 'زیرِ التوا تبدیلیاں';

  @override
  String get cloudLastSynced => 'آخری سنک';

  @override
  String get cloudExportImportSubtitle =>
      'صارف کے اختیار میں JSON بیک اپ اور محفوظ بحالی۔ ان اقدامات سے کلاؤڈ ڈیٹا حذف نہیں ہوتا۔';

  @override
  String get cloudInactive => 'اس بلڈ میں آف لائن اسٹوریج فعال نہیں ہے۔';

  @override
  String get cloudBootstrapping =>
      'اس ڈیوائس پر آپ کے قضا ریکارڈ ترتیب دیے جا رہے ہیں…';

  @override
  String get cloudHydrating =>
      'آپ کے محفوظ قضا ریکارڈ اس ڈیوائس پر بحال کیے جا رہے ہیں…';

  @override
  String get cloudSynced => 'آپ کے تمام قضا ریکارڈ کلاؤڈ میں محفوظ ہیں۔';

  @override
  String get cloudSyncing => 'آپ کا کھاتہ سنک ہو رہا ہے…';

  @override
  String get cloudOffline =>
      'آف لائن — ریکارڈ اس ڈیوائس پر محفوظ ہیں اور خود بخود سنک ہو جائیں گے۔';

  @override
  String cloudPendingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count تبدیلیاں سنک کی منتظر ہیں۔',
      one: '1 تبدیلی سنک کی منتظر ہے۔',
    );
    return '$_temp0';
  }

  @override
  String get cloudSyncProblem =>
      'سنک میں مسئلہ — آپ کا ڈیٹا اس ڈیوائس پر محفوظ ہے۔';

  @override
  String get cloudQazaCount => 'قضا ریکارڈز کی تعداد';

  @override
  String cloudQazaCountValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count قضا ریکارڈز',
      one: '1 قضا ریکارڈ',
      zero: 'کوئی قضا ریکارڈ نہیں',
    );
    return '$_temp0';
  }

  @override
  String get cloudBackupStatus => 'کلاؤڈ بیک اپ';

  @override
  String get cloudBackupDeleted =>
      'کلاؤڈ نقل حذف ہو گئی؛ لوکل ریکارڈز برقرار ہیں۔';

  @override
  String get cloudLocalVsCloudTitle => 'لوکل اور کلاؤڈ ڈیٹا';

  @override
  String get cloudLocalVsCloudBody =>
      'آپ کے قضا ریکارڈ آف لائن استعمال کے لیے اس ڈیوائس پر محفوظ رہتے ہیں۔ سائن اِن ہونے پر تبدیلیاں آپ کے نجی کلاؤڈ اکاؤنٹ سے سنک ہو سکتی ہیں۔ برآمد ایک لوکل بیک اپ ہے؛ کلاؤڈ ڈیٹا حذف کرنے سے لوکل ریکارڈز حذف نہیں ہوتے۔';

  @override
  String get cloudDeleteTitle => 'کلاؤڈ ڈیٹا حذف کریں';

  @override
  String get cloudDeleteBody =>
      'یہ آپ کے کلاؤڈ اکاؤنٹ سے قضا ریکارڈز مستقل طور پر حذف کر دے گا۔ اس ڈیوائس کے لوکل ریکارڈز برقرار رہیں گے۔ یہ عمل واپس نہیں ہو سکتا۔ اگر بیک اپ درکار ہو سکتا ہے تو پہلے ڈیٹا برآمد کر لیں۔';

  @override
  String get cloudDeleteAcknowledge =>
      'میں سمجھتا/سمجھتی ہوں کہ کلاؤڈ نقل مستقل طور پر حذف ہو جائے گی۔';

  @override
  String get cloudDeleteAction => 'کلاؤڈ ڈیٹا حذف کریں';

  @override
  String get cloudDeleteDone =>
      'کلاؤڈ قضا ڈیٹا حذف ہو گیا۔ اس ڈیوائس کے لوکل ریکارڈز برقرار ہیں۔';

  @override
  String get cloudDeleteFailed =>
      'کلاؤڈ ڈیٹا حذف نہیں ہو سکا۔ آپ کے لوکل ریکارڈز محفوظ ہیں۔';

  @override
  String get cloudDeleteSignInRequired =>
      'کلاؤڈ ڈیٹا سنبھالنے کے لیے سائن اِن کریں۔';

  @override
  String get accountGoogle => 'گوگل اکاؤنٹ';

  @override
  String get accountCloudBackup => 'کلاؤڈ بیک اپ';

  @override
  String get accountAutomatic => 'خودکار';

  @override
  String get accountBackupPaused => 'بیک اپ روک دیا گیا ہے';

  @override
  String get accountEnableBackup => 'بیک اپ فعال کریں';

  @override
  String get accountDisconnect => 'گوگل منقطع کریں';

  @override
  String get accountDeleteCloudData => 'کلاؤڈ ڈیٹا حذف کریں';

  @override
  String get accountDeleteCloudDataMessage =>
      'آپ کی کلاؤڈ نقل مستقل طور پر حذف ہو جائے گی۔ اس ڈیوائس پر آپ کا قضا ڈیٹا برقرار رہے گا۔';

  @override
  String get accountDeleteCloudDataAcknowledge =>
      'میں سمجھتا/سمجھتی ہوں کہ کلاؤڈ نقل مستقل طور پر حذف ہو جائے گی۔';

  @override
  String get accountCancel => 'منسوخ';

  @override
  String get accountContinue => 'جاری رکھیں';

  @override
  String get accountGuestTitle => 'یہ ڈیوائس';

  @override
  String get accountGuestLocalDataSubtitle =>
      'آپ کا ڈیٹا اس ڈیوائس پر محفوظ ہے';

  @override
  String get accountNotConnectedGoogle => 'گوگل سے منسلک نہیں';

  @override
  String get accountKeepProgressSafe => 'اپنی پیش رفت محفوظ رکھیں';

  @override
  String get accountKeepProgressSafeDescription =>
      'اپنی قضا پیش رفت کو مختلف ڈیوائسز پر بیک اپ اور بحال کرنے کے لیے گوگل اکاؤنٹ منسلک کریں۔';

  @override
  String get accountGuestContinueMessage =>
      'آپ کی مقامی پیش رفت اسی ڈیوائس پر محفوظ رہتی ہے۔';

  @override
  String get accountBackupSection => 'بیک اپ';

  @override
  String get accountBackupAutomaticDescription =>
      'اپنی قضا پیش رفت کا خودکار بیک اپ لیں';

  @override
  String get accountAccountActions => 'اکاؤنٹ کے اقدامات';

  @override
  String get accountSignOutDescription =>
      'اپنے گوگل اکاؤنٹ سے سائن آؤٹ کریں۔ آپ بعد میں دوبارہ سائن اِن کر سکتے ہیں۔';

  @override
  String get accountDisconnectDescription =>
      'قضا نماز سے گوگل کا کنکشن ہٹائیں اور مہمان موڈ پر واپس جائیں۔';

  @override
  String get accountDangerZone => 'خطرناک اقدامات';

  @override
  String get settingsAccountGuestSubtitle => 'مقامی • صرف یہ ڈیوائس';

  @override
  String get settingsAccountGoogleSubtitle => 'گوگل کے ساتھ سائن اِن';

  @override
  String get accountConnectFailed =>
      'گوگل کنکشن مکمل نہیں ہو سکا۔ آپ کا لوکل ڈیٹا محفوظ ہے۔';

  @override
  String get accountCloudDeleted =>
      'کلاؤڈ ڈیٹا حذف ہو گیا۔ آپ کا لوکل قضا ڈیٹا اس ڈیوائس پر برقرار ہے۔';

  @override
  String get settingsTitle => 'ترتیبات';

  @override
  String get settingsPreferences => 'ترجیحات';

  @override
  String get settingsPreferencesSubtitle => 'زبان اور ظاہری شکل کی ترتیبات۔';

  @override
  String get settingsAppearance => 'ظاہری شکل';

  @override
  String get settingsAppearanceSubtitle =>
      'منتخب کریں کہ ایپ اس ڈیوائس پر کیسی نظر آئے۔';

  @override
  String get settingsThemeSystem => 'سسٹم';

  @override
  String get settingsThemeLight => 'روشن';

  @override
  String get settingsThemeDark => 'تاریک';

  @override
  String get settingsLanguage => 'زبان';

  @override
  String get settingsLanguageSubtitle =>
      'ایپ میں استعمال ہونے والی زبان منتخب کریں۔';

  @override
  String get settingsLanguageNote =>
      'نماز کے نام اور ہجری تاریخیں منتخب زبان کے مطابق ہوں گی۔ اردو دائیں سے بائیں لکھی جاتی ہے۔';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageUrdu => 'اردو';

  @override
  String get homeTodayProgressHeader => 'آج کی پیش رفت';

  @override
  String get homeNextQazaCurrentPrayer => 'اگلی قضا (موجودہ نماز)';

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
  String get homeDetailedStatisticsSubtitle => 'مجموعی اور نماز وار تکمیل';

  @override
  String get homeQazaActivity => 'قضا سرگرمی';

  @override
  String get homeProgressHistory => 'پیش رفت کی تاریخ';

  @override
  String get homeRangeWeekly => 'ہفتہ وار';

  @override
  String get homeRangeMonthly => 'ماہانہ';

  @override
  String get homeRangeYearly => 'سالانہ';

  @override
  String get homeWeeklyTargetLabel => 'ہفتہ وار ہدف';

  @override
  String get homeMonthlyTarget => 'ماہانہ ہدف';

  @override
  String get homeProgressLabel => 'پیش رفت';

  @override
  String get homeActiveDays => 'فعال دن';

  @override
  String get homeActiveMonths => 'فعال مہینے';

  @override
  String get homeGoalReached => 'ہدف مکمل';

  @override
  String get homeRemaining => 'باقی';

  @override
  String get homeActual => 'مکمل شدہ';

  @override
  String get homeNoActivity => 'اس مدت میں کوئی قضا مکمل نہیں ہوئی۔';

  @override
  String get homeSelectDay => 'تفصیلات دیکھنے کے لیے کسی دن کو منتخب کریں۔';

  @override
  String get homePreviousWeek => 'پچھلا ہفتہ';

  @override
  String get homeNextWeek => 'اگلا ہفتہ';

  @override
  String get homePreviousMonth => 'پچھلا مہینہ';

  @override
  String get homeNextMonth => 'اگلا مہینہ';

  @override
  String get homePreviousYear => 'پچھلا سال';

  @override
  String get homeNextYear => 'اگلا سال';

  @override
  String get homeFutureDay => 'آنے والا دن';

  @override
  String get homeDailyGoalsTitle => 'آپ کے روزانہ کے اہداف';

  @override
  String get homeLastSevenDays => 'گزشتہ 7 دن';

  @override
  String get homeGoalsAchieved => 'ہدف حاصل کیا';

  @override
  String get homeWeeklyTarget => 'آپ کا ہفتہ وار ہدف';

  @override
  String homeWeeklyTargetProgress(int completed, int target) {
    return '$target میں سے $completed';
  }

  @override
  String get homeDayActivityDetails => 'دن کی تفصیلات';

  @override
  String get homeTodayDate => 'آج';

  @override
  String homeCurrentPrayerLabel(String prayer) {
    return 'موجودہ نماز: $prayer';
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
  String get profileDobDay => 'دن';

  @override
  String get profileDobMonth => 'مہینہ';

  @override
  String get profileDobYear => 'سال';

  @override
  String get profileSelectDate => 'تاریخ منتخب کریں';

  @override
  String get profileSelectDobHelp => 'اپنی تاریخ پیدائش منتخب کریں';

  @override
  String get profileHijriHint =>
      'گریگورین تاریخ منتخب کرنے کے بعد ہجری تاریخ بھی دکھائی جائے گی۔';

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
  String get profileEdit => 'پروفائل میں ترمیم کریں';

  @override
  String profileAgeYears(int count) {
    return '$count سال';
  }

  @override
  String get profileDiscardChangesTitle => 'غیر محفوظ تبدیلیاں مسترد کریں؟';

  @override
  String get profileDiscardChangesMessage =>
      'آپ کی تبدیلیاں محفوظ نہیں ہوئیں۔ کیا آپ انہیں مسترد کرکے ترمیم سے باہر نکلنا چاہتے ہیں؟';

  @override
  String get profileDiscardChangesAction => 'تبدیلیاں مسترد کریں';

  @override
  String get profileQazaAssumptionsChanged =>
      'پروفائل میں کی جانے والی تبدیلیاں';

  @override
  String get profileQazaAssumptionsHint =>
      'قضا پلان لاگو کرنے سے پہلے پچھلی اور نئی قدروں کا جائزہ لیں۔';

  @override
  String get profileQazaPlanChangedTitle => 'قضا پلان اپ ڈیٹ ہوگا';

  @override
  String get profileQazaPlanSummary =>
      'آپ کی پروفائل میں تبدیلی سے حساب شدہ قضا پلان بدلتا ہے۔';

  @override
  String get profileQazaReviewError =>
      'قضا پلان کا جائزہ تیار نہیں ہو سکا۔ دوبارہ کوشش کریں۔';

  @override
  String get profileQazaApplying => 'قضا پلان لاگو ہو رہا ہے…';

  @override
  String get profileQazaImpact => 'اثر';

  @override
  String profileQazaCount(String count) {
    return '$count قضا';
  }

  @override
  String get profileQazaPreviousTotal => 'پچھلا پلان';

  @override
  String get profileQazaNewTotal => 'نیا پلان';

  @override
  String get profileQazaCompletedInPlan => 'نئے پلان میں مکمل شدہ';

  @override
  String get profileQazaToAdd => 'نئی قضا جوڑی جائے گی';

  @override
  String get profileQazaRestored => 'پہلے ہٹائی گئی قضا بحال کی جائے گی';

  @override
  String get profileQazaUpdatedKeptExisting =>
      'پروفائل اپ ڈیٹ ہوگئی۔ موجودہ قضا ریکارڈ برقرار رہے۔';

  @override
  String get profileQazaNoLongerRequired =>
      'وہ زیرِ التوا قضا جو اب درکار نہیں';

  @override
  String get profileQazaKeepExisting => 'موجودہ قضا ریکارڈ برقرار رکھیں';

  @override
  String get profileQazaApply => 'قضا پلان لاگو کریں';

  @override
  String get profileQazaCompletedProtected =>
      'مکمل شدہ اور دستی طور پر شامل کی گئی قضا حذف نہیں ہوگی۔';

  @override
  String get profileQazaUpdated => 'پروفائل اور قضا پلان اپ ڈیٹ ہوگئے۔';

  @override
  String profileQazaUpdatedCounts(int added, int removed) {
    return 'پروفائل اور قضا پلان اپ ڈیٹ ہوگئے۔ شامل کی گئی قضا: $added؛ ہٹائی گئی قضا: $removed۔';
  }

  @override
  String get profileQazaUpdatedNoChange =>
      'پروفائل اپ ڈیٹ ہوگئی۔ قضا پلان میں کوئی تبدیلی نہیں ہوئی۔';

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

  @override
  String get navPrayerTime => 'نماز کے اوقات';

  @override
  String get prayerTimeTitle => 'نماز کے اوقات';

  @override
  String get prayerTimeLocation => 'مقام';

  @override
  String get prayerTimeUseCurrentLocation => 'موجودہ مقام استعمال کریں';

  @override
  String get prayerTimeSelectCity => 'شہر منتخب کریں';

  @override
  String get prayerTimeSelectCountry => 'ملک منتخب کریں';

  @override
  String get prayerTimeSearchCity => 'شہر تلاش کریں';

  @override
  String get prayerTimeCurrentLocation => 'موجودہ مقام';

  @override
  String get prayerTimeSavedLocation => 'محفوظ مقام';

  @override
  String get prayerTimeToday => 'آج';

  @override
  String get prayerTimeRestrictedTimes => 'محدود اوقات';

  @override
  String get prayerTimeActive => 'فعال';

  @override
  String get prayerTimeLocationUnavailable => 'مقام دستیاب نہیں';

  @override
  String get prayerTimeLocationPermission =>
      'موجودہ مقام استعمال کرنے کے لیے مقام کی اجازت درکار ہے۔';

  @override
  String get prayerTimeLocationServiceRequired =>
      'موجودہ مقام استعمال کرنے کے لیے لوکیشن سروسز کو آن کرنا ضروری ہے۔';

  @override
  String get prayerTimeEnableLocation => 'مقام آن کریں';

  @override
  String get prayerTimeSelectLocation => 'اپنا مقام منتخب کریں';

  @override
  String get prayerTimeCalculationMethod => 'حساب کا طریقہ';

  @override
  String get prayerTimeAsrMethod => 'عصر کا طریقہ';

  @override
  String get prayerTimeHighLatitudeRule => 'بلند عرض بلد کا اصول';

  @override
  String get prayerTimeAdjustments => 'تعدیلات';

  @override
  String get prayerTime12Hour => '12 گھنٹے';

  @override
  String get prayerTime24Hour => '24 گھنٹے';

  @override
  String get prayerTimeStandard => 'معیاری';

  @override
  String get prayerTimeHanafi => 'حنفی';

  @override
  String get prayerTimeAutomatic => 'خودکار';

  @override
  String get prayerTimeMiddleOfTheNight => 'نصف شب';

  @override
  String get prayerTimeSeventhOfTheNight => 'رات کا ساتواں حصہ';

  @override
  String get prayerTimeTwilightAngle => 'شفق کا زاویہ';

  @override
  String get prayerTimeCustom => 'حسب ضرورت';

  @override
  String get prayerTimeFajrAngle => 'فجر کا زاویہ';

  @override
  String get prayerTimeIshaAngle => 'عشاء کا زاویہ';

  @override
  String get prayerTimeSave => 'محفوظ کریں';

  @override
  String get prayerTimeCountry => 'ملک';

  @override
  String get prayerTimeCity => 'شہر';

  @override
  String get prayerTimeNoCities => 'کوئی مطابقت رکھنے والا شہر نہیں';

  @override
  String get prayerTimeSettings => 'نماز کے اوقات کی ترتیبات';

  @override
  String get prayerTimeLocationData => 'مقام کا ڈیٹا';

  @override
  String get settingsLicensesSoftwareTitle => 'اوپن سورس سافٹ ویئر کے لائسنس';

  @override
  String get settingsLicensesSoftwareSubtitle =>
      'Flutter پیکیجز، مقامی لائبریریاں اور شامل فونٹس۔';

  @override
  String get settingsLicensesGeoNamesTitle => 'GeoNames شہری ڈیٹا';

  @override
  String get settingsLicensesGeoNamesSubtitle =>
      'آف لائن شہروں اور مقامات کے ڈیٹا کی نسبت۔';

  @override
  String get prayerTimeLocationDataAttribution =>
      'شہری ڈیٹا © GeoNames، CC BY 4.0 کے تحت لائسنس یافتہ ہے۔';

  @override
  String get prayerTimeUpdated => 'اپ ڈیٹ';

  @override
  String get prayerTimeNoSchedule => 'نماز کے اوقات ابھی ترتیب نہیں دیے گئے۔';

  @override
  String get prayerTimeSetupTitle => 'نماز کے اوقات ترتیب دیں';

  @override
  String get prayerTimeSetupBody =>
      'اپنا موجودہ مقام استعمال کریں یا ملک اور شہر منتخب کریں۔ مقام محفوظ ہونے کے بعد یہ آف لائن کام کرے گا۔';

  @override
  String get prayerTimeRefresh => 'مقام تازہ کریں';

  @override
  String prayerTimeEndsIn(String duration) {
    return 'اختتام میں $duration';
  }

  @override
  String prayerTimeRemaining(String duration) {
    return 'باقی وقت $duration';
  }

  @override
  String prayerTimeStartsIn(String duration) {
    return 'شروع ہونے میں $duration';
  }

  @override
  String prayerTimeNextRestricted(String name) {
    return 'اگلا: $name';
  }

  @override
  String prayerTimeUsingSavedLocation(String location) {
    return 'آپ کا محفوظ مقام استعمال ہو رہا ہے: $location';
  }

  @override
  String get prayerTimeAngleHint => 'درجات میں درج کریں۔';

  @override
  String get prayerTimeAdjustmentMinutes => 'منٹ';

  @override
  String get prayerTimeSunrise => 'طلوعِ آفتاب';

  @override
  String get prayerTimeZawal => 'زوال';

  @override
  String get prayerTimeSunset => 'غروبِ آفتاب';

  @override
  String get prayerTimeFajr => 'فجر';

  @override
  String get prayerTimeDhuhr => 'ظہر';

  @override
  String get prayerTimeAsr => 'عصر';

  @override
  String get prayerTimeMaghrib => 'مغرب';

  @override
  String get prayerTimeIsha => 'عشاء';

  @override
  String get qiblaTitle => 'قبلہ';

  @override
  String get qiblaDirection => 'قبلہ کی سمت';

  @override
  String get qiblaBearing => 'قبلہ کا زاویہ';

  @override
  String get qiblaFromTrueNorth => 'حقیقی شمال سے';

  @override
  String get qiblaUnavailable => 'قبلہ دستیاب نہیں';

  @override
  String get qiblaLocationRequired =>
      'قبلہ معلوم کرنے کے لیے مقام منتخب یا محفوظ کریں۔';

  @override
  String get qiblaCompassBody => 'فون گھمائیں؛ تیر قبلہ کی طرف رہنمائی کرے گا۔';

  @override
  String get qiblaSensorUnavailableBody =>
      'اس آلے میں کمپاس سینسر دستیاب نہیں، اس لیے جامد قبلہ سمت دکھائی جا رہی ہے۔';

  @override
  String get qiblaHeadingUnavailable =>
      'کمپاس کی سمت عارضی طور پر دستیاب نہیں۔';

  @override
  String get qiblaTurnToDirection => 'فون کو اس سمت گھمائیں۔';

  @override
  String qiblaCompassAccuracy(String degrees) {
    return 'کمپاس کی درستگی ±$degrees°';
  }

  @override
  String get qiblaCalibrationHint =>
      'کمپاس کی درستگی کم ہے۔ فون کو 8 کی شکل میں حرکت دے کر دوبارہ کیلیبریٹ کریں۔';

  @override
  String get accountAutomaticBackup => 'خودکار بیک اپ';

  @override
  String get accountBackupStatusChecking => 'بیک اپ کی حالت دیکھی جا رہی ہے…';

  @override
  String get accountBackupStatusDisabled => 'خودکار بیک اپ بند ہے';

  @override
  String accountBackupStatusBackedUp(Object timestamp) {
    return '✓ بیک اپ مکمل · $timestamp';
  }

  @override
  String get accountBackupStatusBackingUp =>
      'آپ کی پیش رفت کا بیک اپ لیا جا رہا ہے…';

  @override
  String get accountBackupStatusPending => 'بیک اپ زیرِ التوا ہے';

  @override
  String get accountBackupStatusWaitingConnection => 'کنکشن کا انتظار ہے';

  @override
  String get accountBackupStatusComplete => 'بیک اپ مکمل ہو گیا';

  @override
  String accountBackupStatusCompletedAt(Object timestamp) {
    return '$timestamp';
  }

  @override
  String get accountBackupStatusWaitingConnectionMessage =>
      'آپ کا قضا ڈیٹا اس ڈیوائس پر محفوظ ہے۔';

  @override
  String get accountBackupStatusFailedTitle => 'بیک اپ مکمل نہیں ہو سکا';

  @override
  String get accountBackupStatusFailedMessage =>
      'آپ کا قضا ڈیٹا اس ڈیوائس پر محفوظ ہے۔';

  @override
  String get accountBackupStatusAuthRequired =>
      'گوگل سیشن بحال کرنے کی ضرورت ہے۔';

  @override
  String get accountBackupStatusSecurityRejected =>
      'سیکیورٹی تصدیق نے کلاؤڈ رسائی مسترد کر دی۔';

  @override
  String get accountBackupStatusNetwork =>
      'انٹرنیٹ کنکشن موجود نہیں۔ کنکشن بحال ہونے پر بیک اپ دوبارہ جاری ہوگا۔';

  @override
  String get accountBackupStatusCloudStateInvalid =>
      'کلاؤڈ بیک اپ کی حالت بدل گئی ہے۔ دوبارہ کوشش کریں۔';

  @override
  String get accountBackupStatusFailedAutomaticRetry =>
      'ہم خودکار طور پر دوبارہ کوشش کریں گے۔';

  @override
  String get accountBackupStatusRetry => 'دوبارہ کوشش کریں';

  @override
  String get accountBackupStatusFailed =>
      'بیک اپ مکمل نہیں ہو سکا۔ ہم خودکار طور پر دوبارہ کوشش کریں گے۔';

  @override
  String get startupProfileLoadErrorTitle => 'مقامی پروفائل لوڈ نہیں ہو سکا';

  @override
  String get startupProfileLoadErrorMessage =>
      'آپ کی مقامی اسٹوریج کو محفوظ طریقے سے پڑھا نہیں جا سکا۔ آپ کا موجودہ قضا ڈیٹا تبدیل نہیں کیا گیا۔ دوبارہ کوشش کریں۔';

  @override
  String get qazaHistoryTitle => 'قضا کی تاریخ';

  @override
  String get qazaHistoryRecentAdditions => 'حالیہ اضافے';

  @override
  String get qazaHistoryRecentlyDeleted => 'حال ہی میں حذف شدہ';

  @override
  String get qazaHistoryNoAdditions => 'ابھی کوئی قضا اضافہ موجود نہیں۔';

  @override
  String get qazaHistoryNoRecentlyDeleted =>
      'حال ہی میں حذف شدہ کوئی قضا نہیں۔';

  @override
  String get qazaHistoryLoadMore => 'مزید لوڈ کریں';

  @override
  String get qazaHistoryOriginalDateUnavailable => 'اصل تاریخ دستیاب نہیں';

  @override
  String get qazaHistoryDeletedQaza => 'حذف شدہ قضا';

  @override
  String qazaHistoryDeletedQazaCount(int count) {
    return '$count قضا حذف ہوئیں';
  }

  @override
  String get qazaHistoryRestore => 'بحال کریں';

  @override
  String qazaHistoryRestoreSuccess(int count) {
    return '$count قضا بحال ہوئیں';
  }

  @override
  String qazaHistoryRestoreConflict(int restored, int skipped) {
    return '$restored بحال ہوئیں، $skipped چھوڑ دی گئیں';
  }

  @override
  String get qazaAdditionTitle => 'قضا اضافہ';

  @override
  String get qazaAdditionNotFound => 'یہ قضا اضافہ نہیں مل سکا۔';

  @override
  String qazaAdditionRecordsCount(int count) {
    return '$count ریکارڈز';
  }

  @override
  String get qazaAdditionNoPrayers => 'کوئی نماز نہیں';

  @override
  String get qazaAdditionViewRecords => 'ریکارڈز دیکھیں';

  @override
  String get qazaAdditionMoreActions => 'مزید اقدامات';

  @override
  String get qazaAdditionEdit => 'اضافے میں ترمیم';

  @override
  String get qazaAdditionDelete => 'اضافہ حذف کریں';

  @override
  String get qazaAdditionDeleteConfirmTitle => 'یہ قضا اضافہ حذف کریں؟';

  @override
  String get qazaAdditionDeleteConfirmMessage =>
      'صرف غیر تبدیل شدہ زیرِ التوا ریکارڈز حذف ہوں گے۔ مکمل یا تبدیل شدہ ریکارڈز محفوظ رہیں گے۔';

  @override
  String get qazaAdditionDeletedNothing =>
      'حذف کرنے کے لیے کوئی اہل ریکارڈ نہیں ملا۔ محفوظ ریکارڈز برقرار ہیں۔';

  @override
  String qazaAdditionDeletedCount(int count) {
    return '$count قضا حذف ہوئیں';
  }

  @override
  String qazaAdditionRestoredCount(int count) {
    return '$count قضا بحال ہوئیں';
  }

  @override
  String get qazaTrackerHistoryTooltip => 'قضا کی تاریخ';

  @override
  String get qazaTrackerAdditionProgress => 'قضا اضافے کی پیش رفت';

  @override
  String get qazaTrackerSelectionHint =>
      'منتخب یا غیر منتخب کرنے کے لیے ٹچ کریں۔';

  @override
  String get qazaTrackerSwipeHint =>
      'تفصیل دیکھنے کے لیے ٹیپ کریں۔ مکمل کرنے کے لیے دائیں یا بائیں سوائپ کریں۔ منتخب کرنے کے لیے دیر تک دبائیں۔';

  @override
  String get qazaMarkSelectedPendingTitle => 'منتخب قضا کو زیرِ التوا کریں؟';

  @override
  String qazaMarkSelectedPendingMessage(int count) {
    return '$count مکمل قضا دوبارہ زیرِ التوا ہو جائیں گی اور مکمل شدہ شمار نہیں ہوں گی۔';
  }

  @override
  String get qazaMarkAsPending => 'زیرِ التوا کریں';

  @override
  String qazaMarkAsPendingCount(int count) {
    return 'زیرِ التوا کریں ($count)';
  }

  @override
  String get qazaNoCompletedTitle => 'کوئی مکمل قضا نہیں';

  @override
  String get qazaNoCompletedMessage => 'مکمل قضا یہاں دکھائی دیں گی۔';

  @override
  String get qazaReturnedToPending => 'قضا دوبارہ زیرِ التوا ہو گئی۔';

  @override
  String get qazaSelectedPendingNothingChanged =>
      'منتخب قضا میں کوئی تبدیلی نہیں ہوئی۔';

  @override
  String get qazaCorrectionChanged =>
      'یہ قضا درست نہیں کی جا سکی کیونکہ یہ تبدیل ہو گئی ہے۔';

  @override
  String get qazaFilter => 'فلٹر';

  @override
  String get qazaFiltersActive => 'فلٹر فعال ہیں';

  @override
  String get qazaOriginalDateLabel => 'قضا کی تاریخ';

  @override
  String get qazaCompletedDateLabel => 'مکمل ہونے کی تاریخ';

  @override
  String get qazaFilterCompletedDateHelp =>
      'مکمل ہونے کی تاریخ کے مطابق فلٹر کریں';

  @override
  String get qazaUndoCompletions => 'مکمل قضا واپس کریں';

  @override
  String get qazaUndoSelected => 'منتخب واپس کریں';

  @override
  String get qazaUndoAll => 'سب واپس کریں';

  @override
  String qazaUndoQazaCount(int count) {
    return '$count قضا';
  }

  @override
  String get addQazaManageAddition => 'اس اضافے کو منظم کریں';

  @override
  String qazaCompletionSingle(String prayer, String date) {
    return '$prayer کی قضا، $date مکمل ہو گئی۔';
  }

  @override
  String qazaCompletionMultiple(int count) {
    return '$count قضا نمازیں مکمل ہو گئیں۔';
  }

  @override
  String qazaUndoSingle(String prayer, String date) {
    return '$prayer کی قضا، $date دوبارہ باقی میں شامل ہو گئی۔';
  }

  @override
  String qazaUndoMultiple(int count) {
    return '$count قضا نمازیں دوبارہ باقی میں شامل ہو گئی ہیں۔';
  }

  @override
  String get qazaUndoExpired => 'واپس کرنے کا 5 سیکنڈ کا وقت ختم ہو گیا۔';

  @override
  String get qazaUndoStaleBatch =>
      'واپس کرنے کا یہ اختیار اب دستیاب نہیں کیونکہ اس کے بعد ایک نیا Undo عمل ہوا ہے۔';

  @override
  String get qazaUndoTargetChanged =>
      'واپس کرنے کا اختیار دستیاب نہیں کیونکہ قضا ریکارڈ بدل چکا یا حذف ہو چکا ہے۔';

  @override
  String get qazaUndoFailed =>
      'قضا واپس نہیں ہو سکی۔ براہِ کرم دوبارہ کوشش کریں۔';

  @override
  String get qazaMarkAsPendingMessage =>
      'یہ قضا دوبارہ زیرِ التوا ہو جائے گی اور مکمل شدہ شمار نہیں ہوگی۔';

  @override
  String get commonDelete => 'حذف کریں';

  @override
  String qazaRequestedSlots(int count) {
    return '$count مطلوبہ جگہیں';
  }

  @override
  String get qazaAdditionUpdated => 'قضا کا اضافہ اپ ڈیٹ ہو گیا';

  @override
  String qazaSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count منتخب',
      one: '1 منتخب',
    );
    return '$_temp0';
  }

  @override
  String dataImportRestored(int count) {
    return 'بیک اپ کامیابی سے بحال ہو گیا۔ $count قضا ریکارڈ بحال کیے گئے۔';
  }

  @override
  String dataImportRestoreSummary(
      int records, int accounts, int revision, String onboarding) {
    return 'اس بیک اپ میں $records قضا ریکارڈ اور $accounts مقامی اکاؤنٹ ہیں۔\n\nبحال کرنے سے اس ڈیوائس کا موجودہ مقامی ڈیٹا منتخب بیک اپ سے بدل جائے گا۔ آپ کی ڈیوائس شناخت اسی ڈیوائس پر برقرار رہے گی۔\n\nبیک اپ ریویژن: $revision\nآن بورڈنگ: $onboarding';
  }

  @override
  String get dataImportOnboardingComplete => 'مکمل';

  @override
  String get dataImportOnboardingIncomplete => 'مکمل نہیں';

  @override
  String get dataLocalOnlyNote =>
      'صرف مقامی بیک اپ۔ آپ کا قضا ڈیٹا اسی ڈیوائس پر رہتا ہے، جب تک آپ اسے واضح طور پر برآمد نہ کریں۔';

  @override
  String get cloudBackupTitle => 'کلاؤڈ بیک اپ';

  @override
  String get cloudBackupDescription =>
      'اپنی قضا کی پیش رفت کا گوگل ڈرائیو ایپ ڈیٹا میں الگ بیک اپ محفوظ رکھیں۔';

  @override
  String get cloudConnect => 'گوگل سے منسلک کریں';

  @override
  String get cloudDisconnect => 'اکاؤنٹ منقطع کریں';

  @override
  String get cloudConnected => 'منسلک';

  @override
  String get cloudNotConnected =>
      'اپنی پیش رفت کا بیک اپ رکھنے کے لیے گوگل اکاؤنٹ منسلک کریں۔';

  @override
  String get cloudBackupNow => 'ابھی بیک اپ کریں';

  @override
  String get cloudAutomaticBackup => 'خودکار بیک اپ';

  @override
  String get cloudLastBackup => 'آخری کامیاب بیک اپ';

  @override
  String get cloudNeverBackedUp => 'ابھی تک بیک اپ نہیں ہوا';

  @override
  String get cloudBackupSucceeded => 'کلاؤڈ بیک اپ/سنک مکمل ہو گیا۔';

  @override
  String get cloudBackupUpToDate => 'بیک اپ پہلے ہی تازہ ترین ہے۔';

  @override
  String get cloudBackupConflictTitle => 'تبدیلیوں میں فرق ملا';

  @override
  String get cloudBackupConflictMessage =>
      'اس ڈیوائس اور گوگل ڈرائیو پر مختلف پیش رفت موجود ہے۔ منتخب کریں کہ کون سا ڈیٹا رکھنا ہے۔';

  @override
  String get cloudKeepLocal => 'اس ڈیوائس کی پیش رفت رکھیں';

  @override
  String get cloudUseRemote => 'گوگل ڈرائیو سے بحال کریں';

  @override
  String get cloudKeepLocalConfirmTitle => 'اس ڈیوائس کی پیش رفت رکھیں؟';

  @override
  String get cloudKeepLocalConfirmMessage =>
      'اس ڈیوائس کے ڈیٹا سے نیا کلاؤڈ بیک اپ بنایا جائے گا۔ موجودہ ریموٹ بیک اپ اپنی تاریخ میں برقرار رہے گا۔';

  @override
  String get cloudUseRemoteConfirmTitle => 'مقامی پیش رفت تبدیل کریں؟';

  @override
  String get cloudUseRemoteConfirmMessage =>
      'موجودہ مقامی ایپ ڈیٹا گوگل ڈرائیو کے بیک اپ سے بدل جائے گا۔ پہلے ایک خفیہ کردہ مقامی ریکوری اسنیپ شاٹ محفوظ کیا جائے گا۔';

  @override
  String get cloudDisconnectConfirmTitle => 'گوگل منقطع کریں؟';

  @override
  String get cloudDisconnectConfirmMessage =>
      'خودکار کلاؤڈ کام بند کر دیا جائے گا۔ آپ کا قضا ڈیٹا اسی ڈیوائس پر محفوظ رہے گا۔';

  @override
  String get cloudRecoveryAvailable =>
      'پچھلے مقامی ڈیٹا کا محفوظ ریکوری اسنیپ شاٹ دستیاب ہے۔';

  @override
  String get cloudRecoverLocal => 'پچھلا مقامی ڈیٹا بحال کریں';

  @override
  String get cloudRecoveryConfirmTitle => 'پچھلا مقامی ڈیٹا بحال کریں؟';

  @override
  String get cloudRecoveryConfirmMessage =>
      'محفوظ مقامی اسنیپ شاٹ اس ڈیوائس کے موجودہ ایپ ڈیٹا کی جگہ لے گا۔';

  @override
  String get cloudAutomaticBackupRequiresConnection =>
      'خودکار بیک اپ فعال کرنے سے پہلے گوگل منسلک کریں۔';

  @override
  String get cloudBackupWorking => 'بیک اپ ہو رہا ہے…';

  @override
  String get cloudSetupChoiceTitle => 'قضا نماز میں خوش آمدید';

  @override
  String get cloudSetupChoiceDescription =>
      'اپنی چھوٹی ہوئی نمازوں کا حساب رکھیں اور قضا کی پیش رفت کو اپنی سہولت کے مطابق منظم کریں۔ آپ کا ریکارڈ اسی ڈیوائس پر محفوظ رہتا ہے۔ مختلف ڈیوائسز پر بیک اپ اور بحالی کے لیے آپ اختیاری طور پر گوگل استعمال کر سکتے ہیں۔';

  @override
  String get cloudSetupUseGoogle => 'گوگل کے ساتھ جاری رکھیں';

  @override
  String get cloudSetupContinueLocal => 'اسی ڈیوائس پر جاری رکھیں';

  @override
  String get cloudConnectionFailed =>
      'گوگل سے رابطہ مکمل نہیں ہو سکا۔ دوبارہ کوشش کریں یا مقامی طور پر جاری رکھیں۔';
}

/// The translations for Urdu, using the Latin script (`ur_Latn`).
class AppLocalizationsUrLatn extends AppLocalizationsUr {
  AppLocalizationsUrLatn() : super('ur_Latn');

  @override
  String get appTitle => 'Qaza Namaz';

  @override
  String get navHome => 'Home';

  @override
  String get navQaza => 'Qaza';

  @override
  String get navKnowledge => 'Rehnumai';

  @override
  String get settingsRemindersSection => 'Yaad dehaniyan';

  @override
  String get settingsRemindersSubtitle =>
      'Qaza mukammal karne ki rozanh yaad dhani';

  @override
  String get settingsBackupSection => 'Data aur storage';

  @override
  String get settingsBackupSubtitle => 'Cloud sync, export aur import';

  @override
  String get navSettings => 'Settings';

  @override
  String get prayerFajr => 'Fajr';

  @override
  String get prayerZuhr => 'Zuhr';

  @override
  String get prayerAsr => 'Asr';

  @override
  String get prayerMaghrib => 'Maghrib';

  @override
  String get prayerIsha => 'Isha';

  @override
  String get prayerWitr => 'Witr';

  @override
  String get statusPending => 'Baqi';

  @override
  String get statusCompleted => 'Mukammal';

  @override
  String get qazaSelectAllMatching => 'Sab mutabiq muntakhab karein';

  @override
  String qazaSelectAllMatchingCapped(String count) {
    return 'Pehle $count mutabiq record muntakhab kar liye gie';
  }

  @override
  String qazaConfirmBulkTitle(String count) {
    return '$count record mukammal krin';
  }

  @override
  String qazaConfirmBulkMessage(String count) {
    return 'Is se $count zair iltawa Namazein mukammal shumar hon gi aap fora baad wapas kar sakte hin baad mein nhin';
  }

  @override
  String get qazaConfirmBulkAction => 'Mukammal karein';

  @override
  String get errorNetwork =>
      'Koi rabta nhin aap ki Qaza is device par mehfooz hin aur on line hote hi sync ho jayein gi';

  @override
  String get errorTimeout =>
      'Bohat waqt lag gia thori der baad dobara koshish krin';

  @override
  String get errorPermission =>
      'Is ke liye ajazt darkar he Settings mein ja kar ajazt din';

  @override
  String get errorAuthentication => 'Is ke liye sign in hona zaroori he';

  @override
  String get errorValidation =>
      'Yeh input qabool nahi hoii jaanch kar dobara koshish krin';

  @override
  String get errorMalformedData => 'Yeh file Qaza backup app nhin ya kharab he';

  @override
  String get errorStorage =>
      'Device tabdeeli mehfooz nahi kar ska kuch jgh khaali kar ke dobara koshish krin';

  @override
  String get errorUnknown => 'Kuch ghalat ho gia';

  @override
  String get commonOpenSettings => 'Settings kholen';

  @override
  String get qazaSortLabel => 'Tarteeb';

  @override
  String get qazaSortOldestFirst => 'Pehle purani';

  @override
  String get qazaSortNewestFirst => 'Pehle nayi';

  @override
  String get filterAll => 'Sab';

  @override
  String get commonRetry => 'Dobara koshish karein';

  @override
  String get commonTotal => 'Kul';

  @override
  String get commonVersion => 'Version';

  @override
  String get stateErrorTitle => 'Kuch ghalat ho gaya';

  @override
  String get prayerRakatFajr => 'Fajr • 2 rakat farz';

  @override
  String get prayerRakatZuhr => 'Zuhr • 4 rakat farz';

  @override
  String get prayerRakatAsr => 'Asr • 4 rakat farz';

  @override
  String get prayerRakatMaghrib => 'Maghrib • 3 rakat farz';

  @override
  String get prayerRakatIsha => 'Isha • 4 rakat farz';

  @override
  String get prayerRakatWitr => 'Witr • 3 rakat wajib • mustaqil';

  @override
  String get syncSettingUp => 'Tarteeb di ja rahi hai';

  @override
  String get syncSettingUpDetail =>
      'Is device par aap ke Qaza record tiar kiye ja rahe hin';

  @override
  String get syncRestoring => 'Bahal kya ja raha hai';

  @override
  String get syncRestoringDetail =>
      'Aap ke mehfooz Qaza record is device par laye ja rahe hin';

  @override
  String get syncSynced => 'Sync shdh';

  @override
  String syncSyncedAt(String timestamp) {
    return 'Sync shdh • $timestamp';
  }

  @override
  String get syncSyncing => 'Sync ho raha hai';

  @override
  String get syncSaved => 'Mehfooz';

  @override
  String get syncSavedDetail =>
      'Aap ki tabdeeliyan is device par mehfooz hin aur khud-ba-khud sync ho jayein gi';

  @override
  String get syncErrorLabel => 'Sync mein masla';

  @override
  String get syncErrorDetail =>
      'Aap ki tabdeeliyan is device par mehfooz hin hm khud-ba-khud dobara koshish karein ge';

  @override
  String get commonClose => 'Band karein';

  @override
  String get commonCancel => 'Mansookh karein';

  @override
  String get commonDone => 'Mukammal';

  @override
  String get commonReset => 'Re set';

  @override
  String get commonClear => 'Saaf karein';

  @override
  String get commonBack => 'Wapas';

  @override
  String get commonContinue => 'Jari rakhein';

  @override
  String get commonLoading => 'Load ho raha hai...';

  @override
  String get commonToday => 'Aaj';

  @override
  String get commonYesterday => 'Kal';

  @override
  String hijriDate(Object day, Object month, Object year) {
    return '$day $month $year h';
  }

  @override
  String hijriMonthYear(Object month, Object year) {
    return '$month $year h';
  }

  @override
  String get hijriMonthMuharram => 'Muharram';

  @override
  String get hijriMonthSafar => 'Safar';

  @override
  String get hijriMonthRabiAlAwwal => 'Rabi al-awwal';

  @override
  String get hijriMonthRabiAlThani => 'Rabi al-thani';

  @override
  String get hijriMonthJumadaAlAwwal => 'Jumada al-awwal';

  @override
  String get hijriMonthJumadaAlThani => 'Jumada al-thani';

  @override
  String get hijriMonthRajab => 'Rajab';

  @override
  String get hijriMonthShaban => 'Shaban';

  @override
  String get hijriMonthRamadan => 'Ramadan';

  @override
  String get hijriMonthShawwal => 'Shawwal';

  @override
  String get hijriMonthDhulQadah => 'Zul-Qadah';

  @override
  String get hijriMonthDhulHijjah => 'Zul-Hijjah';

  @override
  String get homeTitle => 'Home';

  @override
  String get homeProfileTooltip => 'Profile';

  @override
  String get homeHeadingSetup => 'Apna Qaza Safar shuru karein';

  @override
  String get homeHeadingPending => 'Jari rakhein';

  @override
  String get homeHeadingCompleted => 'Aap ki tamam Qaza mukammal hai';

  @override
  String get homeSetupMessage => 'Aap ne ab tak koi Qaza Namaz shamil nahi ki';

  @override
  String get homeCompleteQaza => 'Qaza ada karein';

  @override
  String get homeAddNewQaza => 'Nayi Qaza shamil karein';

  @override
  String get homeAddManually => 'Dasti tor par Qaza shamil karein';

  @override
  String get homeStatTotal => 'Kul';

  @override
  String get homeAddQaza => 'Qaza shamil karein';

  @override
  String homeCompletedCount(int count) {
    return '$count mukammal';
  }

  @override
  String get homeProgressTitle => 'Aap ki progress';

  @override
  String get homeProgressError =>
      'Aap ki Qaza ki progress load nahi ho ski dobara koshish ke liye neeche khinchin';

  @override
  String get homeTodayProgress => 'Aaj ki progress';

  @override
  String homeDailyProgress(int completed, int target) {
    return '$completed / $target mukammal';
  }

  @override
  String homeDailyRemaining(int count) {
    return '$count baqi';
  }

  @override
  String get homeQazaPlan => 'Qaza ka mansooba';

  @override
  String get homeCompleteOldestQaza => 'Sab se prani Qaza mukammal karein';

  @override
  String get homeAuto => 'Khudkar';

  @override
  String get homeAutoSequence => 'Khudkar tarteeb';

  @override
  String get homeQazaTarget => 'Qaza ka hadaf';

  @override
  String get homePrayerSelection => 'Namaz ka antkhab';

  @override
  String get homePrayerTimeUnavailable =>
      'Namaz ke auqat set hone tak waqt Namaz ke mutabiq antkhab dstiab nhin';

  @override
  String get homeQazaTargetReachedTitle => 'Alhamdulillah!';

  @override
  String get homeQazaTargetReachedMessage =>
      'Aap ne aaj ka apna Qaza mansooba mukammal kar liya he\nAllah Taala aap ki koshishein qabool frmaie';

  @override
  String get homeDailyTarget => 'Rozanh hadaf';

  @override
  String homePerDay(int count) {
    return 'Rozanh $count';
  }

  @override
  String homeEstimatedCompletion(String date) {
    return 'Mutawaqqa tkmil: $date';
  }

  @override
  String get homeNextQaza => 'Agli Qaza';

  @override
  String get homeCompleteNextQaza => 'Agli Qaza mukammal karein';

  @override
  String get homeViewAllQaza => 'Tamam Qaza dekhein';

  @override
  String get homeDailyProgressError => 'Aaj ki progress load nahi ho ski';

  @override
  String progressPendingCompleted(String pending, String completed) {
    return '$pending baqi • $completed mukammal';
  }

  @override
  String progressCompletedPending(String completed, String pending) {
    return '$completed mukammal • $pending baqi';
  }

  @override
  String get qazaTitle => 'Qaza';

  @override
  String get qazaProgressLabel => 'Progress';

  @override
  String get qazaAddTooltip => 'Qaza shamil karein';

  @override
  String get qazaDateFilterAny => 'Asal tareekh: koi bhi';

  @override
  String get qazaDateFilterHelp => 'Asal Qaza tareekh ke mutabiq filter karein';

  @override
  String qazaDateFilterRange(String from, String to) {
    return '$from — $to';
  }

  @override
  String get qazaLoading => 'Aap ke Qaza record load ho rahe hin...';

  @override
  String get qazaEmptyTitle => 'Abhi koi Qaza record nahi';

  @override
  String get qazaEmptyMessage =>
      'Shuru karne ke liye chhoti hui Namazein shamil karein ya andaza lgaiin';

  @override
  String get qazaFilteredEmptyTitle => 'In filters se koi record nahi mila';

  @override
  String get qazaFilteredEmptyMessage =>
      'Mukhtalif halt Namaz ya tareekh ki had aazmaiin';

  @override
  String get qazaResetFilters => 'Filters re set karein';

  @override
  String qazaLoadError(String error) {
    return 'Aap ke Qaza record load nahi ho ske: $error';
  }

  @override
  String qazaLoadMoreError(String error) {
    return 'Mzid record load nahi ho ske: $error';
  }

  @override
  String qazaCompleteError(String error) {
    return 'Muntakhab Qaza mukammal nahi ho saki: $error';
  }

  @override
  String qazaCompletedOn(String date) {
    return '$date ko mukammal';
  }

  @override
  String qazaCompleteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Qaza mukammal karein',
      one: '1 Qaza mukammal karein',
    );
    return '$_temp0';
  }

  @override
  String get qazaRecordActions => 'Record ke aamaal';

  @override
  String get qazaEditRecord => 'Tarmeem';

  @override
  String get qazaDeleteRecord => 'Delete karein';

  @override
  String get qazaEditRecordTitle => 'Qaza mein tarmeem';

  @override
  String get qazaEditPrayer => 'Namaz';

  @override
  String get qazaEditDate => 'Asal tareekh';

  @override
  String get qazaEditDateHelp => 'Qaza ki asal tareekh muntakhab karein';

  @override
  String get qazaSaveChanges => 'Tabdeeliyan mehfooz karein';

  @override
  String get qazaDeleteRecordTitle => 'Qaza record delete krin';

  @override
  String qazaDeleteRecordMessage(Object date, Object prayer) {
    return '$date ki $prayer Qaza mustaqil tor par delete krin yeh amal wapas nahi ho skta';
  }

  @override
  String get qazaRecordUpdated => 'Qaza record app date ho gia';

  @override
  String qazaDuplicateRecord(Object date, Object prayer) {
    return '$date ki $prayer Qaza pehle se maujood he';
  }

  @override
  String get qazaRecordUpdateFailed =>
      'Qaza record app date nahi ho ska dobara koshish krin';

  @override
  String get qazaRecordDeleted => 'Qaza mustaqil tor par delete ho gayi he';

  @override
  String get qazaRecordDeleteFailed =>
      'Qaza record delete nahi ho ska dobara koshish krin';

  @override
  String get qazaUndoAction => 'Wapas karein';

  @override
  String qazaUndoAvailable(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Haalya takmeelaat wapas ki ja sakti hin',
      one: 'Haalya tkmil wapas ki ja sakti he',
    );
    return '$_temp0';
  }

  @override
  String qazaUndoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Qaza dobara baqi ho giin',
      one: '1 Qaza dobara baqi ho gii',
    );
    return '$_temp0';
  }

  @override
  String qazaCompletedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Qaza mukammal ho giin',
      one: '1 Qaza mukammal ho gii',
      zero: 'Kuch mukammal nahi hoa',
    );
    return '$_temp0';
  }

  @override
  String get calendarSelectYear => 'Saal muntakhab karein';

  @override
  String get calendarSelectHint =>
      'Muntakhab karne ke liye dstiab tareekh par tap krin';

  @override
  String calendarSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tareekhein mntkhb',
      one: '1 tareekh mntkhb',
    );
    return '$_temp0';
  }

  @override
  String get authTitle => 'Sign in';

  @override
  String get authWelcomeBack => 'Khush aamdeed';

  @override
  String get authSubtitle =>
      'Apne Qaza Namaz tracker tak rasai ke liye sign in krin';

  @override
  String get authContinueWithGoogle => 'Google se jari rakhein';

  @override
  String get authSigningIn => 'Sign in ho raha hai...';

  @override
  String get authProviderNote =>
      'Is waqt Google hi munsalik tasdeeqi faraham kuninda he sign in ki halat fairbis se khud-ba-khud bahal ho jati he';

  @override
  String get authHelpTooltip => 'Tasdeeq mein madad';

  @override
  String get authHelpTitle => 'Tasdeeq';

  @override
  String get authHelpBody =>
      'Is release mein Google sign in hi munsalik tasdeeqi tareeqa he aap ka Qaza Data isi fairbis account se munsalik rehta hai jis se aap sign in karte hin';

  @override
  String get authDismiss => 'Band karein';

  @override
  String get authFailed => 'Sign in nahi ho ska dobara koshish krin';

  @override
  String get welcomeTagline => 'Roohani ibadat aur Namaz ki pabandi';

  @override
  String get welcomeHeadline =>
      'Apni chhoti hui Namazon ka wazahat aur tasalsul ke saath hisaab rkhin';

  @override
  String get welcomeBody =>
      'Apni Qaza Namazein darj krin ada karein aur in ka hisaab rakhein — aik aik Namaz kar ke';

  @override
  String get welcomeGetStarted => 'Shuru karein';

  @override
  String get welcomeSignIn => 'Pehle se account he sign in karein';

  @override
  String get splashTagline => 'Namaz ki pabandi ke liye aik prskon jgh';

  @override
  String get accountChoiceHeadline => 'Apni Qaza ki progress mehfooz rakhein';

  @override
  String get accountChoiceDescription =>
      'Google se sign in karein taake aap ki progress mukhtalif dioaisz par mehfooz aur bahal ho ske';

  @override
  String get accountChoiceContinueGoogle => 'Google ke saath jari rakhein';

  @override
  String get accountChoiceContinueGuest => 'Mehmaan ke tor par jari rakhein';

  @override
  String get accountChoiceGuestDescription =>
      'Mehmaan ka Data isi device par mehfooz rehta he aap baad mein Google munsalik kar sakte hin';

  @override
  String get accountChoiceGoogleFailed =>
      'Google sign in mukammal nahi ho ska dobara koshish krin';

  @override
  String get accountTitle => 'Account';

  @override
  String get accountProfileChecking =>
      'Google account ki halat maloom ki ja rahi hai…';

  @override
  String get accountProfileUnavailable => 'Google account ki halat dstiab nahi';

  @override
  String get accountProfileUnavailableDetail =>
      'Aap ke Qaza record is device par dstiab rahein ge';

  @override
  String get accountGuest => 'Mehmaan';

  @override
  String get accountConnectGoogle => 'Google se munsalik karein';

  @override
  String get accountSignInMethod => 'Sign in ka tareeqa';

  @override
  String get accountGoogleAuth => 'Google';

  @override
  String get accountSignedInWithGoogle => 'Google se sign in hin';

  @override
  String get accountStatus => 'Account ki halat';

  @override
  String get accountSignedIn => 'Mqami';

  @override
  String get accountRecordsRetained =>
      'Aap ke mehfooz Qaza record maujood rahein ge aur agli baar sign in par bahal ho jayein ge';

  @override
  String get accountDeveloperContext => 'Developer tafseelaat';

  @override
  String get accountFirebaseUid => 'Fairbis UID';

  @override
  String get accountNotAvailable => 'Dstiab nahi';

  @override
  String get accountSignOut => 'Sign out';

  @override
  String get accountSignOutPrompt => 'Sign out krin';

  @override
  String get accountSignOutExplanation =>
      'Sign out karne se aap ka Google account munqati ho jaye ga aap ki Qaza progress is device par barqarar rahe gi';

  @override
  String get dataTitle => 'Braamd o daraamad';

  @override
  String get dataExportTitle => 'Data braamd karein';

  @override
  String get dataExportBody =>
      'Apne Qaza khate ki aik JSON naqal mehfooz krin braamd karne se kuch app load nahi hota';

  @override
  String get dataExportAction => 'Braamd';

  @override
  String get dataExportDialogTitle => 'Qaza Data braamd mehfooz karein';

  @override
  String get dataExportSaved => 'Braamd kamyabi se mehfooz ho gii';

  @override
  String get dataExportCanceled =>
      'Braamd mansookh hoii aap ka Data tabdeel nahi hoa';

  @override
  String get dataExportSignInRequired =>
      'Apna Qaza Data braamd karne se pehle sign in krin';

  @override
  String dataExportFailed(String error) {
    return 'Braamd nakam: $error';
  }

  @override
  String get dataImportTitle => 'Data daraamad karein';

  @override
  String get dataImportBody =>
      'Koi JSON braamd kholin is ki mukammal jaanch krin inzimaam ka jaiza lin phir usay is account par laagu krin';

  @override
  String get dataImportAction => 'Daraamad';

  @override
  String get dataImportReviewTitle => 'Data daraamad ka jaiza';

  @override
  String get dataImportCanceled =>
      'Daraamad mansookh hoii aap ka Data tabdeel nahi hoa';

  @override
  String get dataImportSignInRequired =>
      'Data daraamad karne se pehle sign in krin';

  @override
  String get dataImportEmptyFile =>
      'Muntakhab file khaali ya na-qabil mutala he';

  @override
  String dataImportRejected(String error) {
    return 'Daraamad mustarad: $error\nKoi juzvi daraamad laagu nahi hoii';
  }

  @override
  String dataImportComplete(int added, int completed, int unchanged) {
    return 'Daraamad mukammal: $added shaml $completed mkml $unchanged baghair tbdili';
  }

  @override
  String get dataProcessing => 'Data par kam ho raha hai…';

  @override
  String get dataSafetyTitle => 'Data ki hifazat';

  @override
  String get dataSafetyBody =>
      'Braamd karne se Cloud Data delete nahi hota daraamad se mojodh record khtm nahi hote sign out Data delete krna nhin aur app in install karne se Cloud record delete nahi hote';

  @override
  String get dataRemapNote =>
      'Daraamad shdh record mojodh sign in account se munsalik kar diye jate hin is ke baad mojodh local-first sync parat pas manzar mein Firestore se tsdiq karti he';

  @override
  String get addQazaTitle => 'Qaza shamil karein';

  @override
  String get addQazaStep1 => 'Marhala 1 az 3 • tareekhein muntakhab karein';

  @override
  String get addQazaStep2 =>
      'Marhala 2 az 3 • chhoti hui Namazein muntakhab karein';

  @override
  String get addQazaStep3 => 'Marhala 3 az 3 • jaiza aur izafa';

  @override
  String get addQazaModeSingle => 'Aik';

  @override
  String get addQazaModeRange => 'Doraniya';

  @override
  String get addQazaModeMultiple => 'Mtdd';

  @override
  String get addQazaModeSingleTitle => 'Aik tareekh';

  @override
  String get addQazaModeRangeTitle => 'Tareekhon ka doraniya';

  @override
  String get addQazaModeMultipleTitle => 'Mtdd tareekhein';

  @override
  String get addQazaChooseSingle => 'Aik tareekh muntakhab karein';

  @override
  String get addQazaChooseRange => 'Tareekhon ka doraniya muntakhab karein';

  @override
  String get addQazaChooseMultiple => 'Mtdd tareekhein muntakhab karein';

  @override
  String get addQazaAvailabilityNote =>
      'Range mode mein durust tareekhein muntakhab ki ja sakti hin chahe in par koi Qaza baqi na ho jaiza sirf ahl Namazein shamil karta he';

  @override
  String get addQazaStepNameDates => 'Tareekhein muntakhab karein';

  @override
  String get addQazaStepNamePrayers => 'Qaza Namazein';

  @override
  String get addQazaStepNameReview => 'Jaiza';

  @override
  String addQazaStepSemantics(int step, String name) {
    return 'Marhala $step: $name';
  }

  @override
  String addQazaPartialAvailability(int available, int total) {
    return '$total mein se $available tareekhon par dstiab';
  }

  @override
  String get addQazaAvailableEveryDate => 'Hr muntakhab tareekh par dstiab';

  @override
  String get addQazaEligibleOnlyNote =>
      'Sirf ahl tareekh aur Namaz ke mjmoe shamil kiye jayein ge pehle se record shdh chhor diye jayein ge';

  @override
  String addQazaAddCount(String count) {
    return '$count Qaza shamil karein';
  }

  @override
  String get addQazaNothingNew =>
      'Shamil karne ko kuch naya nahi — yeh mjmoe pehle se record hin';

  @override
  String get addQazaChecking => 'Aap ka ledger jaanchaa ja raha hai...';

  @override
  String get addQazaNextPrayers => 'Agla: jaiza aur izafa';

  @override
  String get addQazaPrayersHeading => 'Chhoti hui Namazein';

  @override
  String get addQazaSelectAll => 'Sab muntakhab karein';

  @override
  String get addQazaAllSelected => 'Sab muntakhab hin';

  @override
  String get addQazaReviewHeading => 'Jaiza aur izafa';

  @override
  String get addQazaReviewNote =>
      'Khulase ki tsdiq krin phir yeh Qaza record apne khate mein shamil krin';

  @override
  String get addQazaCombinationNote =>
      'Hr tareekh aur Namaz ka jor aik alg baqi record banta he pehle se maujood jor khud-ba-khud chhor diye jate hin';

  @override
  String get addQazaSelectionLabel => 'Antkhab';

  @override
  String get addQazaDatesLabel => 'Tareekhein';

  @override
  String get addQazaDateCountLabel => 'Tareekhon ki tadaad';

  @override
  String get addQazaDateRangeLabel => 'Tareekhon ka doraniya';

  @override
  String get addQazaCombinationCountLabel => 'Mjmoe';

  @override
  String get addQazaPrayersLabel => 'Namazein';

  @override
  String get addQazaPrayersPerDateLabel => 'Fi tareekh Namazein';

  @override
  String get addQazaExistingLabel => 'Pehle se maujood jor';

  @override
  String get addQazaNewRecordsLabel => 'Nie record';

  @override
  String get addQazaNewLabel => 'Naya';

  @override
  String get addQazaAlreadyAddedLabel => 'Pehle se shamil';

  @override
  String get addQazaUnavailableLabel => 'Dstiab nahi';

  @override
  String get addQazaTimeBlocked =>
      'Namaz ke waqt ke ikhtitam ke baad dstiab hoga';

  @override
  String get addQazaCancelledTitle => 'Qaza shamil krna mansookh hua';

  @override
  String get addQazaCancelledMessage =>
      'Izafa mansookh kar dia gia jo record pehle hi mehfooz ho chuke hin woh barqarar hin';

  @override
  String get addQazaNewQazaLabel => 'Nie Qaza record';

  @override
  String get addQazaInProgress => 'Qaza shamil ho rahi hai...';

  @override
  String get qazaImportAdded => 'Shamil';

  @override
  String get qazaImportSkipped => 'Chhore gaye';

  @override
  String get addQazaCreatedTitle => 'Qaza record ban gaye';

  @override
  String addQazaSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count din muntakhab • aap ki kon C Namazein chhotin',
      one: '1 din muntakhab • aap ki kon C Namazein chhotin',
    );
    return '$_temp0';
  }

  @override
  String qazaHistorySelectedDates(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count muntakhab tareekhein',
      one: '1 muntakhab tareekh',
    );
    return '$_temp0';
  }

  @override
  String qazaHistorySelectionScope(int prayers, int days) {
    return '$prayers Namazein · $days din';
  }

  @override
  String qazaHistoryProgressPercentage(int percent) {
    return '$percent%';
  }

  @override
  String qazaHistoryTrackedRecords(int count) {
    return '$count zair nigrani record';
  }

  @override
  String qazaHistoryAdded(String date) {
    return '$date ko shamil kya gaya';
  }

  @override
  String get qazaHistoryShowAllDates => 'Tamam tareekhein dikhayein';

  @override
  String get qazaHistoryHideDates => 'Tareekhein chhupayein';

  @override
  String get qazaHistoryDeletedStatus => 'Delete shdh';

  @override
  String get qazaHistoryNoDates => 'Koi tareekh nahi';

  @override
  String addQazaDateCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tareekhein',
      one: '1 tareekh',
    );
    return '$_temp0';
  }

  @override
  String addQazaCreatedMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count record aap ke khate mein shamil ho gie',
      one: '1 record aap ke khate mein shamil ho gia',
    );
    return '$_temp0';
  }

  @override
  String addQazaUnavailablePrayer(String rakats) {
    return '$rakats • hr muntakhab tareekh par pehle se drj ada shdh ya Namaz ka waqt abhi khtm nahi hua';
  }

  @override
  String get commonNone => 'Koi nahi';

  @override
  String get completeTitle => 'Qaza ada karein';

  @override
  String get completeHeading => 'Sab se purana baqi record mukammal karein';

  @override
  String get completeIntro =>
      'Aik waqt mein aik record mukammal krin kamyabi ke baad agla purana record fora dikhaya jata he';

  @override
  String get completeLoading => 'Sab se purana baqi record load ho raha hai…';

  @override
  String get completeLoadError => 'Aap ka Qaza record load nahi ho ska';

  @override
  String get completeNoPendingTitle => 'Is Namaz ki koi Qaza baqi nhin';

  @override
  String get completeNoPendingMessage =>
      'Koi aur Namaz muntakhab karein ya pehle Qaza record shamil krin';

  @override
  String get completeOldestSubtitle => 'Taaza trin baqi record';

  @override
  String get completeOriginalDate => 'Asal chhootne ki tareekh';

  @override
  String get completeTimestampNote => 'Adaigi ka waqt alg mehfooz kya jata he';

  @override
  String get completeAction => 'Taaza trin Qaza ada karein';

  @override
  String get completeInProgress => 'Mukammal ho raha hai...';

  @override
  String get completeFailed => 'Qaza mukammal nahi ho ski dobara koshish krin';

  @override
  String completePrayerQaza(String prayer) {
    return '$prayer ki Qaza';
  }

  @override
  String completeSuccess(String prayer) {
    return '$prayer ki Qaza kamyabi se mukammal hoii';
  }

  @override
  String completeSuccessNext(String prayer) {
    return '$prayer ki Qaza mukammal hui • agla purana record tiar he';
  }

  @override
  String get knowledgeBaseTitle => 'Namaz aur Qaza ki Rehnumai';

  @override
  String get knowledgeBaseSearchHint =>
      'Namaz ke masail aur ghalat fahmiyan talash karein';

  @override
  String get knowledgeBaseClearSearch => 'Talash saaf karein';

  @override
  String get knowledgeCategoryMasail => 'Masail';

  @override
  String get knowledgeCategoryMugalat => 'Mughalte';

  @override
  String get knowledgeBaseTopicAll => 'Tamam mozuaat';

  @override
  String get knowledgeTopicBasic => 'Bunyadi batein';

  @override
  String get knowledgeTopicPrayerUnits => 'Rakaat';

  @override
  String get knowledgeTopicSleepForgetfulness => 'Neend aur bhool';

  @override
  String get knowledgeTopicIntentionalOmission => 'Jaan bojh kar tark';

  @override
  String get knowledgeTopicFriday => 'Jumma';

  @override
  String get knowledgeTopicMenstruation => 'Haiz';

  @override
  String get knowledgeTopicNifas => 'Nifas';

  @override
  String get knowledgeTopicMenstruationNifas => 'Haiz o nifas';

  @override
  String get knowledgeTopicMisconceptions => 'Mughalte';

  @override
  String get knowledgeBaseEmptyTitle => 'Rehnumai ka koi mazmoon nahi mila';

  @override
  String get knowledgeBaseEmptyMessage =>
      'Koi aur lafz talash karein ya doosra mozoo muntakhab krin';

  @override
  String get knowledgeBaseLoadError => 'Namaz ki Rehnumai load nahi ho ski';

  @override
  String get knowledgeBaseLanguage => 'Rehnumai ke mazameen ki Zaban';

  @override
  String get knowledgeArticleTitle => 'Mazmoon';

  @override
  String get knowledgeArticleReferences => 'Hawala jaat';

  @override
  String get knowledgeArticleRelated => 'Mutaliqa mazameen';

  @override
  String get knowledgeArticleNotFound => 'Mazmoon nahi mla';

  @override
  String get settingsAccountSection => 'Account';

  @override
  String get settingsAccountSubtitle =>
      'Apne sign in aur account ki tafseelaat snbhalin';

  @override
  String get settingsGoogleSignIn => 'Google sign in';

  @override
  String get settingsKnowledgeBaseSubtitle =>
      'Namaz ke masail aur aam ghalat fahmiyan prhin';

  @override
  String get settingsDataSection => 'Data o astorij';

  @override
  String get settingsDataSubtitle =>
      'Apne Qaza Data ko snk backup ap braamd aur daraamad krin';

  @override
  String get settingsDataCloud => 'Data o Cloud';

  @override
  String get settingsDataCloudSubtitle => 'Snk braamd aur daraamad ki halat';

  @override
  String get settingsResetCounterTitle => 'Qaza counter re set karein';

  @override
  String get settingsResetCounterSubtitle =>
      'Darj shdh tamam Qaza Namazein delete karke ginti dobara sfr se shuru krin';

  @override
  String get settingsResetCounterEmpty =>
      'Re set karne ke liye koi Qaza record maujood nhin';

  @override
  String get settingsResetCounterDialogTitle => 'Kya Qaza counter re set krin';

  @override
  String get settingsResetCounterDialogMessage =>
      'Is account ke tamam Qaza records — baqi aur mukammal dono — is device aur aap ke Cloud backup app se hamesha ke liye delete ho jayein ge\n\nAap ka counter sfr par aa jaye ga aur ab tak ki gayi progress zaya ho jaye gi yeh amal wapas nahi ho skta agar dobara zaroorat parh sakti hai to pehle apna Data braamd kar lin';

  @override
  String settingsResetCounterAcknowledge(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Mein samajhta/samajhti hon keh $count Qaza records hamesha ke liye delete ho jayein ge',
      one:
          'Mein samajhta/samajhti hon keh 1 Qaza record hamesha ke liye delete ho jaye ga',
    );
    return '$_temp0';
  }

  @override
  String get settingsResetCounterConfirm => 'Counter re set karein';

  @override
  String get settingsResetCounterDone => 'Qaza counter re set ho gia';

  @override
  String settingsResetCounterFailed(String error) {
    return 'Qaza counter re set nahi ho saka: $error';
  }

  @override
  String get authContinueAsGuest => 'Mehmaan ke tor par jari rakhein';

  @override
  String get authGuestNote =>
      'Apni Qaza progress ko apne account ke saath mehfooz rakhne ke liye baad mein Google se sign in kar sakte hin';

  @override
  String get backupPromptTitle => 'Apni progress mehfooz rakhein';

  @override
  String get backupPromptBody =>
      'Apni Qaza progress ko apne account ke saath mehfooz rakhne ke liye Google se sign in krin';

  @override
  String get backupPromptConfirm => 'Google se jari rakhein';

  @override
  String get backupPromptDismiss => 'Abhi nahi';

  @override
  String get settingsBackupSignIn => 'Backup app / sign in';

  @override
  String get settingsBackupSignInSubtitle =>
      'Aap mehmaan ke tor par app istemal kar rahe hin Qaza ka backup app lene ke liye sign in krin';

  @override
  String get backupSignInFailed =>
      'Sign in nakam rha aap ki progress ab bhi is device par mehfooz he';

  @override
  String get backupSignInCancelled =>
      'Sign in mansookh ho gia aap ki progress ab bhi is device par mehfooz he';

  @override
  String backupSignInFailedReason(String reason) {
    return 'Sign in nakam raha: $reason aap ki progress ab bhi is device par mehfooz he';
  }

  @override
  String backupMigrationDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Sign in ho gia aap ki Qaza progress ab aap ke account se munsalik he',
      one:
          'Sign in ho gia aap ki Qaza progress ab aap ke account se munsalik he',
      zero:
          'Sign in ho gia aap ki Qaza progress ab aap ke account se munsalik he',
    );
    return '$_temp0';
  }

  @override
  String get settingsAboutSection => 'Taaruf';

  @override
  String get settingsAboutSubtitle => 'App ki maloomat aur orzhn ki tfsil';

  @override
  String settingsAboutRowSubtitle(String version) {
    return 'Qaza Namaz • orzhn $version';
  }

  @override
  String get settingsAppDescription => 'Islami Namaz Qaza tracker';

  @override
  String get cloudSyncTitle => 'Cloud sync';

  @override
  String get cloudSyncNow => 'Abhi sync karein';

  @override
  String get cloudPendingChanges => 'Zair iltawa tabdeeliyan';

  @override
  String get cloudLastSynced => 'Aakhri sync';

  @override
  String get cloudExportImportSubtitle =>
      'User ke ikhtiyar mein JSON backup app aur mehfooz bhali in iqdamat se Cloud Data delete nahi hota';

  @override
  String get cloudInactive => 'Is build mein off line astorij faal nahi he';

  @override
  String get cloudBootstrapping =>
      'Is device par aap ke Qaza record tarteeb diye ja rahe hin…';

  @override
  String get cloudHydrating =>
      'Aap ke mehfooz Qaza record is device par bahal kiye ja rahe hin…';

  @override
  String get cloudSynced => 'Aap ke tamam Qaza record Cloud mein mehfooz hin';

  @override
  String get cloudSyncing => 'Aap ka khata sync ho raha hai…';

  @override
  String get cloudOffline =>
      'Off line — record is device par mehfooz hin aur khud-ba-khud sync ho jayein ge';

  @override
  String cloudPendingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tabdeeliyan sync ki muntazir hin',
      one: '1 tabdeeli sync ki muntazir he',
    );
    return '$_temp0';
  }

  @override
  String get cloudSyncProblem =>
      'Sync mein masla — aap ka Data is device par mehfooz he';

  @override
  String get cloudQazaCount => 'Qaza records ki tadaad';

  @override
  String cloudQazaCountValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Qaza records',
      one: '1 Qaza record',
      zero: 'Koi Qaza record nahi',
    );
    return '$_temp0';
  }

  @override
  String get cloudBackupStatus => 'Cloud backup app';

  @override
  String get cloudBackupDeleted =>
      'Cloud naqal delete ho gii local records barqarar hin';

  @override
  String get cloudLocalVsCloudTitle => 'Local aur Cloud Data';

  @override
  String get cloudLocalVsCloudBody =>
      'Aap ke Qaza record off line istemal ke liye is device par mehfooz rehte hin sign in hone par tabdeeliyan aap ke niji Cloud account se sync ho sakti hin braamd aik local backup app he Cloud Data delete karne se local records delete nahi hote';

  @override
  String get cloudDeleteTitle => 'Cloud Data delete karein';

  @override
  String get cloudDeleteBody =>
      'Yeh aap ke Cloud account se Qaza records mustaqil tor par delete kar de ga is device ke local records barqarar rahein ge yeh amal wapas nahi ho skta agar backup app darkar ho sakta hai to pehle Data braamd kar lin';

  @override
  String get cloudDeleteAcknowledge =>
      'Mein samajhta/samajhti hon keh Cloud naqal mustaqil tor par delete ho jaye gi';

  @override
  String get cloudDeleteAction => 'Cloud Data delete karein';

  @override
  String get cloudDeleteDone =>
      'Cloud Qaza Data delete ho gia is device ke local records barqarar hin';

  @override
  String get cloudDeleteFailed =>
      'Cloud Data delete nahi ho ska aap ke local records mehfooz hin';

  @override
  String get cloudDeleteSignInRequired =>
      'Cloud Data sambhalne ke liye sign in krin';

  @override
  String get accountGoogle => 'Google account';

  @override
  String get accountCloudBackup => 'Cloud backup app';

  @override
  String get accountAutomatic => 'Khudkar';

  @override
  String get accountBackupPaused => 'Backup app rok dia gaya hai';

  @override
  String get accountEnableBackup => 'Backup app faal karein';

  @override
  String get accountDisconnect => 'Google munqati karein';

  @override
  String get accountDeleteCloudData => 'Cloud Data delete karein';

  @override
  String get accountDeleteCloudDataMessage =>
      'Aap ki Cloud naqal mustaqil tor par delete ho jaye gi is device par aap ka Qaza Data barqarar rahe ga';

  @override
  String get accountDeleteCloudDataAcknowledge =>
      'Mein samajhta/samajhti hon keh Cloud naqal mustaqil tor par delete ho jaye gi';

  @override
  String get accountCancel => 'Mansookh';

  @override
  String get accountContinue => 'Jari rakhein';

  @override
  String get accountGuestTitle => 'Yeh device';

  @override
  String get accountGuestLocalDataSubtitle =>
      'Aap ka Data is device par mehfooz hai';

  @override
  String get accountNotConnectedGoogle => 'Google se munsalik nahi';

  @override
  String get accountKeepProgressSafe => 'Apni progress mehfooz rakhein';

  @override
  String get accountKeepProgressSafeDescription =>
      'Apni Qaza progress ko mukhtalif dioaisz par backup app aur bahal karne ke liye Google account munsalik krin';

  @override
  String get accountGuestContinueMessage =>
      'Aap ki mqami progress isi device par mehfooz rehti he';

  @override
  String get accountBackupSection => 'Backup app';

  @override
  String get accountBackupAutomaticDescription =>
      'Apni Qaza progress ka khudkar backup app lein';

  @override
  String get accountAccountActions => 'Account ke iqdamat';

  @override
  String get accountSignOutDescription =>
      'Apne Google account se sign out krin aap baad mein dobara sign in kar sakte hin';

  @override
  String get accountDisconnectDescription =>
      'Qaza Namaz se Google ka connection hatayein aur mehmaan mode par wapas jaiin';

  @override
  String get accountDangerZone => 'Khatarnak iqdamat';

  @override
  String get settingsAccountGuestSubtitle => 'Mqami • sirf yeh device';

  @override
  String get settingsAccountGoogleSubtitle => 'Google ke saath sign in';

  @override
  String get accountConnectFailed =>
      'Google connection mukammal nahi ho ska aap ka local Data mehfooz he';

  @override
  String get accountCloudDeleted =>
      'Cloud Data delete ho gia aap ka local Qaza Data is device par barqarar he';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsPreferences => 'Tarjeehat';

  @override
  String get settingsPreferencesSubtitle =>
      'Zaban aur zahiri shakal ki trtibat';

  @override
  String get settingsAppearance => 'Zahiri shakal';

  @override
  String get settingsAppearanceSubtitle =>
      'Muntakhab karein keh app is device par kaisi nazar aaie';

  @override
  String get settingsThemeSystem => 'System';

  @override
  String get settingsThemeLight => 'Roshan';

  @override
  String get settingsThemeDark => 'Tareek';

  @override
  String get settingsLanguage => 'Zaban';

  @override
  String get settingsLanguageSubtitle =>
      'App mein istemal hone wali Zaban muntakhab krin';

  @override
  String get settingsLanguageNote =>
      'Namaz ke naam aur Hijri tareekhein muntakhab Zaban ke mutabiq hon gi Urdu dayein se bayein likhi jati he';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageUrdu => 'Urdu';

  @override
  String get homeTodayProgressHeader => 'Aaj ki progress';

  @override
  String get homeNextQazaCurrentPrayer => 'Agli Qaza (mojodh Namaz)';

  @override
  String get homeOldestPending => 'Sab se prani baqi';

  @override
  String get homeOverallQaza => 'Majmooi Qaza';

  @override
  String get homePendingByPrayer => 'Namaz ke lihaaz se baqi';

  @override
  String get homePrayerBreakdown => 'Namaz waar jaiza';

  @override
  String get homeViewDetails => 'Tafseelaat dekhein';

  @override
  String get homeViewAll => 'Sab dekhein';

  @override
  String get homeCompleted => 'Mukammal';

  @override
  String get homePending => 'Baqi';

  @override
  String get homeDetailedStatistics => 'Tafseeli aadaad o shumar';

  @override
  String get homeDetailedStatisticsSubtitle => 'Majmooi aur Namaz waar tkmil';

  @override
  String get homeQazaActivity => 'Qaza sargarmi';

  @override
  String get homeProgressHistory => 'Progress ki tareekh';

  @override
  String get homeRangeWeekly => 'Hafta waar';

  @override
  String get homeRangeMonthly => 'Mahana';

  @override
  String get homeRangeYearly => 'Saalana';

  @override
  String get homeWeeklyTargetLabel => 'Hafta waar hadaf';

  @override
  String get homeMonthlyTarget => 'Mahana hadaf';

  @override
  String get homeProgressLabel => 'Progress';

  @override
  String get homeActiveDays => 'Faal din';

  @override
  String get homeActiveMonths => 'Faal maheene';

  @override
  String get homeGoalReached => 'Hadaf mukammal';

  @override
  String get homeRemaining => 'Baqi';

  @override
  String get homeActual => 'Mukammal shdh';

  @override
  String get homeNoActivity => 'Is muddat mein koi Qaza mukammal nahi hoii';

  @override
  String get homeSelectDay =>
      'Tafseelaat dekhne ke liye kisi din ko muntakhab krin';

  @override
  String get homePreviousWeek => 'Pichla hafta';

  @override
  String get homeNextWeek => 'Agla hafta';

  @override
  String get homePreviousMonth => 'Pichla maheena';

  @override
  String get homeNextMonth => 'Agla maheena';

  @override
  String get homePreviousYear => 'Pichla saal';

  @override
  String get homeNextYear => 'Agla saal';

  @override
  String get homeFutureDay => 'Aane wala din';

  @override
  String get homeDailyGoalsTitle => 'Aap ke rozanh ke ahdaaf';

  @override
  String get homeLastSevenDays => 'Guzishta 7 din';

  @override
  String get homeGoalsAchieved => 'Hadaf hasil kya';

  @override
  String get homeWeeklyTarget => 'Aap ka hafta waar hadaf';

  @override
  String homeWeeklyTargetProgress(int completed, int target) {
    return '$target mein se $completed';
  }

  @override
  String get homeDayActivityDetails => 'Din ki tafseelaat';

  @override
  String get homeTodayDate => 'Aaj';

  @override
  String homeCurrentPrayerLabel(String prayer) {
    return 'Mojodh Namaz: $prayer';
  }

  @override
  String get profileLanguageTitle => 'Apni Zaban muntakhab karein';

  @override
  String get profileLanguageIntro =>
      'App mein istemal hone wali Zaban muntakhab krin';

  @override
  String get profileSetupTitle => 'Apna Profile mukammal karein';

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileIntro =>
      'Yeh maloomat aap ke Qaza plan aur Namaz se mutaliq qawaid ke liye istemal hon gi';

  @override
  String get profileSettingsSubtitle =>
      'Aap ki Namaz Profile aur Qaza plan ki trtibat';

  @override
  String get profileGender => 'Jins';

  @override
  String get profileMale => 'Mard';

  @override
  String get profileFemale => 'Khatoon';

  @override
  String get profileMadhab => 'Mazhab / fiqhi maktab';

  @override
  String get profileHanafi => 'Hanafi';

  @override
  String get profileShafi => 'Shafai';

  @override
  String get profileMaliki => 'Maliki';

  @override
  String get profileHanbali => 'Hanbali';

  @override
  String get profileOther => 'Deegar';

  @override
  String get profileDateOfBirth => 'Tareekh paidaish';

  @override
  String get profileDobDay => 'Din';

  @override
  String get profileDobMonth => 'Maheena';

  @override
  String get profileDobYear => 'Saal';

  @override
  String get profileSelectDate => 'Tareekh muntakhab karein';

  @override
  String get profileSelectDobHelp => 'Apni tareekh paidaish muntakhab karein';

  @override
  String get profileHijriHint =>
      'Gregorian tareekh muntakhab karne ke baad Hijri tareekh bhi dikhayi jaye gi';

  @override
  String get profilePubertyAge => 'Balughat ki umar';

  @override
  String get profileStartPrayingAge => 'Namaz shuru karne ki umar';

  @override
  String get profileSelectGenderFirst => 'Pehle jins muntakhab karein';

  @override
  String get profileSelectPubertyFirst =>
      'Pehle balughat ki umar muntakhab karein';

  @override
  String get profileSelectDobFirst => 'Pehle tareekh paidaish muntakhab karein';

  @override
  String get profileWitr => 'Witr';

  @override
  String get profileWitrOptional =>
      'Deegar ke liye aap muntakhab kar sakte hin keh Witr shamil hon ya nhin';

  @override
  String get profileWitrIncluded => 'Shamil';

  @override
  String get profileWitrExcluded => 'Shamil nahi';

  @override
  String get profileSubmit => 'Jari rakhein';

  @override
  String get profileSave => 'Tabdeeliyan mehfooz karein';

  @override
  String get profileEdit => 'Profile mein tarmeem karein';

  @override
  String profileAgeYears(int count) {
    return '$count saal';
  }

  @override
  String get profileDiscardChangesTitle =>
      'Ghair mehfooz tabdeeliyan mustarad krin';

  @override
  String get profileDiscardChangesMessage =>
      'Aap ki tabdeeliyan mehfooz nahi hoiin kya aap unhein mustarad karke tarmeem se bahar nikalna chahte hin';

  @override
  String get profileDiscardChangesAction => 'Tabdeeliyan mustarad karein';

  @override
  String get profileQazaAssumptionsChanged =>
      'Profile mein ki jane wali tabdeeliyan';

  @override
  String get profileQazaAssumptionsHint =>
      'Qaza plan laagu karne se pehle pichli aur nayi qadron ka jaiza lin';

  @override
  String get profileQazaPlanChangedTitle => 'Qaza plan app date hoga';

  @override
  String get profileQazaPlanSummary =>
      'Aap ki Profile mein tabdeeli se hisaab shdh Qaza plan badalta he';

  @override
  String get profileQazaReviewError =>
      'Qaza plan ka jaiza tiar nahi ho ska dobara koshish krin';

  @override
  String get profileQazaApplying => 'Qaza plan laagu ho raha hai…';

  @override
  String get profileQazaImpact => 'Asar';

  @override
  String profileQazaCount(String count) {
    return '$count Qaza';
  }

  @override
  String get profileQazaPreviousTotal => 'Pichla plan';

  @override
  String get profileQazaNewTotal => 'Naya plan';

  @override
  String get profileQazaCompletedInPlan => 'Nie plan mein mukammal shdh';

  @override
  String get profileQazaToAdd => 'Nayi Qaza jori jaye gi';

  @override
  String get profileQazaRestored => 'Pehle hatayi gayi Qaza bahal ki jaye gi';

  @override
  String get profileQazaUpdatedKeptExisting =>
      'Profile app date hogii mojodh Qaza record barqarar rhe';

  @override
  String get profileQazaNoLongerRequired =>
      'Woh zair iltawa Qaza jo ab darkar nahi';

  @override
  String get profileQazaKeepExisting => 'Mojodh Qaza record barqarar rakhein';

  @override
  String get profileQazaApply => 'Qaza plan laagu karein';

  @override
  String get profileQazaCompletedProtected =>
      'Mukammal shdh aur dasti tor par shamil ki gayi Qaza delete nahi hogi';

  @override
  String get profileQazaUpdated => 'Profile aur Qaza plan app date hogie';

  @override
  String profileQazaUpdatedCounts(int added, int removed) {
    return 'Profile aur Qaza plan app date hogie shamil ki gayi Qaza: $added hatayi gayi Qaza: $removed';
  }

  @override
  String get profileQazaUpdatedNoChange =>
      'Profile app date hogii Qaza plan mein koi tabdeeli nahi hoii';

  @override
  String get qazaReviewTitle => 'Apna Qaza plan dekhein';

  @override
  String get qazaReviewSubtitle =>
      'Qaza tracker mein shamil karne se pehle apni tafseelaat ka jaiza lin';

  @override
  String get qazaReviewTotal => 'Kal andaza Qaza Namazein';

  @override
  String get qazaReviewPeriod => 'Qaza ki muddat';

  @override
  String get qazaReviewBreakdown => 'Namaz waar tafseel';

  @override
  String get qazaReviewNote =>
      'Yeh aap ke Profile ki maloomat ki bunyad par Qaza Namazon ka andaza he';

  @override
  String get qazaReviewEdit => 'Apni tafseelaat mein tarmeem karein';

  @override
  String get qazaReviewAdd => 'Qaza ko mere tracker mein shamil karein';

  @override
  String get qazaReviewAdding => 'Qaza shamil ho rahi hai…';

  @override
  String get qazaReviewError => 'Qaza shamil nahi ho ski dobara koshish krin';

  @override
  String get profileErrorLanguage => 'Barah karam Zaban muntakhab krin';

  @override
  String get profileErrorGender => 'Barah karam apni jins muntakhab krin';

  @override
  String get profileErrorMadhab =>
      'Barah karam apna fiqhi maktab muntakhab krin';

  @override
  String get profileErrorDob => 'Barah karam durust tareekh paidaish darj krin';

  @override
  String get profileErrorPuberty =>
      'Muntakhab jins ke liye durust balughat ki umar muntakhab krin';

  @override
  String get profileErrorStartPraying =>
      'Barah karam Namaz shuru karne ki durust umar muntakhab krin';

  @override
  String get profileErrorWitr =>
      'Barah karam Witr ki durust tarteeb muntakhab krin';

  @override
  String get navPrayerTime => 'Auqat';

  @override
  String get prayerTimeTitle => 'Namaz ke auqat';

  @override
  String get prayerTimeLocation => 'Maqam';

  @override
  String get prayerTimeUseCurrentLocation => 'Mojodh maqam istemal karein';

  @override
  String get prayerTimeSelectCity => 'Shehar muntakhab karein';

  @override
  String get prayerTimeSelectCountry => 'Mulk muntakhab karein';

  @override
  String get prayerTimeSearchCity => 'Shehar talash karein';

  @override
  String get prayerTimeCurrentLocation => 'Mojodh maqam';

  @override
  String get prayerTimeSavedLocation => 'Mehfooz maqam';

  @override
  String get prayerTimeToday => 'Aaj';

  @override
  String get prayerTimeRestrictedTimes => 'Mehdood auqat';

  @override
  String get prayerTimeActive => 'Faal';

  @override
  String get prayerTimeLocationUnavailable => 'Maqam dstiab nahi';

  @override
  String get prayerTimeLocationPermission =>
      'Mojodh maqam istemal karne ke liye maqam ki ajazt darkar he';

  @override
  String get prayerTimeLocationServiceRequired =>
      'Mojodh maqam istemal karne ke liye location services ko on krna zaroori he';

  @override
  String get prayerTimeEnableLocation => 'Maqam on karein';

  @override
  String get prayerTimeSelectLocation => 'Apna maqam muntakhab karein';

  @override
  String get prayerTimeCalculationMethod => 'Hisaab ka tareeqa';

  @override
  String get prayerTimeAsrMethod => 'Asr ka tareeqa';

  @override
  String get prayerTimeHighLatitudeRule => 'Buland arz balad ka usool';

  @override
  String get prayerTimeAdjustments => 'Tadeelaat';

  @override
  String get prayerTime12Hour => '12 ghante';

  @override
  String get prayerTime24Hour => '24 ghante';

  @override
  String get prayerTimeStandard => 'Mayari';

  @override
  String get prayerTimeHanafi => 'Hanafi';

  @override
  String get prayerTimeAutomatic => 'Khudkar';

  @override
  String get prayerTimeMiddleOfTheNight => 'Nisf shab';

  @override
  String get prayerTimeSeventhOfTheNight => 'Raat ka satwan hissa';

  @override
  String get prayerTimeTwilightAngle => 'Shafaq ka zaviya';

  @override
  String get prayerTimeCustom => 'Hasb zaroorat';

  @override
  String get prayerTimeFajrAngle => 'Fajr ka zaviya';

  @override
  String get prayerTimeIshaAngle => 'Isha ka zaviya';

  @override
  String get prayerTimeSave => 'Mehfooz karein';

  @override
  String get prayerTimeCountry => 'Mulk';

  @override
  String get prayerTimeCity => 'Shehar';

  @override
  String get prayerTimeNoCities => 'Koi mutabiqat rakhne wala shehar nahi';

  @override
  String get prayerTimeSettings => 'Namaz ke auqat ki Settings';

  @override
  String get prayerTimeLocationData => 'Maqam ka Data';

  @override
  String get settingsLicensesSoftwareTitle =>
      'Open source soft ware ke license';

  @override
  String get settingsLicensesSoftwareSubtitle =>
      'Flutter pikijz mqami libraries aur shamil fonts';

  @override
  String get settingsLicensesGeoNamesTitle => 'GeoNames shehri Data';

  @override
  String get settingsLicensesGeoNamesSubtitle =>
      'Off line shehron aur maqamat ke Data ki nsbt';

  @override
  String get prayerTimeLocationDataAttribution =>
      'Shehri Data © GeoNames CC BY 4.0 ke tehat license yafta he';

  @override
  String get prayerTimeUpdated => 'App date';

  @override
  String get prayerTimeNoSchedule =>
      'Namaz ke auqat abhi tarteeb nahi diye gie';

  @override
  String get prayerTimeSetupTitle => 'Namaz ke auqat tarteeb din';

  @override
  String get prayerTimeSetupBody =>
      'Apna mojodh maqam istemal karein ya mulk aur shehar muntakhab krin maqam mehfooz hone ke baad yeh off line kam kare ga';

  @override
  String get prayerTimeRefresh => 'Maqam taaza karein';

  @override
  String prayerTimeEndsIn(String duration) {
    return 'Ikhtitam mein $duration';
  }

  @override
  String prayerTimeRemaining(String duration) {
    return 'Baqi waqt $duration';
  }

  @override
  String prayerTimeStartsIn(String duration) {
    return 'Shuru hone mein $duration';
  }

  @override
  String prayerTimeNextRestricted(String name) {
    return 'Agla: $name';
  }

  @override
  String prayerTimeUsingSavedLocation(String location) {
    return 'Aap ka mehfooz maqam istemal ho raha hai: $location';
  }

  @override
  String get prayerTimeAngleHint => 'Darjaat mein darj krin';

  @override
  String get prayerTimeAdjustmentMinutes => 'Minute';

  @override
  String get prayerTimeSunrise => 'Tlo aftab';

  @override
  String get prayerTimeZawal => 'Zawal';

  @override
  String get prayerTimeSunset => 'Ghrob aftab';

  @override
  String get prayerTimeFajr => 'Fajr';

  @override
  String get prayerTimeDhuhr => 'Zuhr';

  @override
  String get prayerTimeAsr => 'Asr';

  @override
  String get prayerTimeMaghrib => 'Maghrib';

  @override
  String get prayerTimeIsha => 'Isha';

  @override
  String get qiblaTitle => 'Qibla';

  @override
  String get qiblaDirection => 'Qibla ki simt';

  @override
  String get qiblaBearing => 'Qibla ka zaviya';

  @override
  String get qiblaFromTrueNorth => 'Haqeeqi shumal se';

  @override
  String get qiblaUnavailable => 'Qibla dstiab nahi';

  @override
  String get qiblaLocationRequired =>
      'Qibla maloom karne ke liye maqam muntakhab ya mehfooz krin';

  @override
  String get qiblaCompassBody =>
      'Phone ghmaiin teer qibla ki taraf Rehnumai kare ga';

  @override
  String get qiblaSensorUnavailableBody =>
      'Is aale mein compass sensor dstiab nhin is liye jamid qibla simt dikhayi ja rahi he';

  @override
  String get qiblaHeadingUnavailable =>
      'Compass ki simt aarzi tor par dstiab nhin';

  @override
  String get qiblaTurnToDirection => 'Phone ko is simt ghmaiin';

  @override
  String qiblaCompassAccuracy(String degrees) {
    return 'Compass ki durustagi ±$degrees°';
  }

  @override
  String get qiblaCalibrationHint =>
      'Compass ki durustagi kam he phone ko 8 ki shakal mein harkat de kar dobara calibrate krin';

  @override
  String get accountAutomaticBackup => 'Khudkar backup app';

  @override
  String get accountBackupStatusChecking =>
      'Backup app ki halat dekhi ja rahi hai…';

  @override
  String get accountBackupStatusDisabled => 'Khudkar backup app band hai';

  @override
  String accountBackupStatusBackedUp(Object timestamp) {
    return '✓ backup app mukammal · $timestamp';
  }

  @override
  String get accountBackupStatusBackingUp =>
      'Aap ki progress ka backup app liya ja raha hai…';

  @override
  String get accountBackupStatusPending => 'Backup app zair iltawa hai';

  @override
  String get accountBackupStatusWaitingConnection =>
      'Connection ka intezar hai';

  @override
  String get accountBackupStatusComplete => 'Backup app mukammal ho gaya';

  @override
  String accountBackupStatusCompletedAt(Object timestamp) {
    return '$timestamp';
  }

  @override
  String get accountBackupStatusWaitingConnectionMessage =>
      'Aap ka Qaza Data is device par mehfooz he';

  @override
  String get accountBackupStatusFailedTitle =>
      'Backup app mukammal nahi ho saka';

  @override
  String get accountBackupStatusFailedMessage =>
      'Aap ka Qaza Data is device par mehfooz he';

  @override
  String get accountBackupStatusAuthRequired =>
      'Google session bahal karne ki zaroorat he';

  @override
  String get accountBackupStatusSecurityRejected =>
      'Security tsdiq ne Cloud rasai mustarad kar di';

  @override
  String get accountBackupStatusNetwork =>
      'Internet connection maujood nhin connection bahal hone par backup app dobara jari hoga';

  @override
  String get accountBackupStatusCloudStateInvalid =>
      'Cloud backup app ki halat badal gayi he dobara koshish krin';

  @override
  String get accountBackupStatusFailedAutomaticRetry =>
      'Hm khudkar tor par dobara koshish karein ge';

  @override
  String get accountBackupStatusRetry => 'Dobara koshish karein';

  @override
  String get accountBackupStatusFailed =>
      'Backup app mukammal nahi ho ska hm khudkar tor par dobara koshish karein ge';

  @override
  String get startupProfileLoadErrorTitle => 'Mqami Profile load nahi ho saka';

  @override
  String get startupProfileLoadErrorMessage =>
      'Aap ki mqami astorij ko mehfooz tareeqe se parha nahi ja ska aap ka mojodh Qaza Data tabdeel nahi kya gia dobara koshish krin';

  @override
  String get qazaHistoryTitle => 'Qaza ki tareekh';

  @override
  String get qazaHistoryRecentAdditions => 'Haalya izafay';

  @override
  String get qazaHistoryRecentlyDeleted => 'Haal hi mein delete shdh';

  @override
  String get qazaHistoryNoAdditions => 'Abhi koi Qaza izafa maujood nhin';

  @override
  String get qazaHistoryNoRecentlyDeleted =>
      'Haal hi mein delete shdh koi Qaza nhin';

  @override
  String get qazaHistoryLoadMore => 'Mzid load karein';

  @override
  String get qazaHistoryOriginalDateUnavailable => 'Asal tareekh dstiab nahi';

  @override
  String get qazaHistoryDeletedQaza => 'Delete shdh Qaza';

  @override
  String qazaHistoryDeletedQazaCount(int count) {
    return '$count Qaza delete huin';
  }

  @override
  String get qazaHistoryRestore => 'Bahal karein';

  @override
  String qazaHistoryRestoreSuccess(int count) {
    return '$count Qaza bahal huin';
  }

  @override
  String qazaHistoryRestoreConflict(int restored, int skipped) {
    return '$restored bahal hoiin $skipped chhor di gayin';
  }

  @override
  String get qazaAdditionTitle => 'Qaza izafa';

  @override
  String get qazaAdditionNotFound => 'Yeh Qaza izafa nahi mil ska';

  @override
  String qazaAdditionRecordsCount(int count) {
    return '$count records';
  }

  @override
  String get qazaAdditionNoPrayers => 'Koi Namaz nahi';

  @override
  String get qazaAdditionViewRecords => 'Records dekhein';

  @override
  String get qazaAdditionMoreActions => 'Mzid iqdamat';

  @override
  String get qazaAdditionEdit => 'Izafay mein tarmeem';

  @override
  String get qazaAdditionDelete => 'Izafa delete karein';

  @override
  String get qazaAdditionDeleteConfirmTitle => 'Yeh Qaza izafa delete krin';

  @override
  String get qazaAdditionDeleteConfirmMessage =>
      'Sirf ghair tabdeel shdh zair iltawa records delete hon ge mukammal ya tabdeel shdh records mehfooz rahein ge';

  @override
  String get qazaAdditionDeletedNothing =>
      'Delete karne ke liye koi ahl record nahi mla mehfooz records barqarar hin';

  @override
  String qazaAdditionDeletedCount(int count) {
    return '$count Qaza delete huin';
  }

  @override
  String qazaAdditionRestoredCount(int count) {
    return '$count Qaza bahal huin';
  }

  @override
  String get qazaTrackerHistoryTooltip => 'Qaza ki tareekh';

  @override
  String get qazaTrackerAdditionProgress => 'Qaza izafay ki progress';

  @override
  String get qazaTrackerSelectionHint =>
      'Muntakhab ya ghair muntakhab karne ke liye touch krin';

  @override
  String get qazaTrackerSwipeHint =>
      'Tafseel dekhne ke liye tap krin mukammal karne ke liye dayein ya bayein swipe krin muntakhab karne ke liye der tak dbaiin';

  @override
  String get qazaMarkSelectedPendingTitle =>
      'Muntakhab Qaza ko zair iltawa krin';

  @override
  String qazaMarkSelectedPendingMessage(int count) {
    return '$count mukammal Qaza dobara zair iltawa ho jayein gi aur mukammal shdh shumar nahi hon gi';
  }

  @override
  String get qazaMarkAsPending => 'Zair iltawa karein';

  @override
  String qazaMarkAsPendingCount(int count) {
    return 'Zair iltawa karein ($count)';
  }

  @override
  String get qazaNoCompletedTitle => 'Koi mukammal Qaza nahi';

  @override
  String get qazaNoCompletedMessage => 'Mukammal Qaza yahan dikhayi din gi';

  @override
  String get qazaReturnedToPending => 'Qaza dobara zair iltawa ho gii';

  @override
  String get qazaSelectedPendingNothingChanged =>
      'Muntakhab Qaza mein koi tabdeeli nahi hoii';

  @override
  String get qazaCorrectionChanged =>
      'Yeh Qaza durust nahi ki ja saki kyunke yeh tabdeel ho gayi he';

  @override
  String get qazaFilter => 'Filter';

  @override
  String get qazaFiltersActive => 'Filter faal hin';

  @override
  String get qazaOriginalDateLabel => 'Qaza ki tareekh';

  @override
  String get qazaCompletedDateLabel => 'Mukammal hone ki tareekh';

  @override
  String get qazaFilterCompletedDateHelp =>
      'Mukammal hone ki tareekh ke mutabiq filter karein';

  @override
  String get qazaUndoCompletions => 'Mukammal Qaza wapas karein';

  @override
  String get qazaUndoSelected => 'Muntakhab wapas karein';

  @override
  String get qazaUndoAll => 'Sab wapas karein';

  @override
  String qazaUndoQazaCount(int count) {
    return '$count Qaza';
  }

  @override
  String get addQazaManageAddition => 'Is izafay ko munazzam karein';

  @override
  String qazaCompletionSingle(String prayer, String date) {
    return '$prayer ki qza $date mukammal ho gii';
  }

  @override
  String qazaCompletionMultiple(int count) {
    return '$count Qaza Namazein mukammal ho giin';
  }

  @override
  String qazaUndoSingle(String prayer, String date) {
    return '$prayer ki qza $date dobara baqi mein shamil ho gii';
  }

  @override
  String qazaUndoMultiple(int count) {
    return '$count Qaza Namazein dobara baqi mein shamil ho gayi hin';
  }

  @override
  String get qazaUndoExpired => 'Wapas karne ka 5 second ka waqt khtm ho gia';

  @override
  String get qazaUndoStaleBatch =>
      'Wapas karne ka yeh ikhtiyar ab dstiab nahi kyunke is ke baad aik naya Undo amal hua he';

  @override
  String get qazaUndoTargetChanged =>
      'Wapas karne ka ikhtiyar dstiab nahi kyunke Qaza record badal chuka ya delete ho chuka he';

  @override
  String get qazaUndoFailed =>
      'Qaza wapas nahi ho ski barah karam dobara koshish krin';

  @override
  String get qazaMarkAsPendingMessage =>
      'Yeh Qaza dobara zair iltawa ho jaye gi aur mukammal shdh shumar nahi hogi';

  @override
  String get commonDelete => 'Delete karein';

  @override
  String qazaRequestedSlots(int count) {
    return '$count matlooba jaghein';
  }

  @override
  String get qazaAdditionUpdated => 'Qaza ka izafa app date ho gaya';

  @override
  String qazaSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count muntakhab',
      one: '1 muntakhab',
    );
    return '$_temp0';
  }

  @override
  String dataImportRestored(int count) {
    return 'Backup app kamyabi se bahal ho gia $count Qaza record bahal kiye gie';
  }

  @override
  String dataImportRestoreSummary(
      int records, int accounts, int revision, String onboarding) {
    return 'Is backup app mein $records Qaza record aur $accounts mqami account hin\n\nBahal karne se is device ka mojodh mqami Data muntakhab backup app se badal jaye ga aap ki device shanakht isi device par barqarar rahe gi\n\nBackup app revision: $revision\nOn boarding: $onboarding';
  }

  @override
  String get dataImportOnboardingComplete => 'Mukammal';

  @override
  String get dataImportOnboardingIncomplete => 'Mukammal nahi';

  @override
  String get dataLocalOnlyNote =>
      'Sirf mqami backup ap aap ka Qaza Data isi device par rehta he jab tak aap usay wazeh tor par braamd na krin';

  @override
  String get cloudBackupTitle => 'Cloud backup app';

  @override
  String get cloudBackupDescription =>
      'Apni Qaza ki progress ka Google Drive app Data mein alg backup app mehfooz rkhin';

  @override
  String get cloudConnect => 'Google se munsalik karein';

  @override
  String get cloudDisconnect => 'Account munqati karein';

  @override
  String get cloudConnected => 'Munsalik';

  @override
  String get cloudNotConnected =>
      'Apni progress ka backup app rakhne ke liye Google account munsalik krin';

  @override
  String get cloudBackupNow => 'Abhi backup app karein';

  @override
  String get cloudAutomaticBackup => 'Khudkar backup app';

  @override
  String get cloudLastBackup => 'Aakhri kamyab backup app';

  @override
  String get cloudNeverBackedUp => 'Abhi tak backup app nahi hua';

  @override
  String get cloudBackupSucceeded => 'Cloud backup app/sync mukammal ho gia';

  @override
  String get cloudBackupUpToDate => 'Backup app pehle hi taaza trin he';

  @override
  String get cloudBackupConflictTitle => 'Tabdeeliyon mein farq mila';

  @override
  String get cloudBackupConflictMessage =>
      'Is device aur Google Drive par mukhtalif progress maujood he muntakhab karein keh kon sa Data rakhna he';

  @override
  String get cloudKeepLocal => 'Is device ki progress rakhein';

  @override
  String get cloudUseRemote => 'Google Drive se bahal karein';

  @override
  String get cloudKeepLocalConfirmTitle => 'Is device ki progress rkhin';

  @override
  String get cloudKeepLocalConfirmMessage =>
      'Is device ke Data se naya Cloud backup app banaya jaye ga mojodh remote backup app apni tareekh mein barqarar rahe ga';

  @override
  String get cloudUseRemoteConfirmTitle => 'Mqami progress tabdeel krin';

  @override
  String get cloudUseRemoteConfirmMessage =>
      'Mojodh mqami app Data Google Drive ke backup app se badal jaye ga pehle aik khufiya karda mqami recovery snap shot mehfooz kya jaye ga';

  @override
  String get cloudDisconnectConfirmTitle => 'Google munqati krin';

  @override
  String get cloudDisconnectConfirmMessage =>
      'Khudkar Cloud kam band kar dia jaye ga aap ka Qaza Data isi device par mehfooz rahe ga';

  @override
  String get cloudRecoveryAvailable =>
      'Pichle mqami Data ka mehfooz recovery snap shot dstiab he';

  @override
  String get cloudRecoverLocal => 'Pichla mqami Data bahal karein';

  @override
  String get cloudRecoveryConfirmTitle => 'Pichla mqami Data bahal krin';

  @override
  String get cloudRecoveryConfirmMessage =>
      'Mehfooz mqami snap shot is device ke mojodh app Data ki jgh le ga';

  @override
  String get cloudAutomaticBackupRequiresConnection =>
      'Khudkar backup app faal karne se pehle Google munsalik krin';

  @override
  String get cloudBackupWorking => 'Backup app ho raha hai…';

  @override
  String get cloudSetupChoiceTitle => 'Qaza Namaz mein khush aamdeed';

  @override
  String get cloudSetupChoiceDescription =>
      'Apni chhoti hui Namazon ka hisaab rakhein aur Qaza ki progress ko apni sahulat ke mutabiq munazzam krin aap ka record isi device par mehfooz rehta he mukhtalif dioaisz par backup app aur bahali ke liye aap ikhtiyari tor par Google istemal kar sakte hin';

  @override
  String get cloudSetupUseGoogle => 'Google ke saath jari rakhein';

  @override
  String get cloudSetupContinueLocal => 'Isi device par jari rakhein';

  @override
  String get cloudConnectionFailed =>
      'Google se rabta mukammal nahi ho ska dobara koshish karein ya mqami tor par jari rkhin';

  @override
  String get dailySalahTrackingTitle => "روزانہ نماز کا ریکارڈ";

  @override
  String get dailySalahTrackingEnableTitle => "روزانہ نماز کا ریکارڈ فعال کریں";

  @override
  String get dailySalahTrackingEnableSubtitle => "اپنی ادا کی گئی یا رہ جانے والی نمازیں درج کریں۔ غیر درج نماز کو خودکار طور پر قضا نہیں سمجھا جائے گا۔";

  @override
  String get dailySalahTrackingEnableAction => "فعال کریں";

  @override
  String get dailySalahTrackingPrayed => "ادا کی";

  @override
  String get dailySalahTrackingMissed => "رہ گئی";

  @override
  String get dailySalahTrackingUnrecorded => "درج نہیں";

  @override
  String get dailySalahTrackingConfirmMissedTitle => "نماز رہ جانے کے طور پر درج کریں؟";

  @override
  String get dailySalahTrackingConfirmMissedMessage => "اس نماز اور تاریخ کے لیے صرف اسی صورت میں قضا ریکارڈ بنے گا جب پہلے سے موجود نہ ہو۔";

  @override
  String get dailySalahTrackingUndoQaza => "ٹریکنگ سے بنا قضا ریکارڈ واپس کریں";

  @override
  String get dailySalahTrackingUndoTitle => "یہ قضا ریکارڈ حذف کریں؟";

  @override
  String get dailySalahTrackingUndoMessage => "صرف Daily Salah Tracking کا بنایا ہوا یہی قضا ریکارڈ حذف ہوگا، اور صرف اس وقت جب ابھی زیرِ التوا ہو۔";

  @override
  String get dailySalahTrackingPreviousDay => "پچھلا دن";

  @override
  String get dailySalahTrackingNextDay => "اگلا دن";

  @override
  String get dailySalahTrackingUndoUnavailable => "یہ قضا ریکارڈ اب زیرِ التوا نہیں، اس لیے اسے حذف نہیں کیا گیا۔";
}
