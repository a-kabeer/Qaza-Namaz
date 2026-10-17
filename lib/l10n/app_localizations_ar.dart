// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'قضاء الصلاة';

  @override
  String get navHome => 'الرئيسية';

  @override
  String get navQaza => 'قضاء';

  @override
  String get navKnowledge => 'الإرشاد';

  @override
  String get settingsRemindersSection => 'التذكيرات';

  @override
  String get settingsRemindersSubtitle => 'تذكير يومي بإكمال الصلوات الفائتة.';

  @override
  String get settingsBackupSection => 'البيانات والتخزين';

  @override
  String get settingsBackupSubtitle => 'المزامنة السحابية والتصدير والاستيراد.';

  @override
  String get navSettings => 'الإعدادات';

  @override
  String get prayerFajr => 'الفجر';

  @override
  String get prayerZuhr => 'الظهر';

  @override
  String get prayerAsr => 'العصر';

  @override
  String get prayerMaghrib => 'المغرب';

  @override
  String get prayerIsha => 'العشاء';

  @override
  String get prayerWitr => 'الوتر';

  @override
  String get statusPending => 'قيد الانتظار';

  @override
  String get statusCompleted => 'مكتملة';

  @override
  String get qazaSelectAllMatching => 'تحديد جميع النتائج المطابقة';

  @override
  String qazaSelectAllMatchingCapped(String count) {
    return 'تم تحديد أول $count من السجلات المطابقة.';
  }

  @override
  String qazaConfirmBulkTitle(String count) {
    return 'إكمال $count سجلًا؟';
  }

  @override
  String qazaConfirmBulkMessage(String count) {
    return 'سيتم وضع علامة الإكمال على $count من الصلوات المعلّقة. يمكنك التراجع مباشرة بعد ذلك، ولكن ليس لاحقًا.';
  }

  @override
  String get qazaConfirmBulkAction => 'إكمالها';

  @override
  String get errorNetwork =>
      'لا يوجد اتصال. حُفظت بيانات القضاء على هذا الجهاز وستتم مزامنتها عند عودة الاتصال.';

  @override
  String get errorTimeout =>
      'استغرقت العملية وقتًا طويلًا. حاول مرة أخرى بعد قليل.';

  @override
  String get errorPermission =>
      'يلزم منح الإذن لإتمام هذه العملية. افتح الإعدادات لمنحه.';

  @override
  String get errorAuthentication => 'يجب تسجيل الدخول أولًا.';

  @override
  String get errorValidation =>
      'البيانات المدخلة غير مقبولة. تحقق منها ثم حاول مرة أخرى.';

  @override
  String get errorMalformedData =>
      'هذا الملف ليس نسخة احتياطية صالحة أو أنه تالف.';

  @override
  String get errorStorage =>
      'تعذر حفظ التغيير على هذا الجهاز. أفرغ بعض المساحة ثم حاول مجددًا.';

  @override
  String get errorUnknown => 'حدث خطأ غير متوقع.';

  @override
  String get commonOpenSettings => 'فتح الإعدادات';

  @override
  String get qazaSortLabel => 'الترتيب';

  @override
  String get qazaSortOldestFirst => 'الأقدم أولًا';

  @override
  String get qazaSortNewestFirst => 'الأحدث أولًا';

  @override
  String get filterAll => 'الكل';

  @override
  String get commonRetry => 'إعادة المحاولة';

  @override
  String get commonTotal => 'الإجمالي';

  @override
  String get commonVersion => 'الإصدار';

  @override
  String get stateErrorTitle => 'حدث خطأ';

  @override
  String get prayerRakatFajr => 'الفجر • ركعتان فرض';

  @override
  String get prayerRakatZuhr => 'الظهر • أربع ركعات فرض';

  @override
  String get prayerRakatAsr => 'العصر • أربع ركعات فرض';

  @override
  String get prayerRakatMaghrib => 'المغرب • ثلاث ركعات فرض';

  @override
  String get prayerRakatIsha => 'العشاء • أربع ركعات فرض';

  @override
  String get prayerRakatWitr => 'الوتر • ثلاث ركعات واجبة';

  @override
  String get syncSettingUp => 'جارٍ الإعداد';

  @override
  String get syncSettingUpDetail => 'جارٍ تجهيز سجلات القضاء على هذا الجهاز.';

  @override
  String get syncRestoring => 'جارٍ الاستعادة';

  @override
  String get syncRestoringDetail =>
      'جارٍ استعادة سجلات القضاء المحفوظة إلى هذا الجهاز.';

  @override
  String get syncSynced => 'تمت المزامنة';

  @override
  String syncSyncedAt(String timestamp) {
    return 'تمت المزامنة • $timestamp';
  }

  @override
  String get syncSyncing => 'جارٍ المزامنة';

  @override
  String get syncSaved => 'تم الحفظ';

  @override
  String get syncSavedDetail =>
      'حُفظت تغييراتك على هذا الجهاز وستتم مزامنتها تلقائيًا.';

  @override
  String get syncErrorLabel => 'خطأ في المزامنة';

  @override
  String get syncErrorDetail =>
      'بياناتك محفوظة على هذا الجهاز. سنحاول المزامنة تلقائيًا.';

  @override
  String get commonClose => 'إغلاق';

  @override
  String get commonCancel => 'إلغاء';

  @override
  String get commonDone => 'تم';

  @override
  String get commonReset => 'إعادة تعيين';

  @override
  String get commonClear => 'مسح';

  @override
  String get commonBack => 'رجوع';

  @override
  String get commonContinue => 'متابعة';

  @override
  String get commonLoading => 'جارٍ التحميل...';

  @override
  String get commonToday => 'اليوم';

  @override
  String get commonYesterday => 'أمس';

  @override
  String hijriDate(Object day, Object month, Object year) {
    return '$day $month $year هـ';
  }

  @override
  String hijriDateShort(Object day, Object month) {
    return '$day $month';
  }

  @override
  String get hijriAdjustmentTitle => 'تعديل التاريخ الهجري';

  @override
  String get hijriAdjustmentEarlierTwo => 'قبل يومين';

  @override
  String get hijriAdjustmentEarlierOne => 'قبل يوم واحد';

  @override
  String get hijriAdjustmentNoChange => 'دون تعديل';

  @override
  String get hijriAdjustmentLaterOne => 'بعد يوم واحد';

  @override
  String get hijriAdjustmentLaterTwo => 'بعد يومين';

  @override
  String hijriMonthYear(Object month, Object year) {
    return '$month $year هـ';
  }

  @override
  String get hijriMonthMuharram => 'محرم';

  @override
  String get hijriMonthSafar => 'صفر';

  @override
  String get hijriMonthRabiAlAwwal => 'ربيع الأول';

  @override
  String get hijriMonthRabiAlThani => 'ربيع الآخر';

  @override
  String get hijriMonthJumadaAlAwwal => 'جمادى الأولى';

  @override
  String get hijriMonthJumadaAlThani => 'جمادى الآخرة';

  @override
  String get hijriMonthRajab => 'رجب';

  @override
  String get hijriMonthShaban => 'شعبان';

  @override
  String get hijriMonthRamadan => 'رمضان';

  @override
  String get hijriMonthShawwal => 'شوال';

  @override
  String get hijriMonthDhulQadah => 'ذو القعدة';

  @override
  String get hijriMonthDhulHijjah => 'ذو الحجة';

  @override
  String get homeTitle => 'الرئيسية';

  @override
  String get homeProfileTooltip => 'الملف الشخصي';

  @override
  String get homeHeadingSetup => 'ابدأ رحلتك مع قضاء الصلاة';

  @override
  String get homeHeadingPending => 'واصل التقدم';

  @override
  String get homeHeadingCompleted => 'أحسنت، لقد أكملت جميع الصلوات المسجلة';

  @override
  String get homeSetupMessage => 'لم تضف أي صلوات فائتة بعد.';

  @override
  String get homeCompleteQaza => 'إكمال القضاء';

  @override
  String get homeAddNewQaza => 'إضافة قضاء جديد';

  @override
  String get homeAddManually => 'إضافة قضاء يدويًا';

  @override
  String get homeStatTotal => 'الإجمالي';

  @override
  String get homeAddQaza => 'إضافة قضاء';

  @override
  String homeCompletedCount(int count) {
    return '$count مكتملة';
  }

  @override
  String get homeProgressTitle => 'تقدمك';

  @override
  String get homeProgressError =>
      'تعذر تحميل تقدمك في القضاء. اسحب لإعادة المحاولة.';

  @override
  String get homeTodayProgress => 'إنجاز اليوم';

  @override
  String homeDailyProgress(int completed, int target) {
    return 'تم إكمال $completed من أصل $target';
  }

  @override
  String homeDailyRemaining(int count) {
    return 'متبقٍ $count';
  }

  @override
  String get homeQazaPlan => 'خطة القضاء';

  @override
  String get homeCompleteOldestQaza => 'إكمال أقدم قضاء';

  @override
  String get homeAuto => 'تلقائي';

  @override
  String get homeAutoSequence => 'تسلسل تلقائي';

  @override
  String get homeQazaTarget => 'هدف القضاء';

  @override
  String get homePrayerSelection => 'اختيار الصلاة';

  @override
  String get homePrayerTimeUnavailable =>
      'اختيار وقت الصلاة غير متاح حتى إعداد مواقيت الصلاة.';

  @override
  String get homeQazaTargetReachedTitle => 'الحمد لله!';

  @override
  String get homeQazaTargetReachedMessage =>
      'لقد أكملت خطة القضاء لهذا اليوم.\nتقبل الله منك.';

  @override
  String get homeDailyTarget => 'الهدف اليومي';

  @override
  String homePerDay(int count) {
    return '$count يوميًا';
  }

  @override
  String homeEstimatedCompletion(String date) {
    return 'الإكمال المتوقع: $date';
  }

  @override
  String get homeNextQaza => 'القضاء التالي';

  @override
  String get homeCompleteNextQaza => 'إكمال القضاء التالي';

  @override
  String get homeViewAllQaza => 'عرض جميع الصلوات';

  @override
  String get homeDailyProgressError => 'تعذر تحميل تقدم اليوم.';

  @override
  String progressPendingCompleted(String pending, String completed) {
    return '$pending قيد الانتظار • $completed مكتملة';
  }

  @override
  String progressCompletedPending(String completed, String pending) {
    return '$completed مكتملة • $pending قيد الانتظار';
  }

  @override
  String get qazaTitle => 'القضاء';

  @override
  String get qazaProgressLabel => 'التقدم';

  @override
  String get qazaAddTooltip => 'إضافة قضاء';

  @override
  String get qazaDateFilterAny => 'التاريخ الأصلي: أي تاريخ';

  @override
  String get qazaDateFilterHelp => 'تصفية حسب تاريخ الصلاة الفائتة الأصلي';

  @override
  String qazaDateFilterRange(String from, String to) {
    return '$from — $to';
  }

  @override
  String get qazaLoading => 'جارٍ تحميل سجلات القضاء...';

  @override
  String get qazaEmptyTitle => 'لا توجد سجلات قضاء بعد';

  @override
  String get qazaEmptyMessage => 'أضف الصلوات الفائتة أو احسب تقديرًا للبدء.';

  @override
  String get qazaFilteredEmptyTitle => 'لا توجد سجلات تطابق هذه المرشحات';

  @override
  String get qazaFilteredEmptyMessage =>
      'جرّب حالة أو صلاة أو نطاقًا زمنيًا مختلفًا.';

  @override
  String get qazaResetFilters => 'إعادة ضبط المرشحات';

  @override
  String qazaLoadError(String error) {
    return 'تعذر تحميل سجلات القضاء: $error';
  }

  @override
  String qazaLoadMoreError(String error) {
    return 'تعذر تحميل المزيد من السجلات: $error';
  }

  @override
  String qazaCompleteError(String error) {
    return 'تعذر إكمال سجلات القضاء المحددة: $error';
  }

  @override
  String qazaCompletedOn(String date) {
    return 'تم الإكمال في $date';
  }

  @override
  String qazaCompleteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'إكمال $count من سجلات القضاء',
      one: 'إكمال قضاء واحد',
    );
    return '$_temp0';
  }

  @override
  String get qazaRecordActions => 'إجراءات السجل';

  @override
  String get qazaEditRecord => 'تعديل';

  @override
  String get qazaDeleteRecord => 'حذف';

  @override
  String get qazaEditRecordTitle => 'تعديل سجل القضاء';

  @override
  String get qazaEditPrayer => 'الصلاة';

  @override
  String get qazaEditDate => 'التاريخ الأصلي';

  @override
  String get qazaEditDateHelp => 'حدد التاريخ الأصلي للصلاة الفائتة';

  @override
  String get qazaSaveChanges => 'حفظ التغييرات';

  @override
  String get qazaDeleteRecordTitle => 'حذف سجل القضاء؟';

  @override
  String qazaDeleteRecordMessage(Object date, Object prayer) {
    return 'حذف سجل صلاة القضاء $prayer بتاريخ $date نهائيًا؟ لا يمكن التراجع عن ذلك.';
  }

  @override
  String get qazaRecordUpdated => 'تم تحديث سجل القضاء.';

  @override
  String qazaDuplicateRecord(Object date, Object prayer) {
    return 'يوجد بالفعل سجل قضاء للصلاة $prayer بتاريخ $date.';
  }

  @override
  String get qazaRecordUpdateFailed => 'تعذر تحديث سجل القضاء. حاول مرة أخرى.';

  @override
  String get qazaRecordDeleted => 'تم حذف سجل القضاء نهائيًا.';

  @override
  String get qazaRecordDeleteFailed => 'تعذر حذف سجل القضاء. حاول مرة أخرى.';

  @override
  String get qazaUndoAction => 'تراجع';

  @override
  String qazaUndoAvailable(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'يمكن التراجع عن إكمال السجلات الأخيرة.',
      one: 'يمكن التراجع عن إكمال السجل الأخير.',
    );
    return '$_temp0';
  }

  @override
  String qazaUndoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تمت استعادة $count سجلات قضاء.',
      one: 'تمت استعادة قضاء واحد.',
    );
    return '$_temp0';
  }

  @override
  String qazaCompletedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تم إكمال $count صلوات قضاء.',
      one: 'تم إكمال صلاة قضاء واحدة.',
      zero: 'لم يتم إكمال أي قضاء.',
    );
    return '$_temp0';
  }

  @override
  String get calendarSelectYear => 'اختر السنة';

  @override
  String get calendarSelectHint => 'اضغط على تاريخ متاح لتحديده.';

  @override
  String calendarSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تم تحديد $count تواريخ.',
      one: 'تم تحديد تاريخ واحد.',
    );
    return '$_temp0';
  }

  @override
  String get authTitle => 'تسجيل الدخول';

  @override
  String get authWelcomeBack => 'مرحبًا بعودتك';

  @override
  String get authSubtitle => 'سجّل الدخول لمتابعة استخدام متتبع قضاء الصلاة.';

  @override
  String get authContinueWithGoogle => 'المتابعة باستخدام Google';

  @override
  String get authSigningIn => 'جارٍ تسجيل الدخول...';

  @override
  String get authProviderNote =>
      'Google هو موفر تسجيل الدخول المتصل حاليًا. تتم استعادة حالة تسجيل الدخول تلقائيًا من Firebase.';

  @override
  String get authHelpTooltip => 'مساعدة تسجيل الدخول';

  @override
  String get authHelpTitle => 'تسجيل الدخول';

  @override
  String get authHelpBody =>
      'طريقة تسجيل الدخول المتاحة في هذا الإصدار هي Google. ترتبط بيانات القضاء بحساب Firebase الذي تستخدمه لتسجيل الدخول.';

  @override
  String get authDismiss => 'إغلاق';

  @override
  String get authFailed => 'تعذر تسجيل الدخول. حاول مرة أخرى.';

  @override
  String get welcomeTagline => 'العبادة والمواظبة على الصلاة';

  @override
  String get welcomeHeadline => 'تابع صلواتك الفائتة بوضوح وانتظام.';

  @override
  String get welcomeBody =>
      'سجّل صلوات القضاء وأكملها وتابع تقدمك، صلاةً بعد صلاة.';

  @override
  String get welcomeGetStarted => 'ابدأ الآن';

  @override
  String get welcomeSignIn => 'لديك حساب بالفعل؟ سجّل الدخول';

  @override
  String get splashTagline => 'مساحة هادئة للمواظبة على قضاء الصلاة';

  @override
  String get accountChoiceHeadline => 'حافظ على تقدمك في القضاء';

  @override
  String get accountChoiceDescription =>
      'سجّل الدخول باستخدام Google لنسخ تقدمك احتياطيًا واستعادته عبر الأجهزة.';

  @override
  String get accountChoiceContinueGoogle => 'المتابعة باستخدام Google';

  @override
  String get accountChoiceContinueGuest => 'المتابعة كضيف';

  @override
  String get accountChoiceGuestDescription =>
      'تظل بيانات الضيف على هذا الجهاز. يمكنك ربط Google لاحقًا.';

  @override
  String get accountChoiceGoogleFailed =>
      'تعذر إكمال تسجيل الدخول باستخدام Google. حاول مرة أخرى.';

  @override
  String get accountTitle => 'الحساب';

  @override
  String get accountProfileChecking => 'جارٍ التحقق من حساب Google…';

  @override
  String get accountProfileUnavailable => 'حالة حساب Google غير متاحة';

  @override
  String get accountProfileUnavailableDetail =>
      'ما زالت سجلات القضاء متاحة على هذا الجهاز.';

  @override
  String get accountGuest => 'ضيف';

  @override
  String get accountConnectGoogle => 'ربط حساب Google';

  @override
  String get accountSignInMethod => 'طريقة تسجيل الدخول';

  @override
  String get accountGoogleAuth => 'Google';

  @override
  String get accountSignedInWithGoogle => 'تم تسجيل الدخول باستخدام Google';

  @override
  String get accountStatus => 'حالة الحساب';

  @override
  String get accountSignedIn => 'محلي';

  @override
  String get accountRecordsRetained =>
      'ستبقى سجلات القضاء المحفوظة مخزنة، وستتم استعادتها بعد تسجيل الدخول التالي.';

  @override
  String get accountDeveloperContext => 'معلومات المطور';

  @override
  String get accountFirebaseUid => 'معرّف Firebase';

  @override
  String get accountNotAvailable => 'غير متاح';

  @override
  String get accountSignOut => 'تسجيل الخروج';

  @override
  String get accountSignOutPrompt => 'تسجيل الخروج؟';

  @override
  String get accountSignOutExplanation =>
      'سيؤدي تسجيل الخروج إلى فصل حساب Google. ستبقى بيانات القضاء على هذا الجهاز.';

  @override
  String get dataTitle => 'تصدير واستيراد';

  @override
  String get dataExportTitle => 'تصدير البيانات';

  @override
  String get dataExportBody =>
      'احفظ نسخة JSON من سجلات القضاء. لن يتم رفع أي بيانات عند التصدير.';

  @override
  String get dataExportAction => 'تصدير';

  @override
  String get dataExportDialogTitle => 'حفظ نسخة بيانات القضاء';

  @override
  String get dataExportSaved => 'تم حفظ التصدير بنجاح.';

  @override
  String get dataExportCanceled => 'تم إلغاء التصدير. لم تتغير بياناتك.';

  @override
  String get dataExportSignInRequired => 'سجّل الدخول قبل تصدير بيانات القضاء.';

  @override
  String dataExportFailed(String error) {
    return 'فشل التصدير: $error';
  }

  @override
  String get dataImportTitle => 'استيراد البيانات';

  @override
  String get dataImportBody =>
      'افتح ملف تصدير JSON، وتحقق من صحته، وراجع الدمج قبل تطبيقه على هذا الحساب.';

  @override
  String get dataImportAction => 'استيراد';

  @override
  String get dataImportReviewTitle => 'مراجعة استيراد البيانات';

  @override
  String get dataImportCanceled => 'تم إلغاء الاستيراد. لم تتغير بياناتك.';

  @override
  String get dataImportSignInRequired =>
      'سجّل الدخول قبل استيراد بيانات القضاء.';

  @override
  String get dataImportEmptyFile => 'الملف المحدد فارغ أو يتعذر قراءته.';

  @override
  String dataImportRejected(String error) {
    return 'تم رفض الاستيراد: $error\nلم يتم تطبيق أي استيراد جزئي.';
  }

  @override
  String dataImportComplete(int added, int completed, int unchanged) {
    return 'اكتمل الاستيراد: أُضيف $added، واكتمل $completed، ولم يتغير $unchanged.';
  }

  @override
  String get dataProcessing => 'جارٍ معالجة البيانات…';

  @override
  String get dataSafetyTitle => 'أمان البيانات';

  @override
  String get dataSafetyBody =>
      'لا يؤدي التصدير إلى حذف بيانات السحابة. ولا يمحو الاستيراد السجلات الحالية. وتسجيل الخروج لا يعني حذف البيانات، كما أن إزالة التطبيق لا تحذف السجلات السحابية.';

  @override
  String get dataRemapNote =>
      'تُربط البيانات المستوردة بالحساب الذي سجّل الدخول حاليًا. ثم تؤكد طبقة المزامنة المحلية أولًا التغييرات مع Firestore في الخلفية.';

  @override
  String get addQazaTitle => 'إضافة قضاء';

  @override
  String get addQazaStep1 => 'الخطوة 1 من 3 • تحديد التواريخ';

  @override
  String get addQazaStep2 => 'الخطوة 2 من 3 • تحديد الصلوات الفائتة';

  @override
  String get addQazaStep3 => 'الخطوة 3 من 3 • المراجعة والإضافة';

  @override
  String get addQazaModeSingle => 'مفرد';

  @override
  String get addQazaModeRange => 'نطاق';

  @override
  String get addQazaModeMultiple => 'متعدد';

  @override
  String get addQazaModeSingleTitle => 'تاريخ واحد';

  @override
  String get addQazaModeRangeTitle => 'نطاق زمني';

  @override
  String get addQazaModeMultipleTitle => 'تواريخ متعددة';

  @override
  String get addQazaChooseSingle => 'اختر تاريخًا';

  @override
  String get addQazaChooseRange => 'اختر نطاقًا زمنيًا';

  @override
  String get addQazaChooseMultiple => 'اختر تواريخ متعددة';

  @override
  String get addQazaAvailabilityNote =>
      'في وضع النطاق، يمكن تحديد التواريخ الصالحة حتى إذا لم يتبقَّ قضاء؛ وتضيف المراجعة الصلوات المؤهلة فقط.';

  @override
  String get addQazaStepNameDates => 'تحديد التواريخ';

  @override
  String get addQazaStepNamePrayers => 'الصلوات الفائتة';

  @override
  String get addQazaStepNameReview => 'مراجعة';

  @override
  String addQazaStepSemantics(int step, String name) {
    return 'الخطوة $step: $name';
  }

  @override
  String addQazaPartialAvailability(int available, int total) {
    return 'متاح في $available من أصل $total تواريخ';
  }

  @override
  String get addQazaAvailableEveryDate => 'متاح في جميع التواريخ المحددة';

  @override
  String get addQazaEligibleOnlyNote =>
      'تُضاف فقط مجموعات التاريخ والصلاة المؤهلة. ويتم تخطي أي سجل موجود مسبقًا.';

  @override
  String addQazaAddCount(String count) {
    return 'إضافة $count من سجلات القضاء';
  }

  @override
  String get addQazaNothingNew =>
      'لا توجد سجلات جديدة للإضافة؛ هذه المجموعات مسجلة بالفعل.';

  @override
  String get addQazaChecking => 'جارٍ التحقق من سجلاتك...';

  @override
  String get addQazaNextPrayers => 'التالي: المراجعة والإضافة';

  @override
  String get addQazaPrayersHeading => 'الصلوات الفائتة';

  @override
  String get addQazaSelectAll => 'تحديد الكل';

  @override
  String get addQazaAllSelected => 'تم تحديد الكل';

  @override
  String get addQazaReviewHeading => 'المراجعة والإضافة';

  @override
  String get addQazaReviewNote => 'راجع الملخص ثم أضف سجلات القضاء إلى سجلك.';

  @override
  String get addQazaCombinationNote =>
      'يُنشئ كل تاريخ مع كل صلاة سجلًا مستقلًا قيد الانتظار. ويتم تخطي المجموعات المسجلة مسبقًا تلقائيًا.';

  @override
  String get addQazaSelectionLabel => 'التحديد';

  @override
  String get addQazaDatesLabel => 'التواريخ';

  @override
  String get addQazaDateCountLabel => 'عدد التواريخ';

  @override
  String get addQazaDateRangeLabel => 'النطاق الزمني';

  @override
  String get addQazaCombinationCountLabel => 'عدد السجلات';

  @override
  String get addQazaPrayersLabel => 'الصلوات';

  @override
  String get addQazaPrayersPerDateLabel => 'الصلوات لكل تاريخ';

  @override
  String get addQazaExistingLabel => 'السجلات الموجودة';

  @override
  String get addQazaNewRecordsLabel => 'السجلات الجديدة';

  @override
  String get addQazaNewLabel => 'جديد';

  @override
  String get addQazaAlreadyAddedLabel => 'تمت إضافته';

  @override
  String get addQazaUnavailableLabel => 'غير متاح';

  @override
  String get addQazaTimeBlocked => 'متاح بعد انتهاء وقت الصلاة.';

  @override
  String get addQazaCancelledTitle => 'تم إلغاء إضافة القضاء';

  @override
  String get addQazaCancelledMessage =>
      'تم إلغاء الإضافة. تم الاحتفاظ بأي سجلات حُفظت بالفعل.';

  @override
  String get addQazaNewQazaLabel => 'سجلات قضاء جديدة';

  @override
  String get addQazaInProgress => 'جارٍ إضافة القضاء...';

  @override
  String get qazaImportAdded => 'تمت الإضافة';

  @override
  String get qazaImportSkipped => 'تم التخطي';

  @override
  String get addQazaCreatedTitle => 'تم إنشاء سجلات القضاء';

  @override
  String addQazaSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تم تحديد $count أيام • ما الصلوات التي فاتتك؟',
      one: 'تم تحديد يوم واحد • ما الصلوات التي فاتتك؟',
    );
    return '$_temp0';
  }

  @override
  String qazaHistorySelectedDates(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count تواريخ محددة',
      one: 'تاريخ واحد محدد',
    );
    return '$_temp0';
  }

  @override
  String qazaHistorySelectionScope(int prayers, int days) {
    return '$prayers صلوات · $days أيام';
  }

  @override
  String qazaHistoryProgressPercentage(int percent) {
    return '$percent٪';
  }

  @override
  String qazaHistoryTrackedRecords(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count سجلات متابَعة',
      one: 'سجل واحد متابع',
    );
    return '$_temp0';
  }

  @override
  String qazaHistoryAdded(String date) {
    return 'تمت الإضافة في $date';
  }

  @override
  String get qazaHistoryShowAllDates => 'عرض جميع التواريخ';

  @override
  String get qazaHistoryHideDates => 'إخفاء التواريخ';

  @override
  String get qazaHistoryDeletedStatus => 'محذوف';

  @override
  String get qazaHistoryNoDates => 'لا توجد تواريخ';

  @override
  String addQazaDateCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count تواريخ',
      one: 'تاريخ واحد',
    );
    return '$_temp0';
  }

  @override
  String addQazaCreatedMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تمت إضافة $count سجلات إلى سجلك.',
      one: 'تمت إضافة سجل واحد إلى سجلك.',
    );
    return '$_temp0';
  }

  @override
  String addQazaUnavailablePrayer(String rakats) {
    return '$rakats • مسجلة بالفعل أو تمت صلاتها أو لم ينتهِ وقتها بعد';
  }

  @override
  String get commonNone => 'لا شيء';

  @override
  String get completeTitle => 'إكمال القضاء';

  @override
  String get completeHeading => 'إكمال أقدم سجل معلّق';

  @override
  String get completeIntro =>
      'أكمل سجلًا واحدًا في كل مرة. بعد النجاح، سيظهر السجل التالي مباشرة.';

  @override
  String get completeLoading => 'جارٍ تحميل السجل المعلّق...';

  @override
  String get completeLoadError => 'تعذر تحميل سجل القضاء.';

  @override
  String get completeNoPendingTitle => 'لا يوجد قضاء معلّق لهذه الصلاة.';

  @override
  String get completeNoPendingMessage =>
      'اختر صلاة أخرى أو أضف سجل قضاء أولًا.';

  @override
  String get completeOldestSubtitle => 'أقدم سجل معلّق';

  @override
  String get completeOriginalDate => 'التاريخ الأصلي للصلاة الفائتة';

  @override
  String get completeTimestampNote => 'يُسجّل وقت الإكمال بشكل منفصل.';

  @override
  String get completeAction => 'إكمال القضاء المعلّق';

  @override
  String get completeInProgress => 'جارٍ الإكمال...';

  @override
  String get completeFailed => 'تعذر إكمال القضاء. حاول مرة أخرى.';

  @override
  String completePrayerQaza(String prayer) {
    return 'قضاء $prayer';
  }

  @override
  String completeSuccess(String prayer) {
    return 'تم إكمال قضاء $prayer بنجاح.';
  }

  @override
  String completeSuccessNext(String prayer) {
    return 'اكتمل قضاء $prayer • السجل التالي جاهز.';
  }

  @override
  String get knowledgeBaseTitle => 'إرشادات الصلاة والقضاء';

  @override
  String get knowledgeBaseSearchHint =>
      'ابحث في أحكام الصلاة والمفاهيم الخاطئة';

  @override
  String get knowledgeBaseClearSearch => 'مسح البحث';

  @override
  String get knowledgeCategoryMasail => 'المسائل';

  @override
  String get knowledgeCategoryMugalat => 'المغالطات';

  @override
  String get knowledgeBaseTopicAll => 'كل الموضوعات';

  @override
  String get knowledgeTopicBasic => 'الأساسيات';

  @override
  String get knowledgeTopicPrayerUnits => 'ركعات الصلاة';

  @override
  String get knowledgeTopicSleepForgetfulness => 'النوم والنسيان';

  @override
  String get knowledgeTopicIntentionalOmission => 'الترك المتعمد';

  @override
  String get knowledgeTopicFriday => 'الجمعة';

  @override
  String get knowledgeTopicMenstruation => 'الحيض';

  @override
  String get knowledgeTopicNifas => 'النفاس';

  @override
  String get knowledgeTopicMenstruationNifas => 'الحيض والنفاس';

  @override
  String get knowledgeTopicMisconceptions => 'المفاهيم الخاطئة';

  @override
  String get knowledgeBaseEmptyTitle => 'لم يتم العثور على مقالات إرشادية';

  @override
  String get knowledgeBaseEmptyMessage =>
      'جرّب البحث بكلمة أخرى أو اختر موضوعًا مختلفًا.';

  @override
  String get knowledgeBaseLoadError => 'تعذر تحميل إرشادات الصلاة.';

  @override
  String get knowledgeBaseLanguage => 'لغة الإرشادات';

  @override
  String get knowledgeArticleTitle => 'مقال';

  @override
  String get knowledgeArticleReferences => 'المراجع';

  @override
  String get knowledgeArticleRelated => 'مقالات ذات صلة';

  @override
  String get knowledgeArticleNotFound => 'لم يتم العثور على المقال.';

  @override
  String get settingsAccountSection => 'الحساب';

  @override
  String get settingsAccountSubtitle => 'إدارة تسجيل الدخول وتفاصيل الحساب.';

  @override
  String get settingsGoogleSignIn => 'تسجيل الدخول باستخدام Google';

  @override
  String get settingsKnowledgeBaseSubtitle =>
      'تصفّح أحكام الصلاة والمفاهيم الخاطئة الشائعة.';

  @override
  String get settingsDataSection => 'البيانات والتخزين';

  @override
  String get settingsDataSubtitle =>
      'مزامنة بيانات القضاء ونسخها احتياطيًا وتصديرها واستيرادها.';

  @override
  String get settingsDataCloud => 'البيانات والسحابة';

  @override
  String get settingsDataCloudSubtitle => 'حالة المزامنة والتصدير والاستيراد';

  @override
  String get settingsResetCounterTitle => 'إعادة تعيين عداد القضاء';

  @override
  String get settingsResetCounterSubtitle =>
      'احذف جميع سجلات القضاء وابدأ العد من الصفر.';

  @override
  String get settingsResetCounterEmpty => 'لا توجد سجلات قضاء لإعادة تعيينها.';

  @override
  String get settingsResetCounterDialogTitle => 'إعادة تعيين عداد القضاء؟';

  @override
  String get settingsResetCounterDialogMessage =>
      'سيؤدي هذا إلى حذف جميع سجلات القضاء في هذا الحساب نهائيًا، المعلّقة والمكتملة، من هذا الجهاز ومن النسخة الاحتياطية السحابية.\n\nسيعود العداد إلى الصفر وستفقد تقدم الإكمال الذي حققته. لا يمكن التراجع عن ذلك. صدّر بياناتك أولًا إذا كنت قد تحتاج إليها لاحقًا.';

  @override
  String settingsResetCounterAcknowledge(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'أفهم أنه سيتم حذف $count سجلات قضاء نهائيًا',
      one: 'أفهم أنه سيتم حذف سجل قضاء واحد نهائيًا',
    );
    return '$_temp0';
  }

  @override
  String get settingsResetCounterConfirm => 'إعادة تعيين العداد';

  @override
  String get settingsResetCounterDone => 'تمت إعادة تعيين عداد القضاء.';

  @override
  String settingsResetCounterFailed(String error) {
    return 'تعذرت إعادة تعيين عداد القضاء: $error';
  }

  @override
  String get authContinueAsGuest => 'المتابعة كضيف';

  @override
  String get authGuestNote =>
      'يمكنك تسجيل الدخول باستخدام Google لاحقًا للاحتفاظ بتقدمك وربطه بحسابك.';

  @override
  String get backupPromptTitle => 'حافظ على تقدمك';

  @override
  String get backupPromptBody =>
      'سجّل الدخول باستخدام Google للاحتفاظ بتقدمك في القضاء وربطه بحسابك.';

  @override
  String get backupPromptConfirm => 'المتابعة باستخدام Google';

  @override
  String get backupPromptDismiss => 'ليس الآن';

  @override
  String get settingsBackupSignIn => 'النسخ الاحتياطي / تسجيل الدخول';

  @override
  String get settingsBackupSignInSubtitle =>
      'أنت تستخدم التطبيق كضيف. سجّل الدخول لنسخ بيانات القضاء احتياطيًا.';

  @override
  String get backupSignInFailed =>
      'فشل تسجيل الدخول. ما زال تقدمك محفوظًا على هذا الجهاز.';

  @override
  String get backupSignInCancelled =>
      'تم إلغاء تسجيل الدخول. ما زال تقدمك محفوظًا على هذا الجهاز.';

  @override
  String backupSignInFailedReason(String reason) {
    return 'فشل تسجيل الدخول: $reason ما زال تقدمك محفوظًا على هذا الجهاز.';
  }

  @override
  String backupMigrationDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تم تسجيل الدخول. أصبح تقدمك في القضاء مرتبطًا بحسابك.',
      one: 'تم تسجيل الدخول. أصبح تقدمك في القضاء مرتبطًا بحسابك.',
      zero: 'تم تسجيل الدخول. أصبح تقدمك في القضاء مرتبطًا بحسابك.',
    );
    return '$_temp0';
  }

  @override
  String get settingsAboutSection => 'حول التطبيق';

  @override
  String get settingsAboutSubtitle => 'معلومات التطبيق وإصدار البرنامج.';

  @override
  String settingsAboutRowSubtitle(String version) {
    return 'قضاء الصلاة • الإصدار $version';
  }

  @override
  String get settingsAppDescription => 'متتبع قضاء الصلاة';

  @override
  String get cloudSyncTitle => 'المزامنة السحابية';

  @override
  String get cloudSyncNow => 'المزامنة الآن';

  @override
  String get cloudPendingChanges => 'التغييرات المعلّقة';

  @override
  String get cloudLastSynced => 'آخر مزامنة';

  @override
  String get cloudExportImportSubtitle =>
      'نسخة احتياطية واستعادة آمنة بصيغة JSON تحت تحكم المستخدم. لا تُحذف بيانات السحابة عند استخدام هذه الإجراءات.';

  @override
  String get cloudInactive => 'التخزين دون اتصال غير نشط في هذا الإصدار.';

  @override
  String get cloudBootstrapping => 'جارٍ إعداد سجلات القضاء على هذا الجهاز…';

  @override
  String get cloudHydrating =>
      'جارٍ استعادة سجلات القضاء المحفوظة إلى هذا الجهاز…';

  @override
  String get cloudSynced => 'تم حفظ جميع سجلات القضاء في السحابة.';

  @override
  String get cloudSyncing => 'جارٍ مزامنة السجل…';

  @override
  String get cloudOffline =>
      'دون اتصال — تُحفظ السجلات على هذا الجهاز وتتم مزامنتها تلقائيًا.';

  @override
  String cloudPendingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'هناك $count تغييرات بانتظار المزامنة.',
      one: 'هناك تغيير واحد بانتظار المزامنة.',
    );
    return '$_temp0';
  }

  @override
  String get cloudSyncProblem =>
      'مشكلة في المزامنة — بياناتك آمنة على هذا الجهاز.';

  @override
  String get cloudQazaCount => 'عدد سجلات القضاء';

  @override
  String cloudQazaCountValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count سجلات قضاء',
      one: 'سجل قضاء واحد',
      zero: 'لا توجد سجلات قضاء',
    );
    return '$_temp0';
  }

  @override
  String get cloudBackupStatus => 'النسخة الاحتياطية السحابية';

  @override
  String get cloudBackupDeleted =>
      'حُذفت النسخة السحابية؛ وما زالت السجلات المحلية محفوظة.';

  @override
  String get cloudLocalVsCloudTitle => 'البيانات المحلية والسحابية';

  @override
  String get cloudLocalVsCloudBody =>
      'تُخزّن سجلات القضاء محليًا لتكون متاحة دون اتصال. عند تسجيل الدخول، يمكن مزامنة التغييرات مع حسابك السحابي الخاص. التصدير نسخة احتياطية محلية، وحذف بيانات السحابة لا يحذف سجلاتك المحلية.';

  @override
  String get cloudDeleteTitle => 'حذف البيانات السحابية';

  @override
  String get cloudDeleteBody =>
      'سيؤدي هذا إلى حذف سجلات القضاء من حسابك السحابي نهائيًا. ستبقى السجلات المحلية على هذا الجهاز. لا يمكن التراجع عن ذلك. صدّر بياناتك أولًا إذا كنت قد تحتاج إلى نسخة احتياطية.';

  @override
  String get cloudDeleteAcknowledge =>
      'أفهم أن النسخة السحابية ستُحذف نهائيًا.';

  @override
  String get cloudDeleteAction => 'حذف البيانات السحابية';

  @override
  String get cloudDeleteDone =>
      'تم حذف بيانات القضاء السحابية. ما زالت سجلاتك المحلية على هذا الجهاز.';

  @override
  String get cloudDeleteFailed =>
      'تعذر حذف البيانات السحابية. ما زالت سجلاتك المحلية آمنة.';

  @override
  String get cloudDeleteSignInRequired =>
      'سجّل الدخول لإدارة البيانات السحابية.';

  @override
  String get accountGoogle => 'حساب Google';

  @override
  String get accountCloudBackup => 'النسخ الاحتياطي السحابي';

  @override
  String get accountAutomatic => 'تلقائي';

  @override
  String get accountBackupPaused => 'تم إيقاف النسخ الاحتياطي مؤقتًا';

  @override
  String get accountEnableBackup => 'تفعيل النسخ الاحتياطي';

  @override
  String get accountDisconnect => 'فصل Google';

  @override
  String get accountDeleteCloudData => 'حذف البيانات السحابية';

  @override
  String get accountDeleteCloudDataMessage =>
      'سيتم حذف نسختك السحابية نهائيًا. ستبقى بيانات القضاء على هذا الجهاز.';

  @override
  String get accountDeleteCloudDataAcknowledge =>
      'أفهم أن النسخة السحابية ستُحذف نهائيًا.';

  @override
  String get accountCancel => 'إلغاء';

  @override
  String get accountContinue => 'متابعة';

  @override
  String get accountGuestTitle => 'هذا الجهاز';

  @override
  String get accountGuestLocalDataSubtitle => 'بياناتك محفوظة على هذا الجهاز';

  @override
  String get accountNotConnectedGoogle => 'Google غير متصل';

  @override
  String get accountKeepProgressSafe => 'حافظ على تقدمك';

  @override
  String get accountKeepProgressSafeDescription =>
      'اربط حساب Google لنسخ تقدمك في القضاء احتياطيًا واستعادته عبر الأجهزة.';

  @override
  String get accountGuestContinueMessage =>
      'سيبقى تقدمك المحلي على هذا الجهاز.';

  @override
  String get accountBackupSection => 'النسخ الاحتياطي';

  @override
  String get accountBackupAutomaticDescription =>
      'نسخ تقدمك في القضاء احتياطيًا تلقائيًا';

  @override
  String get accountAccountActions => 'إجراءات الحساب';

  @override
  String get accountSignOutDescription =>
      'سجّل الخروج من حساب Google. يمكنك تسجيل الدخول مجددًا لاحقًا.';

  @override
  String get accountDisconnectDescription =>
      'أزل اتصال Google من قضاء الصلاة وانتقل إلى وضع الضيف.';

  @override
  String get accountDangerZone => 'منطقة الإجراءات الخطرة';

  @override
  String get settingsAccountGuestSubtitle => 'محلي • هذا الجهاز فقط';

  @override
  String get settingsAccountGoogleSubtitle => 'تم تسجيل الدخول باستخدام Google';

  @override
  String get accountConnectFailed =>
      'تعذر إكمال الاتصال بـ Google. ما زالت بياناتك المحلية آمنة.';

  @override
  String get accountCloudDeleted =>
      'تم حذف البيانات السحابية. ما زالت بيانات القضاء المحلية على هذا الجهاز.';

  @override
  String get settingsTitle => 'الإعدادات';

  @override
  String get settingsPreferences => 'التفضيلات';

  @override
  String get settingsPreferencesSubtitle => 'إعدادات اللغة والمظهر.';

  @override
  String get settingsAppearance => 'المظهر';

  @override
  String get settingsAppearanceSubtitle => 'اختر مظهر التطبيق على هذا الجهاز.';

  @override
  String get settingsThemeSystem => 'حسب النظام';

  @override
  String get settingsThemeLight => 'فاتح';

  @override
  String get settingsThemeDark => 'داكن';

  @override
  String get settingsLanguage => 'اللغة';

  @override
  String get settingsLanguageSubtitle => 'اختر اللغة المستخدمة في التطبيق.';

  @override
  String get settingsLanguageNote =>
      'تتبع أسماء الصلوات والتواريخ الهجرية اللغة المختارة. وتُعرض العربية من اليمين إلى اليسار.';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageUrdu => 'اردو';

  @override
  String get homeTodayProgressHeader => 'إنجاز اليوم';

  @override
  String get homeNextQazaCurrentPrayer => 'القضاء التالي (الصلاة الحالية)';

  @override
  String get homeOldestPending => 'أقدم قضاء معلّق';

  @override
  String get homeOverallQaza => 'إجمالي القضاء';

  @override
  String get homePendingByPrayer => 'القضاء المعلّق حسب الصلاة';

  @override
  String get homePrayerBreakdown => 'تفصيل الصلوات';

  @override
  String get homeViewDetails => 'عرض التفاصيل';

  @override
  String get homeViewAll => 'عرض الكل';

  @override
  String get homeCompleted => 'مكتمل';

  @override
  String get homePending => 'معلّق';

  @override
  String get homeDetailedStatistics => 'عرض الإحصاءات التفصيلية';

  @override
  String get homeDetailedStatisticsSubtitle => 'الإكمال الإجمالي وحسب كل صلاة';

  @override
  String get homeQazaActivity => 'نشاط القضاء';

  @override
  String get homeProgressHistory => 'سجل التقدم';

  @override
  String get homeRangeWeekly => 'أسبوعي';

  @override
  String get homeRangeMonthly => 'شهري';

  @override
  String get homeRangeYearly => 'سنوي';

  @override
  String get homeWeeklyTargetLabel => 'الهدف الأسبوعي';

  @override
  String get homeMonthlyTarget => 'الهدف الشهري';

  @override
  String get homeProgressLabel => 'التقدم';

  @override
  String get homeActiveDays => 'الأيام النشطة';

  @override
  String get homeActiveMonths => 'الأشهر النشطة';

  @override
  String get homeGoalReached => 'تم تحقيق الهدف';

  @override
  String get homeRemaining => 'المتبقي';

  @override
  String get homeActual => 'الفعلي';

  @override
  String get homeNoActivity => 'لم يكتمل أي قضاء خلال هذه الفترة.';

  @override
  String get homeSelectDay => 'اضغط على يوم لعرض التفاصيل.';

  @override
  String get homePreviousWeek => 'الأسبوع السابق';

  @override
  String get homeNextWeek => 'الأسبوع التالي';

  @override
  String get homePreviousMonth => 'الشهر السابق';

  @override
  String get homeNextMonth => 'الشهر التالي';

  @override
  String get homePreviousYear => 'السنة السابقة';

  @override
  String get homeNextYear => 'السنة التالية';

  @override
  String get homeFutureDay => 'المستقبل';

  @override
  String get homeDailyGoalsTitle => 'أهدافك اليومية';

  @override
  String get homeLastSevenDays => 'آخر 7 أيام';

  @override
  String get homeGoalsAchieved => 'تم تحقيقه';

  @override
  String get homeWeeklyTarget => 'هدفك الأسبوعي';

  @override
  String homeWeeklyTargetProgress(int completed, int target) {
    return '$completed من $target';
  }

  @override
  String get homeDayActivityDetails => 'تفاصيل اليوم';

  @override
  String get homeTodayDate => 'اليوم';

  @override
  String homeCurrentPrayerLabel(String prayer) {
    return 'الصلاة الحالية: $prayer';
  }

  @override
  String get profileLanguageTitle => 'اختر لغتك';

  @override
  String get profileLanguageIntro =>
      'اختر اللغة التي تريد استخدامها في التطبيق.';

  @override
  String get profileSetupTitle => 'إعداد ملفك الشخصي';

  @override
  String get profileTitle => 'الملف الشخصي';

  @override
  String get profileIntro =>
      'تُستخدم هذه التفاصيل لتخصيص خطة القضاء وتطبيق أحكام الصلاة ذات الصلة.';

  @override
  String get profileSettingsSubtitle => 'إعدادات ملف الصلاة وخطة القضاء.';

  @override
  String get profileGender => 'الجنس';

  @override
  String get profileMale => 'ذكر';

  @override
  String get profileFemale => 'أنثى';

  @override
  String get profileMadhab => 'المذهب الفقهي';

  @override
  String get profileHanafi => 'حنفي';

  @override
  String get profileShafi => 'شافعي';

  @override
  String get profileMaliki => 'مالكي';

  @override
  String get profileHanbali => 'حنبلي';

  @override
  String get profileOther => 'آخر';

  @override
  String get profileDateOfBirth => 'تاريخ الميلاد';

  @override
  String get profileDobDay => 'اليوم';

  @override
  String get profileDobMonth => 'الشهر';

  @override
  String get profileDobYear => 'السنة';

  @override
  String get profileSelectDate => 'اختر التاريخ';

  @override
  String get profileSelectDobHelp => 'حدد تاريخ ميلادك';

  @override
  String get profileHijriHint =>
      'سيظهر التاريخ الهجري بعد تحديد التاريخ الميلادي.';

  @override
  String get profilePubertyAge => 'سن البلوغ';

  @override
  String get profileStartPrayingAge => 'العمر عند بدء الصلاة';

  @override
  String get profileSelectGenderFirst => 'حدد الجنس أولًا';

  @override
  String get profileSelectPubertyFirst => 'حدد سن البلوغ أولًا';

  @override
  String get profileSelectDobFirst => 'حدد تاريخ الميلاد أولًا';

  @override
  String get profileWitr => 'الوتر';

  @override
  String get profileWitrOptional =>
      'عند اختيار «آخر»، يمكنك تحديد ما إذا كان الوتر ضمن الخطة.';

  @override
  String get profileWitrIncluded => 'مشمول';

  @override
  String get profileWitrExcluded => 'غير مشمول';

  @override
  String get profileSubmit => 'متابعة';

  @override
  String get profileSave => 'حفظ التغييرات';

  @override
  String get profileEdit => 'تعديل الملف الشخصي';

  @override
  String profileAgeYears(int count) {
    return '$count سنة';
  }

  @override
  String get profileDiscardChangesTitle => 'تجاهل التغييرات غير المحفوظة؟';

  @override
  String get profileDiscardChangesMessage =>
      'لم تُحفظ تعديلاتك. هل تريد تجاهلها والخروج من وضع التعديل؟';

  @override
  String get profileDiscardChangesAction => 'تجاهل التغييرات';

  @override
  String get profileQazaAssumptionsChanged =>
      'القيم التي يتم تغييرها في الملف الشخصي';

  @override
  String get profileQazaAssumptionsHint =>
      'راجع القيم السابقة والجديدة قبل تطبيق خطة القضاء هذه.';

  @override
  String get profileQazaPlanChangedTitle => 'سيتم تحديث خطة القضاء';

  @override
  String get profileQazaPlanSummary =>
      'يؤدي تغيير ملفك الشخصي إلى تغيير خطة القضاء المحسوبة.';

  @override
  String get profileQazaReviewError =>
      'تعذر إعداد مراجعة خطة القضاء. حاول مرة أخرى.';

  @override
  String get profileQazaApplying => 'جارٍ تطبيق خطة القضاء…';

  @override
  String get profileQazaImpact => 'التأثير';

  @override
  String profileQazaCount(String count) {
    return '$count قضاء';
  }

  @override
  String get profileQazaPreviousTotal => 'الخطة السابقة';

  @override
  String get profileQazaNewTotal => 'الخطة الجديدة';

  @override
  String get profileQazaCompletedInPlan => 'المكتمل في الخطة الجديدة';

  @override
  String get profileQazaToAdd => 'قضاء جديد للإضافة';

  @override
  String get profileQazaRestored => 'سجلات قضاء أُزيلت سابقًا وستُستعاد';

  @override
  String get profileQazaUpdatedKeptExisting =>
      'تم تحديث الملف الشخصي. احتُفظ بسجلات القضاء الحالية.';

  @override
  String get profileQazaNoLongerRequired => 'قضاء معلّق لم تعد هناك حاجة إليه';

  @override
  String get profileQazaKeepExisting => 'الاحتفاظ بسجلات القضاء الحالية';

  @override
  String get profileQazaApply => 'تطبيق خطة القضاء';

  @override
  String get profileQazaCompletedProtected =>
      'لن تُحذف سجلات القضاء المكتملة أو المضافة يدويًا.';

  @override
  String get profileQazaUpdated => 'تم تحديث الملف الشخصي وخطة القضاء.';

  @override
  String profileQazaUpdatedCounts(int added, int removed) {
    return 'تم تحديث الملف الشخصي وخطة القضاء. سجلات القضاء المضافة: $added؛ المحذوفة: $removed.';
  }

  @override
  String get profileQazaUpdatedNoChange =>
      'تم تحديث الملف الشخصي. لم تتغير خطة القضاء.';

  @override
  String get qazaReviewTitle => 'راجع خطة القضاء';

  @override
  String get qazaReviewSubtitle =>
      'راجع تفاصيل القضاء قبل إضافتها إلى المتتبع.';

  @override
  String get qazaReviewTotal => 'إجمالي القضاء التقديري';

  @override
  String get qazaReviewPeriod => 'فترة القضاء';

  @override
  String get qazaReviewBreakdown => 'تفصيل الصلوات';

  @override
  String get qazaReviewNote =>
      'هذه أعداد تقديرية للصلوات الفائتة، محسوبة من المعلومات الموجودة في ملفك الشخصي.';

  @override
  String get qazaReviewEdit => 'تعديل بياناتي';

  @override
  String get qazaReviewAdd => 'إضافة القضاء إلى المتتبع';

  @override
  String get qazaReviewAdding => 'جارٍ إضافة القضاء…';

  @override
  String get qazaReviewError => 'تعذرت إضافة القضاء. حاول مرة أخرى.';

  @override
  String get profileErrorLanguage => 'يرجى اختيار اللغة.';

  @override
  String get profileErrorGender => 'يرجى تحديد الجنس.';

  @override
  String get profileErrorMadhab => 'يرجى تحديد المذهب الفقهي.';

  @override
  String get profileErrorDob => 'يرجى إدخال تاريخ ميلاد صحيح.';

  @override
  String get profileErrorPuberty => 'يرجى تحديد سن بلوغ صحيح للجنس المحدد.';

  @override
  String get profileErrorStartPraying =>
      'يرجى تحديد عمر أو تاريخ صحيح لبدء الصلاة.';

  @override
  String get profileErrorWitr => 'يرجى تحديد إعداد صحيح للوتر.';

  @override
  String get navPrayerTime => 'مواقيت الصلاة';

  @override
  String get prayerTimeTitle => 'مواقيت الصلاة';

  @override
  String get prayerTimeLocation => 'الموقع';

  @override
  String get prayerTimeUseCurrentLocation => 'استخدام الموقع الحالي';

  @override
  String get prayerTimeSelectCity => 'اختر المدينة';

  @override
  String get prayerTimeSelectCountry => 'اختر الدولة';

  @override
  String get prayerTimeSearchCity => 'ابحث عن مدينة';

  @override
  String get prayerTimeCurrentLocation => 'الموقع الحالي';

  @override
  String get prayerTimeSavedLocation => 'الموقع المحفوظ';

  @override
  String get prayerTimeToday => 'اليوم';

  @override
  String get prayerTimeRestrictedTimes => 'أوقات النهي';

  @override
  String get prayerTimeActive => 'نشط';

  @override
  String get prayerTimeLocationUnavailable => 'الموقع غير متاح';

  @override
  String get prayerTimeLocationPermission =>
      'يلزم إذن الموقع لاستخدام موقعك الحالي.';

  @override
  String get prayerTimeLocationServiceRequired =>
      'يجب تشغيل خدمات الموقع لاستخدام موقعك الحالي.';

  @override
  String get prayerTimeEnableLocation => 'تفعيل الموقع';

  @override
  String get prayerTimeSelectLocation => 'اختر موقعك';

  @override
  String get prayerTimeCalculationMethod => 'طريقة الحساب';

  @override
  String get prayerTimeAsrMethod => 'طريقة حساب العصر';

  @override
  String get prayerTimeHighLatitudeRule => 'قاعدة خطوط العرض العليا';

  @override
  String get prayerTimeAdjustments => 'التعديلات';

  @override
  String get prayerTime12Hour => '12 ساعة';

  @override
  String get prayerTime24Hour => '24 ساعة';

  @override
  String get prayerTimeStandard => 'قياسي';

  @override
  String get prayerTimeHanafi => 'حنفي';

  @override
  String get prayerTimeAutomatic => 'تلقائي';

  @override
  String get prayerTimeMiddleOfTheNight => 'منتصف الليل';

  @override
  String get prayerTimeSeventhOfTheNight => 'سُبع الليل';

  @override
  String get prayerTimeTwilightAngle => 'زاوية الشفق';

  @override
  String get prayerTimeCustom => 'مخصص';

  @override
  String get prayerTimeFajrAngle => 'زاوية الفجر';

  @override
  String get prayerTimeIshaAngle => 'زاوية العشاء';

  @override
  String get prayerTimeSave => 'حفظ';

  @override
  String get prayerTimeCountry => 'الدولة';

  @override
  String get prayerTimeCity => 'المدينة';

  @override
  String get prayerTimeNoCities => 'لا توجد مدن مطابقة';

  @override
  String get prayerTimeSettings => 'إعدادات مواقيت الصلاة';

  @override
  String get prayerTimeLocationData => 'بيانات الموقع';

  @override
  String get settingsLicensesSoftwareTitle => 'تراخيص البرامج مفتوحة المصدر';

  @override
  String get settingsLicensesSoftwareSubtitle =>
      'إشعارات تراخيص البرامج المضمّنة في التطبيق.';

  @override
  String get settingsLicensesGeoNamesTitle => 'بيانات المدن من GeoNames';

  @override
  String get settingsLicensesGeoNamesSubtitle =>
      'مصدر بيانات المدن غير المتصلة بالإنترنت.';

  @override
  String get prayerTimeLocationDataAttribution => 'مصدر بيانات الموقع';

  @override
  String get prayerTimeUpdated => 'تم تحديث مواقيت الصلاة.';

  @override
  String get prayerTimeNoSchedule => 'لا يوجد جدول لمواقيت الصلاة.';

  @override
  String get prayerTimeSetupTitle => 'إعداد مواقيت الصلاة';

  @override
  String get prayerTimeSetupBody =>
      'اختر موقعك وطريقة الحساب لعرض مواقيت الصلاة الصحيحة.';

  @override
  String get prayerTimeRefresh => 'تحديث';

  @override
  String prayerTimeEndsIn(String duration) {
    return 'ينتهي بعد $duration';
  }

  @override
  String prayerTimeRemaining(String duration) {
    return 'الوقت المتبقي $duration';
  }

  @override
  String prayerTimeStartsIn(String duration) {
    return 'يبدأ بعد $duration';
  }

  @override
  String prayerTimeNextRestricted(String name) {
    return 'وقت النهي التالي: $name';
  }

  @override
  String prayerTimeUpcomingPrayer(String name) {
    return 'الصلاة القادمة: $name';
  }

  @override
  String prayerTimeUsingSavedLocation(String location) {
    return 'استخدام الموقع المحفوظ: $location';
  }

  @override
  String get prayerTimeAngleHint =>
      'تُستخدم الزوايا لتحديد مواقيت الفجر والعشاء.';

  @override
  String get prayerTimeAdjustmentMinutes => 'التعديل بالدقائق';

  @override
  String get prayerTimeSunrise => 'الشروق';

  @override
  String get prayerTimeZawal => 'الزوال';

  @override
  String get prayerTimeSunset => 'الغروب';

  @override
  String get prayerTimeFajr => 'الفجر';

  @override
  String get prayerTimeDhuhr => 'الظهر';

  @override
  String get prayerTimeAsr => 'العصر';

  @override
  String get prayerTimeMaghrib => 'المغرب';

  @override
  String get prayerTimeIsha => 'العشاء';

  @override
  String get qiblaTitle => 'اتجاه القبلة';

  @override
  String get qiblaDirection => 'اتجاه القبلة';

  @override
  String get qiblaBearing => 'زاوية الاتجاه';

  @override
  String get qiblaFromTrueNorth => 'من الشمال الحقيقي';

  @override
  String get qiblaUnavailable => 'اتجاه القبلة غير متاح.';

  @override
  String get qiblaLocationRequired => 'حدد موقعك لمعرفة اتجاه القبلة.';

  @override
  String get qiblaCompassBody => 'حرّك جهازك حتى يشير المؤشر إلى اتجاه القبلة.';

  @override
  String get qiblaSensorUnavailableBody =>
      'لا يتوفر مستشعر البوصلة على هذا الجهاز.';

  @override
  String get qiblaHeadingUnavailable => 'تعذر تحديد اتجاه الجهاز.';

  @override
  String get qiblaTurnToDirection => 'استدر باتجاه القبلة';

  @override
  String qiblaCompassAccuracy(String degrees) {
    return 'دقة البوصلة ±$degrees°';
  }

  @override
  String get qiblaCalibrationHint =>
      'عاير البوصلة بتحريك الجهاز على شكل الرقم 8.';

  @override
  String get accountAutomaticBackup => 'النسخ الاحتياطي التلقائي';

  @override
  String get accountBackupStatusChecking =>
      'جارٍ التحقق من حالة النسخ الاحتياطي…';

  @override
  String get accountBackupStatusDisabled => 'النسخ الاحتياطي التلقائي متوقف';

  @override
  String accountBackupStatusBackedUp(Object timestamp) {
    return 'تم حفظ نسخة احتياطية · $timestamp';
  }

  @override
  String get accountBackupStatusBackingUp => 'جارٍ إنشاء نسخة احتياطية…';

  @override
  String get accountBackupStatusPending =>
      'توجد تغييرات بانتظار النسخ الاحتياطي';

  @override
  String get accountBackupStatusWaitingConnection => 'بانتظار الاتصال';

  @override
  String get accountBackupStatusComplete => 'اكتمل النسخ الاحتياطي';

  @override
  String accountBackupStatusCompletedAt(Object timestamp) {
    return 'اكتمل في $timestamp';
  }

  @override
  String get accountBackupStatusWaitingConnectionMessage =>
      'سيتم النسخ الاحتياطي عند عودة الاتصال.';

  @override
  String get accountBackupStatusFailedTitle => 'فشل النسخ الاحتياطي';

  @override
  String get accountBackupStatusFailedMessage =>
      'تعذر إنشاء النسخة الاحتياطية. بياناتك المحلية آمنة.';

  @override
  String get accountBackupStatusAuthRequired =>
      'سجّل الدخول لتفعيل النسخ الاحتياطي.';

  @override
  String get accountBackupStatusSecurityRejected =>
      'تم رفض طلب النسخ الاحتياطي لأسباب أمنية.';

  @override
  String get accountBackupStatusNetwork =>
      'تعذر الاتصال بالخدمة. ستتم إعادة المحاولة تلقائيًا.';

  @override
  String get accountBackupStatusCloudStateInvalid =>
      'حالة النسخة الاحتياطية السحابية غير صالحة.';

  @override
  String get accountBackupStatusFailedAutomaticRetry =>
      'فشل النسخ الاحتياطي. ستتم إعادة المحاولة تلقائيًا.';

  @override
  String get accountBackupStatusRetry => 'إعادة المحاولة';

  @override
  String get accountBackupStatusFailed => 'فشل النسخ الاحتياطي';

  @override
  String get startupProfileLoadErrorTitle => 'تعذر تحميل الملف الشخصي';

  @override
  String get startupProfileLoadErrorMessage =>
      'تعذر تحميل بيانات ملفك الشخصي. حاول مرة أخرى.';

  @override
  String get qazaHistoryTitle => 'سجل القضاء';

  @override
  String get qazaHistoryRecentAdditions => 'الإضافات الأخيرة';

  @override
  String get qazaHistoryRecentlyDeleted => 'المحذوفة مؤخرًا';

  @override
  String get qazaHistoryNoAdditions => 'لا توجد إضافات حديثة.';

  @override
  String get qazaHistoryNoRecentlyDeleted => 'لا توجد سجلات محذوفة مؤخرًا.';

  @override
  String get qazaHistoryLoadMore => 'تحميل المزيد';

  @override
  String get qazaHistoryOriginalDateUnavailable => 'التاريخ الأصلي غير متاح';

  @override
  String get qazaHistoryDeletedQaza => 'سجل قضاء محذوف';

  @override
  String qazaHistoryDeletedQazaCount(int count) {
    return '$count سجلات قضاء محذوفة';
  }

  @override
  String get qazaHistoryRestore => 'استعادة';

  @override
  String qazaHistoryRestoreSuccess(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تمت استعادة $count سجلات قضاء.',
      one: 'تمت استعادة سجل قضاء واحد.',
      zero: 'لم تتم استعادة أي سجلات قضاء.',
    );
    return '$_temp0';
  }

  @override
  String qazaHistoryRestoreConflict(int restored, int skipped) {
    return 'تمت استعادة $restored سجلًا وتخطي $skipped سجلات لوجودها مسبقًا.';
  }

  @override
  String get qazaAdditionTitle => 'تفاصيل إضافة القضاء';

  @override
  String get qazaAdditionNotFound => 'لم يتم العثور على سجل الإضافة.';

  @override
  String qazaAdditionRecordsCount(int count) {
    return 'عدد السجلات: $count';
  }

  @override
  String get qazaAdditionNoPrayers => 'لا توجد صلوات ضمن هذه الإضافة.';

  @override
  String get qazaAdditionViewRecords => 'عرض السجلات';

  @override
  String get qazaAdditionMoreActions => 'المزيد من الإجراءات';

  @override
  String get qazaAdditionEdit => 'تعديل الإضافة';

  @override
  String get qazaAdditionDelete => 'حذف الإضافة';

  @override
  String get qazaAdditionDeleteConfirmTitle => 'حذف إضافة القضاء؟';

  @override
  String get qazaAdditionDeleteConfirmMessage =>
      'سيؤدي هذا إلى حذف سجل الإضافة. لن تُحذف سجلات القضاء الفردية إلا إذا تم تأكيد ذلك صراحةً.';

  @override
  String get qazaAdditionDeletedNothing => 'لم يتم حذف أي سجلات.';

  @override
  String qazaAdditionDeletedCount(int count) {
    return 'تم حذف $count سجلًا.';
  }

  @override
  String qazaAdditionRestoredCount(int count) {
    return 'تمت استعادة $count سجلًا.';
  }

  @override
  String get qazaTrackerHistoryTooltip => 'عرض سجل الإضافات';

  @override
  String get qazaTrackerAdditionProgress => 'تقدم الإضافة';

  @override
  String get qazaTrackerSelectionHint => 'حدد السجلات لإكمالها معًا.';

  @override
  String get qazaTrackerSwipeHint => 'اسحب السجل لإكماله.';

  @override
  String get qazaMarkSelectedPendingTitle =>
      'إعادة السجلات المحددة إلى حالة الانتظار؟';

  @override
  String qazaMarkSelectedPendingMessage(int count) {
    return 'ستُعاد $count من سجلات القضاء المحددة إلى حالة قيد الانتظار ولن تُحتسب مكتملة.';
  }

  @override
  String get qazaMarkAsPending => 'وضع علامة قيد الانتظار';

  @override
  String qazaMarkAsPendingCount(int count) {
    return 'إعادة $count سجلًا إلى حالة الانتظار';
  }

  @override
  String get qazaNoCompletedTitle => 'لا توجد صلوات قضاء مكتملة';

  @override
  String get qazaNoCompletedMessage => 'ستظهر صلوات القضاء المكتملة هنا.';

  @override
  String get qazaReturnedToPending => 'أُعيد سجل القضاء إلى حالة قيد الانتظار.';

  @override
  String get qazaSelectedPendingNothingChanged =>
      'لم يتم تغيير أي من سجلات القضاء المحددة.';

  @override
  String get qazaCorrectionChanged =>
      'تعذر تصحيح سجل القضاء هذا لأنه قد تغيّر.';

  @override
  String get qazaFilter => 'تصفية';

  @override
  String get qazaFiltersActive => 'التصفية مفعّلة';

  @override
  String get qazaOriginalDateLabel => 'تاريخ الصلاة الفائتة';

  @override
  String get qazaCompletedDateLabel => 'تاريخ الإكمال';

  @override
  String get qazaFilterCompletedDateHelp => 'تصفية حسب تاريخ الإكمال';

  @override
  String get qazaUndoCompletions => 'التراجع عن الإكمال';

  @override
  String get qazaUndoSelected => 'التراجع عن المحدد';

  @override
  String get qazaUndoAll => 'التراجع عن الكل';

  @override
  String qazaUndoQazaCount(int count) {
    return '$count قضاء';
  }

  @override
  String get addQazaManageAddition => 'إدارة هذه الإضافة';

  @override
  String qazaCompletionSingle(String prayer, String date) {
    return 'تم إكمال قضاء $prayer بتاريخ $date.';
  }

  @override
  String qazaCompletionMultiple(int count) {
    return 'تم إكمال $count من سجلات القضاء.';
  }

  @override
  String qazaUndoSingle(String prayer, String date) {
    return 'تمت استعادة قضاء $prayer بتاريخ $date.';
  }

  @override
  String qazaUndoMultiple(int count) {
    return 'تمت استعادة $count من سجلات القضاء.';
  }

  @override
  String get qazaUndoExpired =>
      'لم يعد التراجع متاحًا لانتهاء مهلة الخمس ثوانٍ.';

  @override
  String get qazaUndoStaleBatch =>
      'لم يعد التراجع متاحًا لأن إجراء تراجع أحدث قد حلّ محله.';

  @override
  String get qazaUndoTargetChanged =>
      'لم يعد التراجع متاحًا لأن سجل القضاء تغيّر أو أُزيل.';

  @override
  String get qazaUndoFailed => 'تعذر التراجع عن العملية. حاول مرة أخرى.';

  @override
  String get qazaMarkAsPendingMessage =>
      'سيعود سجل القضاء هذا إلى حالة قيد الانتظار ولن يُحتسب مكتملًا.';

  @override
  String get commonDelete => 'حذف';

  @override
  String qazaRequestedSlots(int count) {
    return '$count خانات مطلوبة';
  }

  @override
  String get qazaAdditionUpdated => 'تم تحديث إضافة القضاء';

  @override
  String qazaSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تم تحديد $count عناصر',
      one: 'تم تحديد عنصر واحد',
    );
    return '$_temp0';
  }

  @override
  String dataImportRestored(int count) {
    return 'تمت استعادة النسخة الاحتياطية بنجاح. تمت استعادة $count سجلات قضاء.';
  }

  @override
  String dataImportRestoreSummary(
      int records, int accounts, int revision, String onboarding) {
    return 'تحتوي هذه النسخة الاحتياطية على $records سجلات قضاء و$accounts حسابات محلية.\n\nستؤدي الاستعادة إلى استبدال بيانات التطبيق المحلية الحالية على هذا الجهاز. ستبقى هوية الجهاز على هذا الجهاز.\n\nمراجعة النسخة الاحتياطية: $revision\nإعداد الحساب: $onboarding';
  }

  @override
  String get dataImportOnboardingComplete => 'مكتمل';

  @override
  String get dataImportOnboardingIncomplete => 'غير مكتمل';

  @override
  String get dataLocalOnlyNote =>
      'نسخة احتياطية محلية فقط. تبقى بيانات القضاء على هذا الجهاز ما لم تصدّرها صراحةً.';

  @override
  String get cloudBackupTitle => 'النسخ الاحتياطي السحابي';

  @override
  String get cloudBackupDescription =>
      'احتفظ بنسخة احتياطية منفصلة من تقدم القضاء في بيانات تطبيقك على Google Drive.';

  @override
  String get cloudConnect => 'ربط Google';

  @override
  String get cloudDisconnect => 'فصل الحساب';

  @override
  String get cloudConnected => 'متصل';

  @override
  String get cloudNotConnected => 'اربط حساب Google لنسخ تقدمك احتياطيًا.';

  @override
  String get cloudBackupNow => 'نسخ احتياطي الآن';

  @override
  String get cloudAutomaticBackup => 'النسخ الاحتياطي التلقائي';

  @override
  String get cloudLastBackup => 'آخر نسخة احتياطية ناجحة';

  @override
  String get cloudNeverBackedUp => 'لم يتم إنشاء نسخة احتياطية بعد';

  @override
  String get cloudBackupSucceeded =>
      'اكتملت النسخة الاحتياطية/المزامنة السحابية.';

  @override
  String get cloudBackupUpToDate => 'النسخة الاحتياطية محدّثة بالفعل.';

  @override
  String get cloudBackupConflictTitle => 'تم العثور على تغييرات مختلفة';

  @override
  String get cloudBackupConflictMessage =>
      'توجد بيانات مختلفة على هذا الجهاز وفي Google Drive. اختر النسخة التي تريد الاحتفاظ بها.';

  @override
  String get cloudKeepLocal => 'الاحتفاظ ببيانات هذا الجهاز';

  @override
  String get cloudUseRemote => 'الاستعادة من Google Drive';

  @override
  String get cloudKeepLocalConfirmTitle => 'الاحتفاظ بتقدم هذا الجهاز؟';

  @override
  String get cloudKeepLocalConfirmMessage =>
      'سيتم إنشاء نسخة احتياطية سحابية جديدة من بيانات هذا الجهاز. ستبقى النسخة البعيدة الحالية في سجل النسخ.';

  @override
  String get cloudUseRemoteConfirmTitle => 'استبدال التقدم المحلي؟';

  @override
  String get cloudUseRemoteConfirmMessage =>
      'سيؤدي هذا إلى استبدال بيانات التطبيق المحلية الحالية بنسخة Google Drive الاحتياطية. ستُحفظ أولًا لقطة استرداد محلية مشفّرة.';

  @override
  String get cloudDisconnectConfirmTitle => 'فصل Google؟';

  @override
  String get cloudDisconnectConfirmMessage =>
      'سيتم تعطيل العمليات السحابية التلقائية. ستبقى بيانات القضاء على هذا الجهاز.';

  @override
  String get cloudRecoveryAvailable =>
      'تتوفر لقطة استرداد محمية للبيانات المحلية السابقة.';

  @override
  String get cloudRecoverLocal => 'استعادة البيانات المحلية السابقة';

  @override
  String get cloudRecoveryConfirmTitle => 'استعادة البيانات المحلية السابقة؟';

  @override
  String get cloudRecoveryConfirmMessage =>
      'ستستبدل اللقطة المحلية المحفوظة بيانات التطبيق الحالية على هذا الجهاز.';

  @override
  String get cloudAutomaticBackupRequiresConnection =>
      'اربط Google قبل تفعيل النسخ الاحتياطي التلقائي.';

  @override
  String get cloudBackupWorking => 'جارٍ إنشاء نسخة احتياطية…';

  @override
  String get cloudSetupChoiceTitle => 'مرحبًا بك في قضاء الصلاة';

  @override
  String get cloudSetupChoiceDescription =>
      'تابع صلواتك الفائتة ونظّم تقدمك في القضاء وفق وتيرتك. تبقى سجلاتك على هذا الجهاز. ويمكنك اختياريًا استخدام Google لنسخ تقدمك احتياطيًا واستعادته عبر الأجهزة.';

  @override
  String get cloudSetupUseGoogle => 'المتابعة باستخدام Google';

  @override
  String get cloudSetupContinueLocal => 'المتابعة على هذا الجهاز';

  @override
  String get cloudConnectionFailed =>
      'تعذر إكمال الاتصال بـ Google. حاول مرة أخرى أو تابع محليًا.';

  @override
  String get cloudRestoreProgressTitle =>
      'جارٍ استعادة النسخة الاحتياطية من Google Drive';

  @override
  String get cloudRestoreProgressBody =>
      'يجري تنزيل بياناتك والتحقق منها واستعادتها بأمان. أبقِ التطبيق مفتوحًا.';

  @override
  String get cloudRestoreConnectingTitle => 'جارٍ الاتصال بـ Google Drive';

  @override
  String get cloudRestoreConnectingBody =>
      'يجري التحقق من حساب Google والبحث عن نسخة احتياطية موجودة.';

  @override
  String get cloudRestoreStageChecking => 'جارٍ التحقق من النسخة الاحتياطية…';

  @override
  String get cloudRestoreStageRestoring =>
      'جارٍ استعادة النسخة التي تم التحقق منها…';

  @override
  String get cloudRestoreStageTransferring =>
      'جارٍ نقل بيانات النسخة الاحتياطية…';

  @override
  String get cloudRestoreStageFinishing => 'جارٍ إنهاء الاستعادة…';

  @override
  String get initialCloudBackupAppBarTitle => 'احفظ تقدمك';

  @override
  String get initialCloudBackupTitle =>
      'جارٍ إنشاء أول نسخة احتياطية على Google Drive';

  @override
  String get initialCloudBackupBody =>
      'تم حفظ ملفك الشخصي وتقدم قضاء الصلاة محليًا. أبقِ التطبيق مفتوحًا أثناء إنشاء النسخة الاحتياطية.';

  @override
  String get initialCloudBackupFailedTitle => 'بياناتك محفوظة على هذا الجهاز';

  @override
  String get initialCloudBackupFailedBody =>
      'تعذر إكمال النسخ الاحتياطي السحابي. لم يتم حذف ملفك الشخصي أو بيانات قضاء الصلاة المحلية.';

  @override
  String get initialCloudBackupStageChecking => 'جارٍ التحقق من Google Drive…';

  @override
  String get initialCloudBackupStagePreparing =>
      'جارٍ تجهيز النسخة الاحتياطية…';

  @override
  String get initialCloudBackupStageUploading => 'جارٍ رفع النسخة الاحتياطية…';

  @override
  String get initialCloudBackupStageCompleted =>
      'تم حفظ النسخة الاحتياطية بنجاح';

  @override
  String get initialCloudBackupRetry => 'إعادة محاولة النسخ الاحتياطي';

  @override
  String get initialCloudBackupContinueHome => 'المتابعة إلى الرئيسية';

  @override
  String get initialCloudBackupStageDownloading =>
      'جارٍ تنزيل النسخة الاحتياطية…';

  @override
  String get dailySalahTrackingTitle => 'متابعة الصلوات اليومية';

  @override
  String get dailySalahTrackingEnableTitle => 'تفعيل متابعة الصلوات اليومية';

  @override
  String get dailySalahTrackingEnableSubtitle =>
      'سجّل الصلوات التي أديتها أو فاتتك. لن تُسجّل أي صلاة غير مسجّلة كفائتة تلقائيًا.';

  @override
  String get dailySalahTrackingEnableAction => 'تفعيل';

  @override
  String get dailySalahTrackingSkipForNow => 'تخطي الآن';

  @override
  String get dailySalahTrackingSkippedMessage =>
      'تم تخطي تتبّع الصلاة اليومية. يمكنك تفعيله في أي وقت من الملف الشخصي.';

  @override
  String get dailySalahTrackingRemoveStatusTitle => 'إزالة حالة الصلاة؟';

  @override
  String get dailySalahTrackingRemoveStatusMessage =>
      'سيتم تغيير حالة الصلاة إلى غير مسجلة. سيبقى أي سجل قضاء موجود دون تغيير.';

  @override
  String get dailySalahTrackingRemoveStatusAction => 'إزالة الحالة';

  @override
  String get dailySalahTrackingPrayed => 'أديت';

  @override
  String get dailySalahTrackingMissed => 'فاتتني';

  @override
  String get dailySalahTrackingUnrecorded => 'غير مسجلة';

  @override
  String get dailySalahTrackingConfirmMissedTitle => 'تسجيل الصلاة كفائتة؟';

  @override
  String get dailySalahTrackingConfirmMissedMessage =>
      'سيُضاف سجل قضاء لهذه الصلاة والتاريخ فقط إذا لم يكن موجودًا بالفعل.';

  @override
  String get dailySalahTrackingUndoQaza =>
      'التراجع عن سجل القضاء الذي أنشأه المتتبع';

  @override
  String get dailySalahTrackingUndoTitle => 'إزالة سجل القضاء هذا؟';

  @override
  String get dailySalahTrackingUndoMessage =>
      'ستتم إزالة سجل القضاء الذي أنشأته متابعة الصلوات اليومية فقط، وفقط إذا كان لا يزال غير مكتمل.';

  @override
  String get dailySalahTrackingPreviousDay => 'اليوم السابق';

  @override
  String get dailySalahTrackingNextDay => 'اليوم التالي';

  @override
  String get dailySalahTrackingUndoUnavailable =>
      'لم تعد هذه الصلاة قيد الانتظار، لذلك لم تتم إزالتها.';

  @override
  String get profileIslamicBackground => 'الخلفية الإسلامية';

  @override
  String get profileMuslimFromChildhood => 'كنت على الإسلام منذ الطفولة';

  @override
  String get profileAcceptedIslamLater => 'اعتنقت الإسلام لاحقًا';

  @override
  String get profileIslamAcceptanceDate => 'تاريخ اعتناق الإسلام';

  @override
  String get profileStartPrayingDate => 'تاريخ بدء الصلاة';

  @override
  String get profileNewMuslimQazaHelp =>
      'يُحتسب القضاء فقط بعد اعتناق الإسلام ومنذ وجوب الصلاة. لا تُحتسب الصلوات الفائتة قبل اعتناق الإسلام.';

  @override
  String get profileErrorIslamAcceptanceDate =>
      'يرجى إدخال تاريخ صحيح لاعتناق الإسلام، لا يسبق تاريخ الميلاد.';

  @override
  String get profileRememberDate => 'أتذكر التاريخ';

  @override
  String get profileNotSure => 'لست متأكدًا';

  @override
  String get profilePubertyDate => 'تاريخ البلوغ';

  @override
  String get profileEstimateUsingAge => 'تقدير باستخدام العمر';
}
