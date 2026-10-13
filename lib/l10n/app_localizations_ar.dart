import 'app_localizations_en.dart';

/// Arabic strings currently reviewed for the app interface.
/// Untranslated strings inherit the English template until reviewed Arabic copy is added.
class AppLocalizationsAr extends AppLocalizationsEn {
  AppLocalizationsAr() : super('ar');

  @override
  String get appTitle => 'قضاء الصلاة';

  @override
  String get navHome => 'الرئيسية';

  @override
  String get navQaza => 'قضاء';

  @override
  String get navKnowledge => 'المعرفة';

  @override
  String get navSettings => 'الإعدادات';

  @override
  String get settingsRemindersSection => 'التذكيرات';

  @override
  String get settingsRemindersSubtitle => 'تذكير يومي بإكمال الصلوات الفائتة.';

  @override
  String get settingsBackupSection => 'البيانات والتخزين';

  @override
  String get settingsBackupSubtitle => 'المزامنة السحابية والتصدير والاستيراد.';

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
  String get errorNetwork => 'لا يوجد اتصال. حُفظت بيانات القضاء على هذا الجهاز وستتم مزامنتها عند عودة الاتصال.';

  @override
  String get errorTimeout => 'استغرقت العملية وقتًا طويلًا. حاول مرة أخرى بعد قليل.';

  @override
  String get errorPermission => 'يلزم منح الإذن لإتمام هذه العملية. افتح الإعدادات لمنحه.';

  @override
  String get errorAuthentication => 'يجب تسجيل الدخول أولًا.';

  @override
  String get errorValidation => 'البيانات المدخلة غير مقبولة. تحقق منها ثم حاول مرة أخرى.';

  @override
  String get errorMalformedData => 'هذا الملف ليس نسخة احتياطية صالحة أو أنه تالف.';

  @override
  String get errorStorage => 'تعذر حفظ التغيير على هذا الجهاز. أفرغ بعض المساحة ثم حاول مجددًا.';

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
  String get syncRestoringDetail => 'جارٍ استعادة سجلات القضاء المحفوظة إلى هذا الجهاز.';

  @override
  String get syncSynced => 'تمت المزامنة';

  @override
  String get syncSyncing => 'جارٍ المزامنة';

  @override
  String get syncSaved => 'تم الحفظ';

  @override
  String get syncSavedDetail => 'حُفظت تغييراتك على هذا الجهاز وستتم مزامنتها تلقائيًا.';

  @override
  String get syncErrorLabel => 'خطأ في المزامنة';

  @override
  String get syncErrorDetail => 'بياناتك محفوظة على هذا الجهاز. سنحاول المزامنة تلقائيًا.';

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
  String get homeProgressTitle => 'تقدمك';

  @override
  String get homeProgressError => 'تعذر تحميل تقدمك في القضاء. اسحب لإعادة المحاولة.';

  @override
  String get homeTodayProgress => 'إنجاز اليوم';

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
  String get homePrayerTimeUnavailable => 'اختيار وقت الصلاة غير متاح حتى إعداد مواقيت الصلاة.';

  @override
  String get homeQazaTargetReachedTitle => 'الحمد لله!';

  @override
  String get homeQazaTargetReachedMessage => 'لقد أكملت خطة القضاء لهذا اليوم.\nتقبل الله منك.';

  @override
  String get homeDailyTarget => 'الهدف اليومي';

  @override
  String get homeNextQaza => 'القضاء التالي';

  @override
  String get homeCompleteNextQaza => 'إكمال القضاء التالي';

  @override
  String get homeViewAllQaza => 'عرض جميع الصلوات';

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
  String get qazaLoading => 'جارٍ تحميل سجلات القضاء...';

  @override
  String get qazaEmptyTitle => 'لا توجد سجلات قضاء بعد';

  @override
  String get qazaEmptyMessage => 'أضف الصلوات الفائتة أو احسب تقديرًا للبدء.';

