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
  String get navCalculator => 'کیلکولیٹر';

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
  String get progressNoRecords => 'ابھی کوئی ریکارڈ نہیں';

  @override
  String progressPercentCompleted(int percent) {
    return '$percent% مکمل';
  }

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
  String hijriDate(Object day, Object month, Object year) {
    return '$day $month $year ھ';
  }

  @override
  String get homeTitle => 'ہوم';

  @override
  String get homeNotificationsTooltip => 'اطلاعات';

  @override
  String get homeProfileTooltip => 'پروفائل';

  @override
  String get homeHeadingSetup => 'اپنا قضا سفر شروع کریں';

  @override
  String get homeHeadingPending => 'جاری رکھیں';

  @override
  String get homeHeadingCompleted => 'آپ کی تمام قضا مکمل ہے';

  @override
  String get homeSetupMessage =>
      'اندازہ لگائیں یا چھوٹی ہوئی نمازیں دستی طور پر شامل کریں تاکہ ان کا حساب رکھا جا سکے۔';

  @override
  String get homeCalculateQaza => 'قضا کا حساب لگائیں';

  @override
  String get homeCompleteQaza => 'قضا ادا کریں';

  @override
  String get homeAddNewQaza => 'نئی قضا شامل کریں';

  @override
  String get homeAddManually => 'دستی طور پر قضا شامل کریں';

  @override
  String get homeProgressTitle => 'آپ کی پیش رفت';

  @override
  String get homeProgressError =>
      'آپ کی قضا کی پیش رفت لوڈ نہیں ہو سکی۔ دوبارہ کوشش کے لیے نیچے کھینچیں۔';

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
  String get qazaLogsTooltip => 'ریکارڈ';

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
  String get calcAboutYouIntro =>
      'اپنی تاریخِ پیدائش اور بلوغت کی معلومات سے آغاز کریں۔ تاریخیں گریگورین کیلنڈر میں منتخب ہوتی ہیں؛ ہجری تاریخ ساتھ دکھائی جاتی ہے۔';

  @override
  String get calcDateOfBirth => 'تاریخِ پیدائش';

  @override
  String get calcSelectDate => 'تاریخ منتخب کریں';

  @override
  String get calcSelectDobHelp => 'اپنی تاریخِ پیدائش منتخب کریں';

  @override
  String get calcCurrentAge => 'موجودہ عمر';

  @override
  String calcAgeYears(int years) {
    return '$years سال';
  }

  @override
  String get calcBalighInformation => 'بلوغت کی معلومات';

  @override
  String get calcModeAge => 'عمر';

  @override
  String get calcModeExactDate => 'اصل تاریخ';

  @override
  String get calcBalighAgeLabel => 'بلوغت کی عمر (سال)';

  @override
  String get calcSelectExactDate => 'اصل تاریخ منتخب کریں';

  @override
  String get calcSelectBalighHelp => 'بلوغت کی اصل تاریخ منتخب کریں';

  @override
  String calcEstimatedBalighDate(String date) {
    return 'اندازاً بلوغت کی تاریخ: $date';
  }

  @override
  String calcExactBalighDate(String date) {
    return 'بلوغت کی اصل تاریخ: $date';
  }

  @override
  String get calcPrayerHistoryIntro =>
      'بتائیں کہ باقاعدہ نماز کب شروع ہوئی تاکہ ہم قضا کا دورانیہ نکال سکیں۔';

  @override
  String get calcRegularPrayerStart => 'باقاعدہ نماز کا آغاز';

  @override
  String get calcPrayerStartAgeLabel => 'باقاعدہ نماز شروع کرنے کی عمر (سال)';

  @override
  String get calcSelectPrayerStartHelp =>
      'نماز شروع کرنے کی اصل تاریخ منتخب کریں';

  @override
  String calcEstimatedPrayerStartDate(String date) {
    return 'اندازاً نماز کے آغاز کی تاریخ: $date';
  }

  @override
  String calcExactPrayerStartDate(String date) {
    return 'نماز کے آغاز کی اصل تاریخ: $date';
  }

  @override
  String get calcIncludeWitr => 'وتر الگ شمار کریں';

  @override
  String get calcIncludeWitrSubtitle =>
      'وتر کو پانچ فرض نمازوں سے الگ شمار کیا جاتا ہے۔';

  @override
  String get calcQazaPeriod => 'قضا کا دورانیہ';

  @override
  String get calcBalighDate => 'بلوغت کی تاریخ';

  @override
  String get calcPrayerStartDate => 'نماز کے آغاز کی تاریخ';

  @override
  String get calcCalendarPeriod => 'کیلنڈر دورانیہ';

  @override
  String calcPeriodValue(int years, int days) {
    return '$years سال • $days دن';
  }

  @override
  String get calcCompleteDatesPrompt =>
      'قضا کا دورانیہ نکالنے کے لیے درست تاریخیں مکمل کریں۔';

  @override
  String get calcNoResultPrompt =>
      'اپنا قضا تخمینہ دیکھنے کے لیے درست نماز دورانیہ نکالیں۔';

  @override
  String get calcElapsedDays => 'گزرے ہوئے دن';

  @override
  String get calcEstimatedPrayers => 'تخمینی نمازیں';

  @override
  String get calcPrayerBreakdown => 'نمازوں کی تفصیل';

  @override
  String get calcWitrNotIncluded =>
      'وتر شامل نہیں ہے۔ اسے نماز کی تاریخ والے مرحلے میں تبدیل کریں۔';

  @override
  String get calcEditAboutYou => 'آپ کے بارے میں ترمیم کریں';

  @override
  String get calcEditPrayerHistory => 'نماز کی تاریخ میں ترمیم کریں';

  @override
  String get calcPreflightErrorShort => 'موجودہ ریکارڈ کی جانچ نہیں ہو سکی۔';

  @override
  String get calcAddErrorShort => 'اندازہ شامل نہیں ہو سکا۔';

  @override
  String get calculatorTitle => 'کیلکولیٹر';

  @override
  String get calcStepAboutYou => 'آپ کے بارے میں';

  @override
  String get calcStepPrayerHistory => 'نماز کی تاریخ';

  @override
  String get calcStepResult => 'نتیجہ';

  @override
  String calcStepOf(int step) {
    return 'مرحلہ $step از 3';
  }

  @override
  String calcStepSemantics(int step, String name) {
    return 'مرحلہ $step: $name';
  }

  @override
  String get calcCalculate => 'حساب لگائیں';

  @override
  String get calcAddToTracker => 'ٹریکر میں شامل کریں';

  @override
  String get calcKeepAsEstimate => 'اندازے کے طور پر رکھیں';

  @override
  String get calcKeptAsEstimate => 'اندازے کے طور پر محفوظ';

  @override
  String get calcEstimated => 'اندازاً حساب';

  @override
  String get calcBasedOnExactDates => 'اصل تاریخوں کی بنیاد پر';

  @override
  String get calcPreflightTitle => 'قضا ٹریکر میں شامل کریں';

  @override
  String get calcCalculated => 'حساب شدہ';

  @override
  String get calcAlreadyRecorded => 'پہلے سے درج';

  @override
  String get calcAlreadyCompleted => 'پہلے سے مکمل';

  @override
  String get calcNewToAdd => 'نئی شامل کرنے کے لیے';

  @override
  String get calcExistingUntouched => 'موجودہ ریکارڈ کبھی تبدیل نہیں ہوتے۔';

  @override
  String calcAddCountToTracker(String count) {
    return '$count قضا ٹریکر میں شامل کریں';
  }

  @override
  String get calcEstimateAdded => 'اندازہ شامل ہو گیا';

  @override
  String calcEstimateAddedMessage(String count) {
    return '$count قضا ریکارڈ شامل کر دیے گئے۔ موجودہ ریکارڈ تبدیل نہیں ہوئے۔';
  }

  @override
  String calcPreflightError(String error) {
    return 'آپ کے موجودہ ریکارڈ کی جانچ نہیں ہو سکی: $error';
  }

  @override
  String calcAddError(String error) {
    return 'اندازہ شامل نہیں ہو سکا: $error';
  }

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
  String get notificationsOff => 'بند';

  @override
  String get notificationsTitle => 'اطلاعات';

  @override
  String get notificationsLoading => 'اطلاعات کی ترتیبات لوڈ ہو رہی ہیں…';

  @override
  String notificationsLoadError(String error) {
    return 'اطلاعات کی ترتیبات لوڈ نہیں ہو سکیں: $error';
  }

  @override
  String get notificationsTryAgain => 'دوبارہ کوشش کریں';

  @override
  String get notificationsDailyTitle => 'روزانہ قضا یاد دہانی';

  @override
  String get notificationsDailySubtitle =>
      'باقی قضا نمازیں جاری رکھنے کے لیے دن میں ایک نرم یاد دہانی حاصل کریں۔';

  @override
  String get notificationsDailyToggle => 'روزانہ یاد دہانی';

  @override
  String get notificationsReminderTime => 'یاد دہانی کا وقت';

  @override
  String get notificationsChooseTime => 'روزانہ یاد دہانی کا وقت منتخب کریں';

  @override
  String get notificationsEnableToChangeTime =>
      'وقت تبدیل کرنے کے لیے یاد دہانی فعال کریں';

  @override
  String notificationsEveryDayAt(String time) {
    return 'روزانہ $time بجے';
  }

  @override
  String get notificationsStatusHeading => 'یاد دہانی کی حالت';

  @override
  String get notificationsOffStatus => 'یاد دہانی بند ہے۔';

  @override
  String get notificationsPermissionRequired => 'اطلاعات کی اجازت درکار ہے۔';

  @override
  String get notificationsNoPending =>
      'کوئی قضا باقی نہیں۔ کوئی یاد دہانی مقرر نہیں۔';

  @override
  String notificationsScheduledAt(String time) {
    return 'روزانہ $time بجے مقرر ہے۔';
  }

  @override
  String notificationsOnAt(String time) {
    return 'فعال • $time';
  }

  @override
  String get notificationsOnPendingWait => 'فعال • قضا باقی ہونے پر شروع ہوگی';

  @override
  String get notificationsPermissionNeeded => 'اجازت درکار';

  @override
  String get notificationsAllowPrompt =>
      'اطلاعات کی اجازت دیں تاکہ ایپ آپ کو یاد دلا سکے۔';

  @override
  String get notificationsAllow => 'اجازت دیں';

  @override
  String get notificationsAllowed => 'اطلاعات کی اجازت ہے';

  @override
  String get notificationsDeviceCanDeliver =>
      'یہ ڈیوائس آپ کی یاد دہانی پہنچا سکتی ہے۔';

  @override
  String get notificationsBlocked => 'اطلاعات بند ہیں';

  @override
  String get notificationsBlockedDetail =>
      'اطلاعات بند ہیں۔ سسٹم کی ترتیبات میں اجازت دیں، پھر دوبارہ کوشش کریں۔';

  @override
  String get notificationsEnableInSettings =>
      'یاد دہانی استعمال کرنے کے لیے سسٹم کی ترتیبات میں اطلاعات فعال کریں۔';

  @override
  String get notificationsUnavailable => 'اطلاعات دستیاب نہیں';

  @override
  String get notificationsUnavailableDetail =>
      'اس ڈیوائس پر اطلاعات دستیاب نہیں ہیں۔';

  @override
  String get notificationsRestricted => 'اطلاعات محدود ہیں';

  @override
  String get notificationsRestrictedDetail =>
      'اس ڈیوائس پر اطلاعات کی ترسیل محدود ہے۔';

  @override
  String get notificationsEnableFailed =>
      'اس ڈیوائس پر اطلاعات فعال نہیں ہو سکیں۔';

  @override
  String get notificationsSendTest => 'آزمائشی اطلاع بھیجیں';

  @override
  String get notificationsSendTestSubtitle =>
      'ترسیل جانچنے کے لیے ابھی ایک اطلاع بھیجیں۔';

  @override
  String get notificationsTestSent => 'آزمائشی اطلاع بھیج دی گئی۔';

  @override
  String notificationsTestFailed(String error) {
    return 'آزمائشی اطلاع ناکام: $error';
  }

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
  String get accountTitle => 'اکاؤنٹ';

  @override
  String get accountSignInMethod => 'سائن اِن کا طریقہ';

  @override
  String get accountGoogleAuth => 'گوگل توثیق';

  @override
  String get accountSignedInWithGoogle => 'گوگل سے سائن اِن ہیں';

  @override
  String get accountStatus => 'اکاؤنٹ کی حالت';

  @override
  String get accountSignedIn => 'سائن اِن ہیں';

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
      'سائن آؤٹ کرنے پر آپ خوش آمدید اسکرین پر واپس آ جائیں گے۔ آپ کے محفوظ قضا ریکارڈ حذف نہیں ہوتے اور اگلی بار سائن اِن پر بحال ہو جائیں گے۔';

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
  String get addQazaGregorianNote =>
      'گریگورین تاریخ بنیاد ہے۔ ہر تاریخ اور نماز کا جوڑ ایک الگ قضا ریکارڈ ہے۔';

  @override
  String get addQazaAvailabilityNote =>
      'کوئی تاریخ صرف اسی صورت غیر فعال ہوتی ہے جب اس پر کوئی نماز باقی نہ رہے۔';

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
  String get addQazaPrayersLabel => 'نمازیں';

  @override
  String get addQazaPrayersPerDateLabel => 'فی تاریخ نمازیں';

  @override
  String get addQazaExistingLabel => 'پہلے سے موجود جوڑ';

  @override
  String get addQazaNewRecordsLabel => 'نئے ریکارڈ';

  @override
  String get addQazaNewQazaLabel => 'نئے قضا ریکارڈ';

  @override
  String get addQazaInProgress => 'قضا شامل ہو رہی ہے...';

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
    return '$rakats • ہر منتخب تاریخ پر پہلے سے درج یا ادا شدہ';
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
  String get completePrayerLabel => 'نماز';

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
  String get completeOldestSubtitle => 'سب سے پرانا باقی ریکارڈ';

  @override
  String get completeOriginalDate => 'اصل چھوٹنے کی تاریخ';

  @override
  String get completeTimestampNote => 'ادائیگی کا وقت الگ محفوظ کیا جاتا ہے۔';

  @override
  String get completeAction => 'سب سے پرانی قضا ادا کریں';

  @override
  String get completeInProgress => 'مکمل ہو رہا ہے...';

  @override
  String get completeOpenWorkspace => 'قضا ورک اسپیس کھولیں';

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
  String get logsTitle => 'ریکارڈ و پیش رفت';

  @override
  String get logsSectionTitle => 'قضا ریکارڈ';

  @override
  String get logsRefresh => 'ریکارڈ تازہ کریں';

  @override
  String get logsOrderNote =>
      'نئی اصل تاریخیں پہلے • ایک وقت میں 50 لوڈ ہوتے ہیں';

  @override
  String get logsScrollForMore => 'مزید تاریخ کے لیے اسکرول کریں';

  @override
  String get logsLoading => 'آپ کی تاریخ لوڈ ہو رہی ہے...';

  @override
  String get logsLoadError => 'آپ کی تاریخ لوڈ نہیں ہو سکی۔';

  @override
  String get logsRefreshError => 'تازہ ترین تاریخ حاصل نہیں ہو سکی۔';

  @override
  String logsLoadMoreError(String error) {
    return 'مزید تاریخ لوڈ نہیں ہو سکی: $error';
  }

  @override
  String get logsEmptyTitle => 'ابھی کوئی قضا ریکارڈ نہیں۔';

  @override
  String get logsEmptyMessage =>
      'آپ کے قضا ریکارڈ یہاں ترتیب وار دکھائی دیں گے۔';

  @override
  String get logsFilteredEmptyTitle => 'کوئی مماثل قضا ریکارڈ نہیں۔';

  @override
  String get logsFilteredEmptyMessage => 'فلٹرز تبدیل یا صاف کر کے دیکھیں۔';

  @override
  String get logsClearFilters => 'فلٹرز صاف کریں';

  @override
  String get logsFilterAllPrayers => 'تمام نمازیں';

  @override
  String get logsFilterStatus => 'حالت';

  @override
  String get logsFilterPrayer => 'نماز';

  @override
  String get logsFilterDate => 'اصل قضا تاریخ کے مطابق فلٹر کریں';

  @override
  String get logsOriginalDateLabel => 'اصل قضا تاریخ';

  @override
  String get logsProgressTitle => 'آپ کی پیش رفت';

  @override
  String get logsPrayerProgressTitle => 'نماز کے اعتبار سے پیش رفت';

  @override
  String get logsProgressError => 'پیش رفت کا خلاصہ لوڈ نہیں ہو سکا۔';

  @override
  String logsOriginalDateValue(String date) {
    return 'اصل قضا تاریخ: $date';
  }

  @override
  String logsCompletedValue(String timestamp) {
    return 'مکمل ہوئی: $timestamp';
  }

  @override
  String get logsStatusPending => 'حالت: باقی';

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
  String get knowledgeBaseEmptyTitle => 'کوئی مضمون نہیں ملا';

  @override
  String get knowledgeBaseEmptyMessage => 'کوئی اور تلاش یا زمرہ آزمائیں۔';

  @override
  String get knowledgeBaseLoadError => 'معلومات لوڈ نہیں ہو سکیں۔';

  @override
  String get knowledgeArticleTitle => 'مضمون';

  @override
  String get knowledgeArticleLanguage => 'مضمون کی زبان';

  @override
  String get knowledgeArticleReferences => 'حوالہ جات';

  @override
  String get knowledgeArticleRelated => 'متعلقہ مضامین';

  @override
  String get knowledgeArticleNotFound => 'مضمون نہیں ملا۔';

  @override
  String get notificationReminderTitle => 'قضا نماز یاد دہانی';

  @override
  String get notificationReminderBody =>
      'پابندی کے ساتھ اپنی قضا نمازیں ادا کرتے رہیں۔';

  @override
  String get notificationTestTitle => 'قضا نماز';

  @override
  String get notificationTestBody => 'آزمائشی اطلاع کامیابی سے موصول ہوئی۔';

  @override
  String get notificationChannelName => 'قضا روزانہ یاد دہانی';

  @override
  String get notificationChannelDescription =>
      'قضا نمازیں مکمل کرتے رہنے کی روزانہ یاد دہانی۔';

  @override
  String get settingsAccountSection => 'اکاؤنٹ';

  @override
  String get settingsAccountSubtitle =>
      'اپنے سائن اِن اور اکاؤنٹ کی تفصیلات سنبھالیں۔';

  @override
  String get settingsGoogleSignIn => 'گوگل سائن اِن';

  @override
  String get settingsPrayerSection => 'نماز';

  @override
  String get settingsPrayerSubtitle =>
      'قضا کیلکولیٹر میں استعمال ہونے والے اصول دیکھیں۔';

  @override
  String get settingsPrayerRules => 'نماز و فقہی اصول';

  @override
  String get settingsPrayerRulesSubtitle => 'حسابی طریقہ، بلوغت، وتر';

  @override
  String get settingsKnowledgeBaseSubtitle => 'مسائل و مغالطے دیکھیں';

  @override
  String get settingsNotificationsSubtitle =>
      'یاد دہانیاں اور اطلاعات کا شیڈول سنبھالیں۔';

  @override
  String get settingsNotificationsRowSubtitle => 'روزانہ یاد دہانی اور شیڈول';

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
  String get rulesCalculationMethod => 'حسابی طریقہ';

  @override
  String get rulesCalculationMethodSubtitle =>
      'اپنے حالات کے مطابق طریقہ منتخب کریں۔';

  @override
  String get rulesBaligh => 'بلوغت';

  @override
  String get rulesBalighSubtitle =>
      'منصوبہ بندی کے کیلکولیٹر میں استعمال ہوتا ہے۔';

  @override
  String get rulesWitr => 'وتر';

  @override
  String get rulesWitrSubtitle => 'وتر ایک مستقل نماز کے طور پر شمار ہوتی ہے۔';

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
  String get settingsTitle => 'ترتیبات';

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
}