  @override
  String get qazaFilteredEmptyTitle => 'لا توجد سجلات تطابق هذه المرشحات';

  @override
  String get qazaFilteredEmptyMessage => 'جرّب حالة أو صلاة أو نطاقًا زمنيًا مختلفًا.';

  @override
  String get qazaResetFilters => 'إعادة ضبط المرشحات';

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
  String get qazaRecordUpdated => 'تم تحديث سجل القضاء.';

  @override
  String get qazaRecordUpdateFailed => 'تعذر تحديث سجل القضاء. حاول مرة أخرى.';

  @override
  String get qazaRecordDeleted => 'تم حذف سجل القضاء نهائيًا.';

  @override
  String get qazaRecordDeleteFailed => 'تعذر حذف سجل القضاء. حاول مرة أخرى.';

  @override
  String get qazaUndoAction => 'تراجع';

  @override
  String get calendarSelectYear => 'اختر السنة';

  @override
  String get calendarSelectHint => 'اضغط على تاريخ متاح لتحديده.';

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
  String get authHelpTooltip => 'مساعدة تسجيل الدخول';

  @override
  String get authHelpTitle => 'تسجيل الدخول';

  @override
  String get authDismiss => 'إغلاق';

  @override
  String get authFailed => 'تعذر تسجيل الدخول. حاول مرة أخرى.';

  @override
  String get welcomeTagline => 'العبادة والمواظبة على الصلاة';

  @override
  String get welcomeHeadline => 'تابع صلواتك الفائتة بوضوح وانتظام.';

  @override
  String get welcomeBody => 'سجّل صلوات القضاء وأكملها وتابع تقدمك، صلاةً بعد صلاة.';

  @override
  String get welcomeGetStarted => 'ابدأ الآن';

  @override
  String get welcomeSignIn => 'لديك حساب بالفعل؟ سجّل الدخول';

  @override
  String get splashTagline => 'مساحة هادئة للمواظبة على قضاء الصلاة';

  @override
  String get accountTitle => 'الحساب';

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
  String get accountNotAvailable => 'غير متاح';

  @override
  String get accountSignOut => 'تسجيل الخروج';

  @override
  String get accountSignOutPrompt => 'تسجيل الخروج؟';

  @override
  String get accountSignOutExplanation => 'سيؤدي تسجيل الخروج إلى فصل حساب Google. ستبقى بيانات القضاء على هذا الجهاز.';

  @override
  String get dataTitle => 'تصدير واستيراد';

  @override
  String get dataExportTitle => 'تصدير البيانات';

  @override
  String get dataExportBody => 'احفظ نسخة JSON من سجلات القضاء. لن يتم رفع أي بيانات عند التصدير.';

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
  String get dataImportTitle => 'استيراد البيانات';

  @override
  String get dataImportBody => 'افتح ملف تصدير JSON، وتحقق من صحته، وراجع الدمج قبل تطبيقه على هذا الحساب.';

  @override
  String get dataImportAction => 'استيراد';

  @override
  String get dataImportReviewTitle => 'مراجعة استيراد البيانات';

  @override
  String get dataImportCanceled => 'تم إلغاء الاستيراد. لم تتغير بياناتك.';

  @override
  String get dataImportSignInRequired => 'سجّل الدخول قبل استيراد بيانات القضاء.';

  @override
  String get dataImportEmptyFile => 'الملف المحدد فارغ أو يتعذر قراءته.';

  @override
  String get dataProcessing => 'جارٍ معالجة البيانات…';

  @override
  String get dataSafetyTitle => 'أمان البيانات';

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
  String get addQazaStepNameDates => 'تحديد التواريخ';

  @override
  String get addQazaStepNamePrayers => 'الصلوات الفائتة';

  @override
  String get addQazaStepNameReview => 'مراجعة';

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
  String get addQazaCancelledMessage => 'تم إلغاء الإضافة. تم الاحتفاظ بأي سجلات حُفظت بالفعل.';

  @override
  String get addQazaChecking => 'جارٍ التحقق من سجلاتك...';

  @override
  String get addQazaNextPrayers => 'التالي: المراجعة والإضافة';

  @override
  String get qazaImportAdded => 'تمت الإضافة';

  @override
  String get qazaImportSkipped => 'تم التخطي';

  @override
  String get addQazaCreatedTitle => 'تم إنشاء سجلات القضاء';

  @override
  String get completeTitle => 'إكمال القضاء';

  @override
  String get completeHeading => 'إكمال أقدم سجل معلّق';

  @override
  String get completeIntro => 'أكمل سجلًا واحدًا في كل مرة. بعد النجاح، سيظهر السجل التالي مباشرة.';

  @override
  String get completeLoading => 'جارٍ تحميل السجل المعلّق...';

  @override
  String get completeLoadError => 'تعذر تحميل سجل القضاء.';

  @override
  String get completeNoPendingTitle => 'لا يوجد قضاء معلّق لهذه الصلاة.';

  @override
  String get completeNoPendingMessage => 'اختر صلاة أخرى أو أضف سجل قضاء أولًا.';

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
  String get knowledgeBaseTitle => 'المكتبة العلمية';

  @override
  String get knowledgeBaseSearchHint => 'ابحث في المسائل والمغالطات';

  @override
  String get knowledgeBaseClearSearch => 'مسح البحث';

  @override
  String get knowledgeCategoryMasail => 'المسائل';

  @override
  String get knowledgeCategoryMugalat => 'المغالطات';

  @override
  String get knowledgeBaseEmptyTitle => 'لم يتم العثور على مقالات';

  @override
  String get knowledgeBaseEmptyMessage => 'جرّب كلمة بحث أو تصنيفًا آخر.';

  @override
  String get knowledgeBaseLoadError => 'تعذر تحميل المكتبة العلمية.';

  @override
  String get knowledgeBaseLanguage => 'لغة المكتبة العلمية';

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
  String get settingsKnowledgeBaseSubtitle => 'تصفح المسائل والمغالطات';

  @override
  String get settingsDataSection => 'البيانات والتخزين';

  @override
  String get settingsDataSubtitle => 'مزامنة بيانات القضاء ونسخها احتياطيًا وتصديرها واستيرادها.';

  @override
  String get settingsDataCloud => 'البيانات والسحابة';

  @override
  String get settingsDataCloudSubtitle => 'حالة المزامنة والتصدير والاستيراد';

  @override
  String get settingsLanguage => 'اللغة';

  @override
  String get settingsLanguageSubtitle => 'اختر اللغة المستخدمة في التطبيق.';

  @override
  String get settingsLanguageNote => 'تتبع أسماء الصلوات والتواريخ الهجرية اللغة المختارة. وتُعرض العربية من اليمين إلى اليسار.';

  @override
  String get settingsAboutSection => 'حول التطبيق';

  @override
  String get settingsAboutSubtitle => 'معلومات التطبيق وإصدار البرنامج.';

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
  String get backupPromptTitle => 'حافظ على تقدمك';

  @override
  String get backupPromptBody => 'سجّل الدخول باستخدام Google للاحتفاظ بتقدمك في القضاء وربطه بحسابك.';

  @override
  String get backupPromptConfirm => 'المتابعة باستخدام Google';

  @override
  String get backupPromptDismiss => 'ليس الآن';

  @override
  String get backupSignInFailed => 'فشل تسجيل الدخول. ما زال تقدمك محفوظًا على هذا الجهاز.';

  @override
  String get backupSignInCancelled => 'تم إلغاء تسجيل الدخول. ما زال تقدمك محفوظًا على هذا الجهاز.';

  @override
  String get profileLanguageTitle => 'اختر لغتك';

  @override
  String get profileLanguageIntro => 'اختر اللغة التي تريد استخدامها في التطبيق.';

  @override
  String get profileErrorLanguage => 'يرجى اختيار اللغة.';
}
