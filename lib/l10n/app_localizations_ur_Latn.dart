// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Roman Urdu (`ur-Latn`).
class AppLocalizationsUrLatn extends AppLocalizations {
  AppLocalizationsUrLatn([String locale = 'ur_Latn']) : super(locale);

  @override
  String get appTitle => 'Qaza Namaz';

  @override
  String get navHome => 'Home';

  @override
  String get navQaza => 'Qaza';

  @override
  String get navKnowledge => 'Rehnumai';

  @override
  String get settingsRemindersSection => 'yaad dehaniyan';

  @override
  String get settingsRemindersSubtitle =>
      'Qaza mukammal karne ki rozanh yaad dhani';

  @override
  String get settingsBackupSection => 'Data aur astorij';

  @override
  String get settingsBackupSubtitle => 'Cloud snk braamd aur draamd';

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
  String get statusPending => 'baqi';

  @override
  String get statusCompleted => 'mukammal';

  @override
  String get qazaSelectAllMatching => 'sab mutabiq muntakhab karein';

  @override
  String qazaSelectAllMatchingCapped(String count) {
    return 'pehle $count mutabiq record muntakhab kar liye gie';
  }

  @override
  String qazaConfirmBulkTitle(String count) {
    return '$count record mukammal krin';
  }

  @override
  String qazaConfirmBulkMessage(String count) {
    return 'is se $count zair iltawa Namazein mukammal shumar hon gi aap fora baad wapas kar sakte hin baad mein nhin';
  }

  @override
  String get qazaConfirmBulkAction => 'mukammal karein';

  @override
  String get errorNetwork =>
      'koi rabta nhin aap ki Qaza is device par mehfooz hin aur on line hote hi sync ho jayein gi';

  @override
  String get errorTimeout =>
      'bohat waqt lag gia thori der baad dobara koshish krin';

  @override
  String get errorPermission =>
      'is ke liye ajazt darkar he Settings mein ja kar ajazt din';

  @override
  String get errorAuthentication => 'is ke liye sign in hona zaroori he';

  @override
  String get errorValidation =>
      'yeh input qabool nahi hoii jaanch kar dobara koshish krin';

  @override
  String get errorMalformedData => 'yeh file Qaza backup app nhin ya kharab he';

  @override
  String get errorStorage =>
      'device tabdeeli mehfooz nahi kar ska kuch jgh khaali kar ke dobara koshish krin';

  @override
  String get errorUnknown => 'kuch ghalat ho gia';

  @override
  String get commonOpenSettings => 'Settings kholen';

  @override
  String get qazaSortLabel => 'tarteeb';

  @override
  String get qazaSortOldestFirst => 'pehle prani';

  @override
  String get qazaSortNewestFirst => 'pehle nayi';

  @override
  String get filterAll => 'sab';

  @override
  String get commonRetry => 'dobara koshish karein';

  @override
  String get commonTotal => 'kal';

  @override
  String get commonVersion => 'orzhn';

  @override
  String get stateErrorTitle => 'kuch ghalat ho gaya';

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
  String get syncSettingUp => 'tarteeb di ja rahi hai';

  @override
  String get syncSettingUpDetail =>
      'is device par aap ke Qaza record tiar kiye ja rahe hin';

  @override
  String get syncRestoring => 'bahal kya ja raha hai';

  @override
  String get syncRestoringDetail =>
      'aap ke mehfooz Qaza record is device par laye ja rahe hin';

  @override
  String get syncSynced => 'sync shdh';

  @override
  String syncSyncedAt(String timestamp) {
    return 'sync shdh • $timestamp';
  }

  @override
  String get syncSyncing => 'sync ho raha hai';

  @override
  String get syncSaved => 'mehfooz';

  @override
  String get syncSavedDetail =>
      'aap ki tabdeeliyan is device par mehfooz hin aur khud-ba-khud sync ho jayein gi';

  @override
  String get syncErrorLabel => 'sync mein masla';

  @override
  String get syncErrorDetail =>
      'aap ki tabdeeliyan is device par mehfooz hin hm khud-ba-khud dobara koshish karein ge';

  @override
  String get commonClose => 'band karein';

  @override
  String get commonCancel => 'mansookh karein';

  @override
  String get commonDone => 'mukammal';

  @override
  String get commonReset => 're set';

  @override
  String get commonClear => 'saaf karein';

  @override
  String get commonBack => 'wapas';

  @override
  String get commonContinue => 'jari rakhein';

  @override
  String get commonLoading => 'load ho raha hai...';

  @override
  String get commonToday => 'aaj';

  @override
  String get commonYesterday => 'kal';

  @override
  String hijriDate(Object day, Object month, Object year) {
    return '$day $month $year h';
  }

  @override
  String hijriDateShort(Object day, Object month) {
    return '$day $month';
  }

  @override
  String get hijriAdjustmentTitle => 'Hijri tareekh adjust karein';

  @override
  String get hijriAdjustmentEarlierTwo => '2 din pehle';

  @override
  String get hijriAdjustmentEarlierOne => '1 din pehle';

  @override
  String get hijriAdjustmentNoChange => 'Koi tabdeeli nahi';

  @override
  String get hijriAdjustmentLaterOne => '1 din baad';

  @override
  String get hijriAdjustmentLaterTwo => '2 din baad';
  @override
  String hijriMonthYear(Object month, Object year) {
    return '$month $year h';
  }

  @override
  String get hijriMonthMuharram => 'Muharram';

  @override
  String get hijriMonthSafar => 'sfr';

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
  String get homeHeadingSetup => 'apna Qaza Safar shuru karein';

  @override
  String get homeHeadingPending => 'jari rakhein';

  @override
  String get homeHeadingCompleted => 'aap ki tamam Qaza mukammal hai';

  @override
  String get homeSetupMessage => 'aap ne ab tak koi Qaza Namaz shamil nahi ki';

  @override
  String get homeCompleteQaza => 'Qaza ada karein';

  @override
  String get homeAddNewQaza => 'nayi Qaza shamil karein';

  @override
  String get homeAddManually => 'dasti tor par Qaza shamil karein';

  @override
  String get homeStatTotal => 'kal';

  @override
  String get homeAddQaza => 'Qaza shamil karein';

  @override
  String homeCompletedCount(int count) {
    return '$count mukammal';
  }

  @override
  String get homeProgressTitle => 'aap ki progress';

  @override
  String get homeProgressError =>
      'aap ki Qaza ki progress load nahi ho ski dobara koshish ke liye neeche khinchin';

  @override
  String get homeTodayProgress => 'aaj ki progress';

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
  String get homeCompleteOldestQaza => 'sab se prani Qaza mukammal karein';

  @override
  String get homeAuto => 'khudkar';

  @override
  String get homeAutoSequence => 'khudkar tarteeb';

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
      'aap ne aaj ka apna Qaza mansooba mukammal kar liya he\nAllah Taala aap ki koshishein qabool frmaie';

  @override
  String get homeDailyTarget => 'rozanh hadaf';

  @override
  String homePerDay(int count) {
    return 'rozanh $count';
  }

  @override
  String homeEstimatedCompletion(String date) {
    return 'mutawaqqa tkmil: $date';
  }

  @override
  String get homeNextQaza => 'agli Qaza';

  @override
  String get homeCompleteNextQaza => 'agli Qaza mukammal karein';

  @override
  String get homeViewAllQaza => 'tamam Qaza dekhein';

  @override
  String get homeDailyProgressError => 'aaj ki progress load nahi ho ski';

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
  String get qazaProgressLabel => 'progress';

  @override
  String get qazaAddTooltip => 'Qaza shamil karein';

  @override
  String get qazaDateFilterAny => 'asal tareekh: koi bhi';

  @override
  String get qazaDateFilterHelp => 'asal Qaza tareekh ke mutabiq filter karein';

  @override
  String qazaDateFilterRange(String from, String to) {
    return '$from — $to';
  }

  @override
  String get qazaLoading => 'aap ke Qaza record load ho rahe hin...';

  @override
  String get qazaEmptyTitle => 'abhi koi Qaza record nahi';

  @override
  String get qazaEmptyMessage =>
      'shuru karne ke liye chhoti hui Namazein shamil karein ya andaza lgaiin';

  @override
  String get qazaFilteredEmptyTitle => 'in filters se koi record nahi mila';

  @override
  String get qazaFilteredEmptyMessage =>
      'mukhtalif halt Namaz ya tareekh ki had aazmaiin';

  @override
  String get qazaResetFilters => 'filters re set karein';

  @override
  String qazaLoadError(String error) {
    return 'aap ke Qaza record load nahi ho ske: $error';
  }

  @override
  String qazaLoadMoreError(String error) {
    return 'mzid record load nahi ho ske: $error';
  }

  @override
  String qazaCompleteError(String error) {
    return 'muntakhab Qaza mukammal nahi ho saki: $error';
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
  String get qazaRecordActions => 'record ke aamaal';

  @override
  String get qazaEditRecord => 'tarmeem';

  @override
  String get qazaDeleteRecord => 'delete karein';

  @override
  String get qazaEditRecordTitle => 'Qaza mein tarmeem';

  @override
  String get qazaEditPrayer => 'Namaz';

  @override
  String get qazaEditDate => 'asal tareekh';

  @override
  String get qazaEditDateHelp => 'Qaza ki asal tareekh muntakhab karein';

  @override
  String get qazaSaveChanges => 'tabdeeliyan mehfooz karein';

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
  String get qazaUndoAction => 'wapas karein';

  @override
  String qazaUndoAvailable(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'haalya takmeelaat wapas ki ja sakti hin',
      one: 'haalya tkmil wapas ki ja sakti he',
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
      zero: 'kuch mukammal nahi hoa',
    );
    return '$_temp0';
  }

  @override
  String get calendarSelectYear => 'saal muntakhab karein';

  @override
  String get calendarSelectHint =>
      'muntakhab karne ke liye dstiab tareekh par tap krin';

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
  String get authTitle => 'sign in';

  @override
  String get authWelcomeBack => 'khush aamdeed';

  @override
  String get authSubtitle =>
      'apne Qaza Namaz tracker tak rasai ke liye sign in krin';

  @override
  String get authContinueWithGoogle => 'Google se jari rakhein';

  @override
  String get authSigningIn => 'sign in ho raha hai...';

  @override
  String get authProviderNote =>
      'is waqt Google hi munsalik tasdeeqi faraham kuninda he sign in ki halat fairbis se khud-ba-khud bahal ho jati he';

  @override
  String get authHelpTooltip => 'tasdeeq mein madad';

  @override
  String get authHelpTitle => 'tasdeeq';

  @override
  String get authHelpBody =>
      'is release mein Google sign in hi munsalik tasdeeqi tareeqa he aap ka Qaza Data isi fairbis account se munsalik rehta hai jis se aap sign in karte hin';

  @override
  String get authDismiss => 'band karein';

  @override
  String get authFailed => 'sign in nahi ho ska dobara koshish krin';

  @override
  String get welcomeTagline => 'roohani ibadat aur Namaz ki pabandi';

  @override
  String get welcomeHeadline =>
      'apni chhoti hui Namazon ka wazahat aur tasalsul ke saath hisaab rkhin';

  @override
  String get welcomeBody =>
      'apni Qaza Namazein darj krin ada karein aur in ka hisaab rakhein — aik aik Namaz kar ke';

  @override
  String get welcomeGetStarted => 'shuru karein';

  @override
  String get welcomeSignIn => 'pehle se account he sign in karein';

  @override
  String get splashTagline => 'Namaz ki pabandi ke liye aik prskon jgh';

  @override
  String get accountChoiceHeadline => 'apni Qaza ki progress mehfooz rakhein';

  @override
  String get accountChoiceDescription =>
      'Google se sign in karein taake aap ki progress mukhtalif dioaisz par mehfooz aur bahal ho ske';

  @override
  String get accountChoiceContinueGoogle => 'Google ke saath jari rakhein';

  @override
  String get accountChoiceContinueGuest => 'mehmaan ke tor par jari rakhein';

  @override
  String get accountChoiceGuestDescription =>
      'mehmaan ka Data isi device par mehfooz rehta he aap baad mein Google munsalik kar sakte hin';

  @override
  String get accountChoiceGoogleFailed =>
      'Google sign in mukammal nahi ho ska dobara koshish krin';

  @override
  String get accountTitle => 'account';

  @override
  String get accountProfileChecking =>
      'Google account ki halat maloom ki ja rahi hai…';

  @override
  String get accountProfileUnavailable => 'Google account ki halat dstiab nahi';

  @override
  String get accountProfileUnavailableDetail =>
      'aap ke Qaza record is device par dstiab rahein ge';

  @override
  String get accountGuest => 'mehmaan';

  @override
  String get accountConnectGoogle => 'Google se munsalik karein';

  @override
  String get accountSignInMethod => 'sign in ka tareeqa';

  @override
  String get accountGoogleAuth => 'Google';

  @override
  String get accountSignedInWithGoogle => 'Google se sign in hin';

  @override
  String get accountStatus => 'account ki halat';

  @override
  String get accountSignedIn => 'mqami';

  @override
  String get accountRecordsRetained =>
      'aap ke mehfooz Qaza record maujood rahein ge aur agli baar sign in par bahal ho jayein ge';

  @override
  String get accountDeveloperContext => 'developer tafseelaat';

  @override
  String get accountFirebaseUid => 'fairbis UID';

  @override
  String get accountNotAvailable => 'dstiab nahi';

  @override
  String get accountSignOut => 'sign out';

  @override
  String get accountSignOutPrompt => 'sign out krin';

  @override
  String get accountSignOutExplanation =>
      'sign out karne se aap ka Google account munqati ho jaye ga aap ki Qaza progress is device par barqarar rahe gi';

  @override
  String get dataTitle => 'braamd o daraamad';

  @override
  String get dataExportTitle => 'Data braamd karein';

  @override
  String get dataExportBody =>
      'apne Qaza khate ki aik JSON naqal mehfooz krin braamd karne se kuch app load nahi hota';

  @override
  String get dataExportAction => 'braamd';

  @override
  String get dataExportDialogTitle => 'Qaza Data braamd mehfooz karein';

  @override
  String get dataExportSaved => 'braamd kamyabi se mehfooz ho gii';

  @override
  String get dataExportCanceled =>
      'braamd mansookh hoii aap ka Data tabdeel nahi hoa';

  @override
  String get dataExportSignInRequired =>
      'apna Qaza Data braamd karne se pehle sign in krin';

  @override
  String dataExportFailed(String error) {
    return 'braamd nakam: $error';
  }

  @override
  String get dataImportTitle => 'Data daraamad karein';

  @override
  String get dataImportBody =>
      'koi JSON braamd kholin is ki mukammal jaanch krin inzimaam ka jaiza lin phir usay is account par laagu krin';

  @override
  String get dataImportAction => 'daraamad';

  @override
  String get dataImportReviewTitle => 'Data daraamad ka jaiza';

  @override
  String get dataImportCanceled =>
      'daraamad mansookh hoii aap ka Data tabdeel nahi hoa';

  @override
  String get dataImportSignInRequired =>
      'Data daraamad karne se pehle sign in krin';

  @override
  String get dataImportEmptyFile =>
      'muntakhab file khaali ya na-qabil mutala he';

  @override
  String dataImportRejected(String error) {
    return 'daraamad mustarad: $error\nkoi juzvi daraamad laagu nahi hoii';
  }

  @override
  String dataImportComplete(int added, int completed, int unchanged) {
    return 'daraamad mukammal: $added shaml $completed mkml $unchanged baghair tbdili';
  }

  @override
  String get dataProcessing => 'Data par kam ho raha hai…';

  @override
  String get dataSafetyTitle => 'Data ki hifazat';

  @override
  String get dataSafetyBody =>
      'braamd karne se Cloud Data delete nahi hota daraamad se mojodh record khtm nahi hote sign out Data delete krna nhin aur app in install karne se Cloud record delete nahi hote';

  @override
  String get dataRemapNote =>
      'daraamad shdh record mojodh sign in account se munsalik kar diye jate hin is ke baad mojodh local-first sync parat pas manzar mein Firestore se tsdiq karti he';

  @override
  String get addQazaTitle => 'Qaza shamil karein';

  @override
  String get addQazaStep1 => 'marhala 1 az 3 • tareekhein muntakhab karein';

  @override
  String get addQazaStep2 =>
      'marhala 2 az 3 • chhoti hui Namazein muntakhab karein';

  @override
  String get addQazaStep3 => 'marhala 3 az 3 • jaiza aur izafa';

  @override
  String get addQazaModeSingle => 'aik';

  @override
  String get addQazaModeRange => 'doraniya';

  @override
  String get addQazaModeMultiple => 'mtdd';

  @override
  String get addQazaModeSingleTitle => 'aik tareekh';

  @override
  String get addQazaModeRangeTitle => 'tareekhon ka doraniya';

  @override
  String get addQazaModeMultipleTitle => 'mtdd tareekhein';

  @override
  String get addQazaChooseSingle => 'aik tareekh muntakhab karein';

  @override
  String get addQazaChooseRange => 'tareekhon ka doraniya muntakhab karein';

  @override
  String get addQazaChooseMultiple => 'mtdd tareekhein muntakhab karein';

  @override
  String get addQazaAvailabilityNote =>
      'range mode mein durust tareekhein muntakhab ki ja sakti hin chahe in par koi Qaza baqi na ho jaiza sirf ahl Namazein shamil karta he';

  @override
  String get addQazaStepNameDates => 'tareekhein muntakhab karein';

  @override
  String get addQazaStepNamePrayers => 'Qaza Namazein';

  @override
  String get addQazaStepNameReview => 'jaiza';

  @override
  String addQazaStepSemantics(int step, String name) {
    return 'marhala $step: $name';
  }

  @override
  String addQazaPartialAvailability(int available, int total) {
    return '$total mein se $available tareekhon par dstiab';
  }

  @override
  String get addQazaAvailableEveryDate => 'hr muntakhab tareekh par dstiab';

  @override
  String get addQazaEligibleOnlyNote =>
      'sirf ahl tareekh aur Namaz ke mjmoe shamil kiye jayein ge pehle se record shdh chhor diye jayein ge';

  @override
  String addQazaAddCount(String count) {
    return '$count Qaza shamil karein';
  }

  @override
  String get addQazaNothingNew =>
      'shamil karne ko kuch naya nahi — yeh mjmoe pehle se record hin';

  @override
  String get addQazaChecking => 'aap ka ledger jaanchaa ja raha hai...';

  @override
  String get addQazaNextPrayers => 'agla: jaiza aur izafa';

  @override
  String get addQazaPrayersHeading => 'chhoti hui Namazein';

  @override
  String get addQazaSelectAll => 'sab muntakhab karein';

  @override
  String get addQazaAllSelected => 'sab muntakhab hin';

  @override
  String get addQazaReviewHeading => 'jaiza aur izafa';

  @override
  String get addQazaReviewNote =>
      'khulase ki tsdiq krin phir yeh Qaza record apne khate mein shamil krin';

  @override
  String get addQazaCombinationNote =>
      'hr tareekh aur Namaz ka jor aik alg baqi record banta he pehle se maujood jor khud-ba-khud chhor diye jate hin';

  @override
  String get addQazaSelectionLabel => 'antkhab';

  @override
  String get addQazaDatesLabel => 'tareekhein';

  @override
  String get addQazaDateCountLabel => 'tareekhon ki tadaad';

  @override
  String get addQazaDateRangeLabel => 'tareekhon ka doraniya';

  @override
  String get addQazaCombinationCountLabel => 'mjmoe';

  @override
  String get addQazaPrayersLabel => 'Namazein';

  @override
  String get addQazaPrayersPerDateLabel => 'fi tareekh Namazein';

  @override
  String get addQazaExistingLabel => 'pehle se maujood jor';

  @override
  String get addQazaNewRecordsLabel => 'nie record';

  @override
  String get addQazaNewLabel => 'naya';

  @override
  String get addQazaAlreadyAddedLabel => 'pehle se shamil';

  @override
  String get addQazaUnavailableLabel => 'dstiab nahi';

  @override
  String get addQazaTimeBlocked =>
      'Namaz ke waqt ke ikhtitam ke baad dstiab hoga';

  @override
  String get addQazaCancelledTitle => 'Qaza shamil krna mansookh hua';

  @override
  String get addQazaCancelledMessage =>
      'izafa mansookh kar dia gia jo record pehle hi mehfooz ho chuke hin woh barqarar hin';

  @override
  String get addQazaNewQazaLabel => 'nie Qaza record';

  @override
  String get addQazaInProgress => 'Qaza shamil ho rahi hai...';

  @override
  String get qazaImportAdded => 'shamil';

  @override
  String get qazaImportSkipped => 'chhore gaye';

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
  String get qazaHistoryShowAllDates => 'tamam tareekhein dikhayein';

  @override
  String get qazaHistoryHideDates => 'tareekhein chhupayein';

  @override
  String get qazaHistoryDeletedStatus => 'delete shdh';

  @override
  String get qazaHistoryNoDates => 'koi tareekh nahi';

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
  String get commonNone => 'koi nahi';

  @override
  String get completeTitle => 'Qaza ada karein';

  @override
  String get completeHeading => 'sab se purana baqi record mukammal karein';

  @override
  String get completeIntro =>
      'aik waqt mein aik record mukammal krin kamyabi ke baad agla purana record fora dikhaya jata he';

  @override
  String get completeLoading => 'sab se purana baqi record load ho raha hai…';

  @override
  String get completeLoadError => 'aap ka Qaza record load nahi ho ska';

  @override
  String get completeNoPendingTitle => 'is Namaz ki koi Qaza baqi nhin';

  @override
  String get completeNoPendingMessage =>
      'koi aur Namaz muntakhab karein ya pehle Qaza record shamil krin';

  @override
  String get completeOldestSubtitle => 'taaza trin baqi record';

  @override
  String get completeOriginalDate => 'asal chhootne ki tareekh';

  @override
  String get completeTimestampNote => 'adaigi ka waqt alg mehfooz kya jata he';

  @override
  String get completeAction => 'taaza trin Qaza ada karein';

  @override
  String get completeInProgress => 'mukammal ho raha hai...';

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
  String get knowledgeBaseClearSearch => 'talash saaf karein';

  @override
  String get knowledgeCategoryMasail => 'masail';

  @override
  String get knowledgeCategoryMugalat => 'mughalte';

  @override
  String get knowledgeBaseTopicAll => 'tamam mozuaat';

  @override
  String get knowledgeTopicBasic => 'bunyadi batein';

  @override
  String get knowledgeTopicPrayerUnits => 'rakaat';

  @override
  String get knowledgeTopicSleepForgetfulness => 'neend aur bhool';

  @override
  String get knowledgeTopicIntentionalOmission => 'jaan bojh kar tark';

  @override
  String get knowledgeTopicFriday => 'Jumma';

  @override
  String get knowledgeTopicMenstruation => 'haiz';

  @override
  String get knowledgeTopicNifas => 'nifas';

  @override
  String get knowledgeTopicMenstruationNifas => 'haiz o nifas';

  @override
  String get knowledgeTopicMisconceptions => 'mughalte';

  @override
  String get knowledgeBaseEmptyTitle => 'Rehnumai ka koi mazmoon nahi mila';

  @override
  String get knowledgeBaseEmptyMessage =>
      'koi aur lafz talash karein ya doosra mozoo muntakhab krin';

  @override
  String get knowledgeBaseLoadError => 'Namaz ki Rehnumai load nahi ho ski';

  @override
  String get knowledgeBaseLanguage => 'Rehnumai ke mazameen ki Zaban';

  @override
  String get knowledgeArticleTitle => 'mazmoon';

  @override
  String get knowledgeArticleReferences => 'hawala jaat';

  @override
  String get knowledgeArticleRelated => 'mutaliqa mazameen';

  @override
  String get knowledgeArticleNotFound => 'mazmoon nahi mla';

  @override
  String get settingsAccountSection => 'account';

  @override
  String get settingsAccountSubtitle =>
      'apne sign in aur account ki tafseelaat snbhalin';

  @override
  String get settingsGoogleSignIn => 'Google sign in';

  @override
  String get settingsKnowledgeBaseSubtitle =>
      'Namaz ke masail aur aam ghalat fahmiyan prhin';

  @override
  String get settingsDataSection => 'Data o astorij';

  @override
  String get settingsDataSubtitle =>
      'apne Qaza Data ko snk backup ap braamd aur daraamad krin';

  @override
  String get settingsDataCloud => 'Data o Cloud';

  @override
  String get settingsDataCloudSubtitle => 'snk braamd aur daraamad ki halat';

  @override
  String get settingsResetCounterTitle => 'Qaza counter re set karein';

  @override
  String get settingsResetCounterSubtitle =>
      'darj shdh tamam Qaza Namazein delete karke ginti dobara sfr se shuru krin';

  @override
  String get settingsResetCounterEmpty =>
      're set karne ke liye koi Qaza record maujood nhin';

  @override
  String get settingsResetCounterDialogTitle => 'kya Qaza counter re set krin';

  @override
  String get settingsResetCounterDialogMessage =>
      'is account ke tamam Qaza records — baqi aur mukammal dono — is device aur aap ke Cloud backup app se hamesha ke liye delete ho jayein ge\n\naap ka counter sfr par aa jaye ga aur ab tak ki gayi progress zaya ho jaye gi yeh amal wapas nahi ho skta agar dobara zaroorat parh sakti hai to pehle apna Data braamd kar lin';

  @override
  String settingsResetCounterAcknowledge(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'mein samajhta/samajhti hon keh $count Qaza records hamesha ke liye delete ho jayein ge',
      one:
          'mein samajhta/samajhti hon keh 1 Qaza record hamesha ke liye delete ho jaye ga',
    );
    return '$_temp0';
  }

  @override
  String get settingsResetCounterConfirm => 'counter re set karein';

  @override
  String get settingsResetCounterDone => 'Qaza counter re set ho gia';

  @override
  String settingsResetCounterFailed(String error) {
    return 'Qaza counter re set nahi ho saka: $error';
  }

  @override
  String get authContinueAsGuest => 'mehmaan ke tor par jari rakhein';

  @override
  String get authGuestNote =>
      'apni Qaza progress ko apne account ke saath mehfooz rakhne ke liye baad mein Google se sign in kar sakte hin';

  @override
  String get backupPromptTitle => 'apni progress mehfooz rakhein';

  @override
  String get backupPromptBody =>
      'apni Qaza progress ko apne account ke saath mehfooz rakhne ke liye Google se sign in krin';

  @override
  String get backupPromptConfirm => 'Google se jari rakhein';

  @override
  String get backupPromptDismiss => 'abhi nahi';

  @override
  String get settingsBackupSignIn => 'backup app / sign in';

  @override
  String get settingsBackupSignInSubtitle =>
      'aap mehmaan ke tor par app istemal kar rahe hin Qaza ka backup app lene ke liye sign in krin';

  @override
  String get backupSignInFailed =>
      'sign in nakam rha aap ki progress ab bhi is device par mehfooz he';

  @override
  String get backupSignInCancelled =>
      'sign in mansookh ho gia aap ki progress ab bhi is device par mehfooz he';

  @override
  String backupSignInFailedReason(String reason) {
    return 'sign in nakam raha: $reason aap ki progress ab bhi is device par mehfooz he';
  }

  @override
  String backupMigrationDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'sign in ho gia aap ki Qaza progress ab aap ke account se munsalik he',
      one:
          'sign in ho gia aap ki Qaza progress ab aap ke account se munsalik he',
      zero:
          'sign in ho gia aap ki Qaza progress ab aap ke account se munsalik he',
    );
    return '$_temp0';
  }

  @override
  String get settingsAboutSection => 'taaruf';

  @override
  String get settingsAboutSubtitle => 'app ki maloomat aur orzhn ki tfsil';

  @override
  String settingsAboutRowSubtitle(String version) {
    return 'Qaza Namaz • orzhn $version';
  }

  @override
  String get settingsAppDescription => 'Islami Namaz Qaza tracker';

  @override
  String get cloudSyncTitle => 'Cloud sync';

  @override
  String get cloudSyncNow => 'abhi sync karein';

  @override
  String get cloudPendingChanges => 'zair iltawa tabdeeliyan';

  @override
  String get cloudLastSynced => 'aakhri sync';

  @override
  String get cloudExportImportSubtitle =>
      'user ke ikhtiyar mein JSON backup app aur mehfooz bhali in iqdamat se Cloud Data delete nahi hota';

  @override
  String get cloudInactive => 'is build mein off line astorij faal nahi he';

  @override
  String get cloudBootstrapping =>
      'is device par aap ke Qaza record tarteeb diye ja rahe hin…';

  @override
  String get cloudHydrating =>
      'aap ke mehfooz Qaza record is device par bahal kiye ja rahe hin…';

  @override
  String get cloudSynced => 'aap ke tamam Qaza record Cloud mein mehfooz hin';

  @override
  String get cloudSyncing => 'aap ka khata sync ho raha hai…';

  @override
  String get cloudOffline =>
      'off line — record is device par mehfooz hin aur khud-ba-khud sync ho jayein ge';

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
      'sync mein masla — aap ka Data is device par mehfooz he';

  @override
  String get cloudQazaCount => 'Qaza records ki tadaad';

  @override
  String cloudQazaCountValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Qaza records',
      one: '1 Qaza record',
      zero: 'koi Qaza record nahi',
    );
    return '$_temp0';
  }

  @override
  String get cloudBackupStatus => 'Cloud backup app';

  @override
  String get cloudBackupDeleted =>
      'Cloud naqal delete ho gii local records barqarar hin';

  @override
  String get cloudLocalVsCloudTitle => 'local aur Cloud Data';

  @override
  String get cloudLocalVsCloudBody =>
      'aap ke Qaza record off line istemal ke liye is device par mehfooz rehte hin sign in hone par tabdeeliyan aap ke niji Cloud account se sync ho sakti hin braamd aik local backup app he Cloud Data delete karne se local records delete nahi hote';

  @override
  String get cloudDeleteTitle => 'Cloud Data delete karein';

  @override
  String get cloudDeleteBody =>
      'yeh aap ke Cloud account se Qaza records mustaqil tor par delete kar de ga is device ke local records barqarar rahein ge yeh amal wapas nahi ho skta agar backup app darkar ho sakta hai to pehle Data braamd kar lin';

  @override
  String get cloudDeleteAcknowledge =>
      'mein samajhta/samajhti hon keh Cloud naqal mustaqil tor par delete ho jaye gi';

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
  String get accountAutomatic => 'khudkar';

  @override
  String get accountBackupPaused => 'backup app rok dia gaya hai';

  @override
  String get accountEnableBackup => 'backup app faal karein';

  @override
  String get accountDisconnect => 'Google munqati karein';

  @override
  String get accountDeleteCloudData => 'Cloud Data delete karein';

  @override
  String get accountDeleteCloudDataMessage =>
      'aap ki Cloud naqal mustaqil tor par delete ho jaye gi is device par aap ka Qaza Data barqarar rahe ga';

  @override
  String get accountDeleteCloudDataAcknowledge =>
      'mein samajhta/samajhti hon keh Cloud naqal mustaqil tor par delete ho jaye gi';

  @override
  String get accountCancel => 'mansookh';

  @override
  String get accountContinue => 'jari rakhein';

  @override
  String get accountGuestTitle => 'yeh device';

  @override
  String get accountGuestLocalDataSubtitle =>
      'aap ka Data is device par mehfooz hai';

  @override
  String get accountNotConnectedGoogle => 'Google se munsalik nahi';

  @override
  String get accountKeepProgressSafe => 'apni progress mehfooz rakhein';

  @override
  String get accountKeepProgressSafeDescription =>
      'apni Qaza progress ko mukhtalif dioaisz par backup app aur bahal karne ke liye Google account munsalik krin';

  @override
  String get accountGuestContinueMessage =>
      'aap ki mqami progress isi device par mehfooz rehti he';

  @override
  String get accountBackupSection => 'backup app';

  @override
  String get accountBackupAutomaticDescription =>
      'apni Qaza progress ka khudkar backup app lein';

  @override
  String get accountAccountActions => 'account ke iqdamat';

  @override
  String get accountSignOutDescription =>
      'apne Google account se sign out krin aap baad mein dobara sign in kar sakte hin';

  @override
  String get accountDisconnectDescription =>
      'Qaza Namaz se Google ka connection hatayein aur mehmaan mode par wapas jaiin';

  @override
  String get accountDangerZone => 'khatarnak iqdamat';

  @override
  String get settingsAccountGuestSubtitle => 'mqami • sirf yeh device';

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
  String get settingsPreferences => 'tarjeehat';

  @override
  String get settingsPreferencesSubtitle =>
      'Zaban aur zahiri shakal ki trtibat';

  @override
  String get settingsAppearance => 'zahiri shakal';

  @override
  String get settingsAppearanceSubtitle =>
      'muntakhab karein keh app is device par kaisi nazar aaie';

  @override
  String get settingsThemeSystem => 'system';

  @override
  String get settingsThemeLight => 'roshan';

  @override
  String get settingsThemeDark => 'tareek';

  @override
  String get settingsLanguage => 'Zaban';

  @override
  String get settingsLanguageSubtitle =>
      'app mein istemal hone wali Zaban muntakhab krin';

  @override
  String get settingsLanguageNote =>
      'Namaz ke naam aur Hijri tareekhein muntakhab Zaban ke mutabiq hon gi Urdu dayein se bayein likhi jati he';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageUrdu => 'Urdu';

  @override
  String get homeTodayProgressHeader => 'aaj ki progress';

  @override
  String get homeNextQazaCurrentPrayer => 'agli Qaza (mojodh Namaz)';

  @override
  String get homeOldestPending => 'sab se prani baqi';

  @override
  String get homeOverallQaza => 'majmooi Qaza';

  @override
  String get homePendingByPrayer => 'Namaz ke lihaaz se baqi';

  @override
  String get homePrayerBreakdown => 'Namaz waar jaiza';

  @override
  String get homeViewDetails => 'tafseelaat dekhein';

  @override
  String get homeViewAll => 'sab dekhein';

  @override
  String get homeCompleted => 'mukammal';

  @override
  String get homePending => 'baqi';

  @override
  String get homeDetailedStatistics => 'tafseeli aadaad o shumar';

  @override
  String get homeDetailedStatisticsSubtitle => 'majmooi aur Namaz waar tkmil';

  @override
  String get homeQazaActivity => 'Qaza sargarmi';

  @override
  String get homeProgressHistory => 'progress ki tareekh';

  @override
  String get homeRangeWeekly => 'hafta waar';

  @override
  String get homeRangeMonthly => 'mahana';

  @override
  String get homeRangeYearly => 'saalana';

  @override
  String get homeWeeklyTargetLabel => 'hafta waar hadaf';

  @override
  String get homeMonthlyTarget => 'mahana hadaf';

  @override
  String get homeProgressLabel => 'progress';

  @override
  String get homeActiveDays => 'faal din';

  @override
  String get homeActiveMonths => 'faal maheene';

  @override
  String get homeGoalReached => 'hadaf mukammal';

  @override
  String get homeRemaining => 'baqi';

  @override
  String get homeActual => 'mukammal shdh';

  @override
  String get homeNoActivity => 'is muddat mein koi Qaza mukammal nahi hoii';

  @override
  String get homeSelectDay =>
      'tafseelaat dekhne ke liye kisi din ko muntakhab krin';

  @override
  String get homePreviousWeek => 'pichla hafta';

  @override
  String get homeNextWeek => 'agla hafta';

  @override
  String get homePreviousMonth => 'pichla maheena';

  @override
  String get homeNextMonth => 'agla maheena';

  @override
  String get homePreviousYear => 'pichla saal';

  @override
  String get homeNextYear => 'agla saal';

  @override
  String get homeFutureDay => 'aane wala din';

  @override
  String get homeDailyGoalsTitle => 'aap ke rozanh ke ahdaaf';

  @override
  String get homeLastSevenDays => 'guzishta 7 din';

  @override
  String get homeGoalsAchieved => 'hadaf hasil kya';

  @override
  String get homeWeeklyTarget => 'aap ka hafta waar hadaf';

  @override
  String homeWeeklyTargetProgress(int completed, int target) {
    return '$target mein se $completed';
  }

  @override
  String get homeDayActivityDetails => 'din ki tafseelaat';

  @override
  String get homeTodayDate => 'aaj';

  @override
  String homeCurrentPrayerLabel(String prayer) {
    return 'mojodh Namaz: $prayer';
  }

  @override
  String get profileLanguageTitle => 'apni Zaban muntakhab karein';

  @override
  String get profileLanguageIntro =>
      'app mein istemal hone wali Zaban muntakhab krin';

  @override
  String get profileSetupTitle => 'apna Profile mukammal karein';

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileIntro =>
      'yeh maloomat aap ke Qaza plan aur Namaz se mutaliq qawaid ke liye istemal hon gi';

  @override
  String get profileSettingsSubtitle =>
      'aap ki Namaz Profile aur Qaza plan ki trtibat';

  @override
  String get profileGender => 'jins';

  @override
  String get profileMale => 'mard';

  @override
  String get profileFemale => 'khatoon';

  @override
  String get profileMadhab => 'mazhab / fiqhi maktab';

  @override
  String get profileHanafi => 'Hanafi';

  @override
  String get profileShafi => 'Shafai';

  @override
  String get profileMaliki => 'Maliki';

  @override
  String get profileHanbali => 'Hanbali';

  @override
  String get profileOther => 'deegar';

  @override
  String get profileDateOfBirth => 'tareekh paidaish';

  @override
  String get profileDobDay => 'din';

  @override
  String get profileDobMonth => 'maheena';

  @override
  String get profileDobYear => 'saal';

  @override
  String get profileSelectDate => 'tareekh muntakhab karein';

  @override
  String get profileSelectDobHelp => 'apni tareekh paidaish muntakhab karein';

  @override
  String get profileHijriHint =>
      'Gregorian tareekh muntakhab karne ke baad Hijri tareekh bhi dikhayi jaye gi';

  @override
  String get profileRememberDate => "Mujhe tareekh yaad hai";

  @override
  String get profileNotSure => "Mujhe yaqeen nahi";

  @override
  String get profilePubertyDate => "Puberty ki tareekh";

  @override
  String get profileIslamicBackground => "Islami pas-e-manzar";

  @override
  String get profileMuslimFromChildhood => "Main bachpan se Islam par hoon";

  @override
  String get profileAcceptedIslamLater => "Main ne baad mein Islam qabool kiya";

  @override
  String get profileIslamAcceptanceDate => "Islam qabool karne ki tareekh";

  @override
  String get profileStartPrayingDate => "Namaz shuru karne ki tareekh";

  @override
  String get profileNewMuslimQazaHelp =>
      "Qaza sirf Islam qabool karne aur Namaz farz hone ke baad shumar hogi. Islam qabool karne se pehle chhuti Namazein shamil nahi hongi.";

  String get profilePubertyAge => 'balughat ki umar';

  @override
  String get profileStartPrayingAge => 'Namaz shuru karne ki umar';

  @override
  String get profileSelectGenderFirst => 'pehle jins muntakhab karein';

  @override
  String get profileSelectPubertyFirst =>
      'pehle balughat ki umar muntakhab karein';

  @override
  String get profileSelectDobFirst => 'pehle tareekh paidaish muntakhab karein';

  @override
  String get profileWitr => 'Witr';

  @override
  String get profileWitrOptional =>
      'deegar ke liye aap muntakhab kar sakte hin keh Witr shamil hon ya nhin';

  @override
  String get profileWitrIncluded => 'shamil';

  @override
  String get profileWitrExcluded => 'shamil nahi';

  @override
  String get profileSubmit => 'jari rakhein';

  @override
  String get profileSave => 'tabdeeliyan mehfooz karein';

  @override
  String get profileEdit => 'Profile mein tarmeem karein';

  @override
  String profileAgeYears(int count) {
    return '$count saal';
  }

  @override
  String get profileDiscardChangesTitle =>
      'ghair mehfooz tabdeeliyan mustarad krin';

  @override
  String get profileDiscardChangesMessage =>
      'aap ki tabdeeliyan mehfooz nahi hoiin kya aap unhein mustarad karke tarmeem se bahar nikalna chahte hin';

  @override
  String get profileDiscardChangesAction => 'tabdeeliyan mustarad karein';

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
      'aap ki Profile mein tabdeeli se hisaab shdh Qaza plan badalta he';

  @override
  String get profileQazaReviewError =>
      'Qaza plan ka jaiza tiar nahi ho ska dobara koshish krin';

  @override
  String get profileQazaApplying => 'Qaza plan laagu ho raha hai…';

  @override
  String get profileQazaImpact => 'asar';

  @override
  String profileQazaCount(String count) {
    return '$count Qaza';
  }

  @override
  String get profileQazaPreviousTotal => 'pichla plan';

  @override
  String get profileQazaNewTotal => 'naya plan';

  @override
  String get profileQazaCompletedInPlan => 'nie plan mein mukammal shdh';

  @override
  String get profileQazaToAdd => 'nayi Qaza jori jaye gi';

  @override
  String get profileQazaRestored => 'pehle hatayi gayi Qaza bahal ki jaye gi';

  @override
  String get profileQazaUpdatedKeptExisting =>
      'Profile app date hogii mojodh Qaza record barqarar rhe';

  @override
  String get profileQazaNoLongerRequired =>
      'woh zair iltawa Qaza jo ab darkar nahi';

  @override
  String get profileQazaKeepExisting => 'mojodh Qaza record barqarar rakhein';

  @override
  String get profileQazaApply => 'Qaza plan laagu karein';

  @override
  String get profileQazaCompletedProtected =>
      'mukammal shdh aur dasti tor par shamil ki gayi Qaza delete nahi hogi';

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
  String get qazaReviewTitle => 'apna Qaza plan dekhein';

  @override
  String get qazaReviewSubtitle =>
      'Qaza tracker mein shamil karne se pehle apni tafseelaat ka jaiza lin';

  @override
  String get qazaReviewTotal => 'kal andaza Qaza Namazein';

  @override
  String get qazaReviewPeriod => 'Qaza ki muddat';

  @override
  String get qazaReviewBreakdown => 'Namaz waar tafseel';

  @override
  String get qazaReviewNote =>
      'yeh aap ke Profile ki maloomat ki bunyad par Qaza Namazon ka andaza he';

  @override
  String get qazaReviewEdit => 'apni tafseelaat mein tarmeem karein';

  @override
  String get qazaReviewAdd => 'Qaza ko mere tracker mein shamil karein';

  @override
  String get qazaReviewAdding => 'Qaza shamil ho rahi hai…';

  @override
  String get qazaReviewError => 'Qaza shamil nahi ho ski dobara koshish krin';

  @override
  String get profileErrorLanguage => 'barah karam Zaban muntakhab krin';

  @override
  String get profileErrorGender => 'barah karam apni jins muntakhab krin';

  @override
  String get profileErrorMadhab =>
      'barah karam apna fiqhi maktab muntakhab krin';

  @override
  String get profileErrorDob => 'barah karam durust tareekh paidaish darj krin';

  @override
  @override
  String get profileErrorIslamAcceptanceDate =>
      "Barah-e-karam Islam qabool karne ki durust tareekh dein jo tareekh paidaish se pehle na ho.";

  @override
  String get profileErrorPuberty =>
      'muntakhab jins ke liye durust balughat ki umar muntakhab krin';

  @override
  String get profileErrorStartPraying =>
      "Barah-e-karam Namaz shuru karne ki durust umar ya tareekh muntakhab karein.";

  @override
  String get profileErrorWitr =>
      'barah karam Witr ki durust tarteeb muntakhab krin';

  @override
  String get navPrayerTime => 'Namaz ke auqat';

  @override
  String get prayerTimeTitle => 'Namaz ke auqat';

  @override
  String get prayerTimeLocation => 'maqam';

  @override
  String get prayerTimeUseCurrentLocation => 'mojodh maqam istemal karein';

  @override
  String get prayerTimeSelectCity => 'shehar muntakhab karein';

  @override
  String get prayerTimeSelectCountry => 'mulk muntakhab karein';

  @override
  String get prayerTimeSearchCity => 'shehar talash karein';

  @override
  String get prayerTimeCurrentLocation => 'mojodh maqam';

  @override
  String get prayerTimeSavedLocation => 'mehfooz maqam';

  @override
  String get prayerTimeToday => 'aaj';

  @override
  String get prayerTimeRestrictedTimes => 'mehdood auqat';

  @override
  String get prayerTimeActive => 'faal';

  @override
  String get prayerTimeLocationUnavailable => 'maqam dstiab nahi';

  @override
  String get prayerTimeLocationPermission =>
      'mojodh maqam istemal karne ke liye maqam ki ajazt darkar he';

  @override
  String get prayerTimeLocationServiceRequired =>
      'mojodh maqam istemal karne ke liye location services ko on krna zaroori he';

  @override
  String get prayerTimeEnableLocation => 'maqam on karein';

  @override
  String get prayerTimeSelectLocation => 'apna maqam muntakhab karein';

  @override
  String get prayerTimeCalculationMethod => 'hisaab ka tareeqa';

  @override
  String get prayerTimeAsrMethod => 'Asr ka tareeqa';

  @override
  String get prayerTimeHighLatitudeRule => 'buland arz balad ka usool';

  @override
  String get prayerTimeAdjustments => 'tadeelaat';

  @override
  String get prayerTime12Hour => '12 ghante';

  @override
  String get prayerTime24Hour => '24 ghante';

  @override
  String get prayerTimeStandard => 'mayari';

  @override
  String get prayerTimeHanafi => 'Hanafi';

  @override
  String get prayerTimeAutomatic => 'khudkar';

  @override
  String get prayerTimeMiddleOfTheNight => 'nisf shab';

  @override
  String get prayerTimeSeventhOfTheNight => 'raat ka satwan hissa';

  @override
  String get prayerTimeTwilightAngle => 'shafaq ka zaviya';

  @override
  String get prayerTimeCustom => 'hasb zaroorat';

  @override
  String get prayerTimeFajrAngle => 'Fajr ka zaviya';

  @override
  String get prayerTimeIshaAngle => 'Isha ka zaviya';

  @override
  String get prayerTimeSave => 'mehfooz karein';

  @override
  String get prayerTimeCountry => 'mulk';

  @override
  String get prayerTimeCity => 'shehar';

  @override
  String get prayerTimeNoCities => 'koi mutabiqat rakhne wala shehar nahi';

  @override
  String get prayerTimeSettings => 'Namaz ke auqat ki Settings';

  @override
  String get prayerTimeLocationData => 'maqam ka Data';

  @override
  String get settingsLicensesSoftwareTitle =>
      'open source soft ware ke license';

  @override
  String get settingsLicensesSoftwareSubtitle =>
      'Flutter pikijz mqami libraries aur shamil fonts';

  @override
  String get settingsLicensesGeoNamesTitle => 'GeoNames shehri Data';

  @override
  String get settingsLicensesGeoNamesSubtitle =>
      'off line shehron aur maqamat ke Data ki nsbt';

  @override
  String get prayerTimeLocationDataAttribution =>
      'shehri Data © GeoNames CC BY 4.0 ke tehat license yafta he';

  @override
  String get prayerTimeUpdated => 'app date';

  @override
  String get prayerTimeNoSchedule =>
      'Namaz ke auqat abhi tarteeb nahi diye gie';

  @override
  String get prayerTimeSetupTitle => 'Namaz ke auqat tarteeb din';

  @override
  String get prayerTimeSetupBody =>
      'apna mojodh maqam istemal karein ya mulk aur shehar muntakhab krin maqam mehfooz hone ke baad yeh off line kam kare ga';

  @override
  String get prayerTimeRefresh => 'maqam taaza karein';

  @override
  String prayerTimeEndsIn(String duration) {
    return 'ikhtitam mein $duration';
  }

  @override
  String prayerTimeRemaining(String duration) {
    return 'baqi waqt $duration';
  }

  @override
  String prayerTimeStartsIn(String duration) {
    return 'shuru hone mein $duration';
  }

  @override
  String prayerTimeNextRestricted(String name) {
    return 'agla: $name';
  }

  @override
  String prayerTimeUpcomingPrayer(String name) {
    return 'Agli namaz: $name';
  }

  @override
  String prayerTimeUsingSavedLocation(String location) {
    return 'aap ka mehfooz maqam istemal ho raha hai: $location';
  }

  @override
  String get prayerTimeAngleHint => 'darjaat mein darj krin';

  @override
  String get prayerTimeAdjustmentMinutes => 'minute';

  @override
  String get prayerTimeSunrise => 'tlo aftab';

  @override
  String get prayerTimeZawal => 'zawal';

  @override
  String get prayerTimeSunset => 'ghrob aftab';

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
  String get qiblaTitle => 'qibla';

  @override
  String get qiblaDirection => 'qibla ki simt';

  @override
  String get qiblaBearing => 'qibla ka zaviya';

  @override
  String get qiblaFromTrueNorth => 'haqeeqi shumal se';

  @override
  String get qiblaUnavailable => 'qibla dstiab nahi';

  @override
  String get qiblaLocationRequired =>
      'qibla maloom karne ke liye maqam muntakhab ya mehfooz krin';

  @override
  String get qiblaCompassBody =>
      'phone ghmaiin teer qibla ki taraf Rehnumai kare ga';

  @override
  String get qiblaSensorUnavailableBody =>
      'is aale mein compass sensor dstiab nhin is liye jamid qibla simt dikhayi ja rahi he';

  @override
  String get qiblaHeadingUnavailable =>
      'compass ki simt aarzi tor par dstiab nhin';

  @override
  String get qiblaTurnToDirection => 'phone ko is simt ghmaiin';

  @override
  String qiblaCompassAccuracy(String degrees) {
    return 'compass ki durustagi ±$degrees°';
  }

  @override
  String get qiblaCalibrationHint =>
      'compass ki durustagi kam he phone ko 8 ki shakal mein harkat de kar dobara calibrate krin';

  @override
  String get accountAutomaticBackup => 'khudkar backup app';

  @override
  String get accountBackupStatusChecking =>
      'backup app ki halat dekhi ja rahi hai…';

  @override
  String get accountBackupStatusDisabled => 'khudkar backup app band hai';

  @override
  String accountBackupStatusBackedUp(Object timestamp) {
    return '✓ backup app mukammal · $timestamp';
  }

  @override
  String get accountBackupStatusBackingUp =>
      'aap ki progress ka backup app liya ja raha hai…';

  @override
  String get accountBackupStatusPending => 'backup app zair iltawa hai';

  @override
  String get accountBackupStatusWaitingConnection =>
      'connection ka intezar hai';

  @override
  String get accountBackupStatusComplete => 'backup app mukammal ho gaya';

  @override
  String accountBackupStatusCompletedAt(Object timestamp) {
    return '$timestamp';
  }

  @override
  String get accountBackupStatusWaitingConnectionMessage =>
      'aap ka Qaza Data is device par mehfooz he';

  @override
  String get accountBackupStatusFailedTitle =>
      'backup app mukammal nahi ho saka';

  @override
  String get accountBackupStatusFailedMessage =>
      'aap ka Qaza Data is device par mehfooz he';

  @override
  String get accountBackupStatusAuthRequired =>
      'Google session bahal karne ki zaroorat he';

  @override
  String get accountBackupStatusSecurityRejected =>
      'security tsdiq ne Cloud rasai mustarad kar di';

  @override
  String get accountBackupStatusNetwork =>
      'internet connection maujood nhin connection bahal hone par backup app dobara jari hoga';

  @override
  String get accountBackupStatusCloudStateInvalid =>
      'Cloud backup app ki halat badal gayi he dobara koshish krin';

  @override
  String get accountBackupStatusFailedAutomaticRetry =>
      'hm khudkar tor par dobara koshish karein ge';

  @override
  String get accountBackupStatusRetry => 'dobara koshish karein';

  @override
  String get accountBackupStatusFailed =>
      'backup app mukammal nahi ho ska hm khudkar tor par dobara koshish karein ge';

  @override
  String get startupProfileLoadErrorTitle => 'mqami Profile load nahi ho saka';

  @override
  String get startupProfileLoadErrorMessage =>
      'aap ki mqami astorij ko mehfooz tareeqe se parha nahi ja ska aap ka mojodh Qaza Data tabdeel nahi kya gia dobara koshish krin';

  @override
  String get qazaHistoryTitle => 'Qaza ki tareekh';

  @override
  String get qazaHistoryRecentAdditions => 'haalya izafay';

  @override
  String get qazaHistoryRecentlyDeleted => 'haal hi mein delete shdh';

  @override
  String get qazaHistoryNoAdditions => 'abhi koi Qaza izafa maujood nhin';

  @override
  String get qazaHistoryNoRecentlyDeleted =>
      'haal hi mein delete shdh koi Qaza nhin';

  @override
  String get qazaHistoryLoadMore => 'mzid load karein';

  @override
  String get qazaHistoryOriginalDateUnavailable => 'asal tareekh dstiab nahi';

  @override
  String get qazaHistoryDeletedQaza => 'delete shdh Qaza';

  @override
  String qazaHistoryDeletedQazaCount(int count) {
    return '$count Qaza delete huin';
  }

  @override
  String get qazaHistoryRestore => 'bahal karein';

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
  String get qazaAdditionNotFound => 'yeh Qaza izafa nahi mil ska';

  @override
  String qazaAdditionRecordsCount(int count) {
    return '$count records';
  }

  @override
  String get qazaAdditionNoPrayers => 'koi Namaz nahi';

  @override
  String get qazaAdditionViewRecords => 'records dekhein';

  @override
  String get qazaAdditionMoreActions => 'mzid iqdamat';

  @override
  String get qazaAdditionEdit => 'izafay mein tarmeem';

  @override
  String get qazaAdditionDelete => 'izafa delete karein';

  @override
  String get qazaAdditionDeleteConfirmTitle => 'yeh Qaza izafa delete krin';

  @override
  String get qazaAdditionDeleteConfirmMessage =>
      'sirf ghair tabdeel shdh zair iltawa records delete hon ge mukammal ya tabdeel shdh records mehfooz rahein ge';

  @override
  String get qazaAdditionDeletedNothing =>
      'delete karne ke liye koi ahl record nahi mla mehfooz records barqarar hin';

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
      'muntakhab ya ghair muntakhab karne ke liye touch krin';

  @override
  String get qazaTrackerSwipeHint =>
      'tafseel dekhne ke liye tap krin mukammal karne ke liye dayein ya bayein swipe krin muntakhab karne ke liye der tak dbaiin';

  @override
  String get qazaMarkSelectedPendingTitle =>
      'muntakhab Qaza ko zair iltawa krin';

  @override
  String qazaMarkSelectedPendingMessage(int count) {
    return '$count mukammal Qaza dobara zair iltawa ho jayein gi aur mukammal shdh shumar nahi hon gi';
  }

  @override
  String get qazaMarkAsPending => 'zair iltawa karein';

  @override
  String qazaMarkAsPendingCount(int count) {
    return 'zair iltawa karein ($count)';
  }

  @override
  String get qazaNoCompletedTitle => 'koi mukammal Qaza nahi';

  @override
  String get qazaNoCompletedMessage => 'mukammal Qaza yahan dikhayi din gi';

  @override
  String get qazaReturnedToPending => 'Qaza dobara zair iltawa ho gii';

  @override
  String get qazaSelectedPendingNothingChanged =>
      'muntakhab Qaza mein koi tabdeeli nahi hoii';

  @override
  String get qazaCorrectionChanged =>
      'yeh Qaza durust nahi ki ja saki kyunke yeh tabdeel ho gayi he';

  @override
  String get qazaFilter => 'filter';

  @override
  String get qazaFiltersActive => 'filter faal hin';

  @override
  String get qazaOriginalDateLabel => 'Qaza ki tareekh';

  @override
  String get qazaCompletedDateLabel => 'mukammal hone ki tareekh';

  @override
  String get qazaFilterCompletedDateHelp =>
      'mukammal hone ki tareekh ke mutabiq filter karein';

  @override
  String get qazaUndoCompletions => 'mukammal Qaza wapas karein';

  @override
  String get qazaUndoSelected => 'muntakhab wapas karein';

  @override
  String get qazaUndoAll => 'sab wapas karein';

  @override
  String qazaUndoQazaCount(int count) {
    return '$count Qaza';
  }

  @override
  String get addQazaManageAddition => 'is izafay ko munazzam karein';

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
  String get qazaUndoExpired => 'wapas karne ka 5 second ka waqt khtm ho gia';

  @override
  String get qazaUndoStaleBatch =>
      'wapas karne ka yeh ikhtiyar ab dstiab nahi kyunke is ke baad aik naya Undo amal hua he';

  @override
  String get qazaUndoTargetChanged =>
      'wapas karne ka ikhtiyar dstiab nahi kyunke Qaza record badal chuka ya delete ho chuka he';

  @override
  String get qazaUndoFailed =>
      'Qaza wapas nahi ho ski barah karam dobara koshish krin';

  @override
  String get qazaMarkAsPendingMessage =>
      'yeh Qaza dobara zair iltawa ho jaye gi aur mukammal shdh shumar nahi hogi';

  @override
  String get commonDelete => 'delete karein';

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
    return 'backup app kamyabi se bahal ho gia $count Qaza record bahal kiye gie';
  }

  @override
  String dataImportRestoreSummary(
      int records, int accounts, int revision, String onboarding) {
    return 'is backup app mein $records Qaza record aur $accounts mqami account hin\n\nbahal karne se is device ka mojodh mqami Data muntakhab backup app se badal jaye ga aap ki device shanakht isi device par barqarar rahe gi\n\nbackup app revision: $revision\non boarding: $onboarding';
  }

  @override
  String get dataImportOnboardingComplete => 'mukammal';

  @override
  String get dataImportOnboardingIncomplete => 'mukammal nahi';

  @override
  String get dataLocalOnlyNote =>
      'sirf mqami backup ap aap ka Qaza Data isi device par rehta he jab tak aap usay wazeh tor par braamd na krin';

  @override
  String get cloudBackupTitle => 'Cloud backup app';

  @override
  String get cloudBackupDescription =>
      'apni Qaza ki progress ka Google Drive app Data mein alg backup app mehfooz rkhin';

  @override
  String get cloudConnect => 'Google se sign in karein';

  @override
  String get cloudDisconnect => 'Sign out';

  @override
  String get cloudConnected => 'munsalik';

  @override
  String get cloudNotConnected =>
      'apni progress ka backup app rakhne ke liye Google account munsalik krin';

  @override
  String get cloudBackupNow => 'abhi backup app karein';

  @override
  String get cloudAutomaticBackup => 'khudkar backup app';

  @override
  String get cloudLastBackup => 'aakhri kamyab backup app';

  @override
  String get cloudNeverBackedUp => 'abhi tak backup app nahi hua';

  @override
  String get cloudBackupSucceeded => 'Cloud backup app/sync mukammal ho gia';

  @override
  String get cloudBackupUpToDate => 'backup app pehle hi taaza trin he';

  @override
  String get cloudBackupConflictTitle => 'tabdeeliyon mein farq mila';

  @override
  String get cloudBackupConflictMessage =>
      'is device aur Google Drive par mukhtalif progress maujood he muntakhab karein keh kon sa Data rakhna he';

  @override
  String get cloudKeepLocal => 'is device ki progress rakhein';

  @override
  String get cloudUseRemote => 'Google Drive se bahal karein';

  @override
  String get cloudKeepLocalConfirmTitle => 'is device ki progress rkhin';

  @override
  String get cloudKeepLocalConfirmMessage =>
      'is device ke Data se naya Cloud backup app banaya jaye ga mojodh remote backup app apni tareekh mein barqarar rahe ga';

  @override
  String get cloudUseRemoteConfirmTitle => 'mqami progress tabdeel krin';

  @override
  String get cloudUseRemoteConfirmMessage =>
      'mojodh mqami app Data Google Drive ke backup app se badal jaye ga pehle aik khufiya karda mqami recovery snap shot mehfooz kya jaye ga';

  @override
  String get cloudDisconnectConfirmTitle => 'Google munqati krin';

  @override
  String get cloudDisconnectConfirmMessage =>
      'khudkar Cloud kam band kar dia jaye ga aap ka Qaza Data isi device par mehfooz rahe ga';

  @override
  String get cloudRecoveryAvailable =>
      'pichle mqami Data ka mehfooz recovery snap shot dstiab he';

  @override
  String get cloudRecoverLocal => 'pichla mqami Data bahal karein';

  @override
  String get cloudRecoveryConfirmTitle => 'pichla mqami Data bahal krin';

  @override
  String get cloudRecoveryConfirmMessage =>
      'mehfooz mqami snap shot is device ke mojodh app Data ki jgh le ga';

  @override
  String get cloudAutomaticBackupRequiresConnection =>
      'khudkar backup app faal karne se pehle Google munsalik krin';

  @override
  String get cloudBackupWorking => 'backup app ho raha hai…';

  @override
  String get cloudSetupChoiceTitle => 'Qaza Namaz mein khush aamdeed';

  @override
  String get cloudSetupChoiceDescription =>
      'apni chhoti hui Namazon ka hisaab rakhein aur Qaza ki progress ko apni sahulat ke mutabiq munazzam krin aap ka record isi device par mehfooz rehta he mukhtalif dioaisz par backup app aur bahali ke liye aap ikhtiyari tor par Google istemal kar sakte hin';

  @override
  String get cloudAccountChoiceTitle => "Google account muntakhib karein";

  @override
  String get cloudAccountChoiceDescription =>
      "Pehle istemal shuda account muntakhib karein, ya naye Google account ke sath jari rakhein.";

  @override
  String get cloudContinueNewAccount => "Naye account ke sath jari rakhein";

  @override
  String get cloudSignOutPendingTitle => "Tabdeeliyon ka backup nahi hua";

  @override
  String get cloudSignOutPendingMessage =>
      "Haliya tabdeeliyon ka Google Drive par backup nahi hua. Ab sign out karne par yeh isi device par rahengi, lekin Google backup mein mehfooz nahi hongi.";

  @override
  String get cloudSignOutAnyway => "Phir bhi sign out karein";

  @override
  String get cloudBackupAndSignOut => "Backup le kar sign out karein";

  @override
  String get guestGooglePromptTitle => "Apni Qaza progress mehfooz rakhein";

  @override
  String get guestGooglePromptMessage =>
      "Apni Qaza ka backup banane aur device badalne par bahal karne ke liye Google account connect karein.";

  @override
  String get cloudSetupUseGoogle => 'Google ke saath jari rakhein';

  @override
  String get cloudSetupContinueLocal => 'Guest ke tor par jari rakhein';

  @override
  String get cloudConnectionFailed =>
      'Google se rabta mukammal nahi ho ska dobara koshish karein ya mqami tor par jari rkhin';

  @override
  String get dailySalahTrackingTitle => "Rozana Namaz ka Record";

  @override
  String get dailySalahTrackingEnableTitle => "Rozana Namaz Tracking On Karein";

  @override
  String get dailySalahTrackingEnableSubtitle =>
      "Parhi hui ya reh jane wali namazen record karein. Jo namaz record na ho, use khud-ba-khud missed mark nahi kiya jata.";

  @override
  String get dailySalahTrackingEnableAction => "On Karein";
  @override
  String get dailySalahTrackingSkipForNow => "Filhal chhor dein";

  @override
  String get dailySalahTrackingSkippedMessage =>
      "Daily Namaz Tracking skip kar di gayi hai. Aap ise Profile se kisi bhi waqt enable kar sakte hain.";

  @override
  String get dailySalahTrackingRemoveStatusTitle => "Namaz ka status hatayen?";

  @override
  String get dailySalahTrackingRemoveStatusMessage =>
      "Is se namaz unrecorded ho jayegi. Mojooda Qaza record mein koi tabdeeli nahi hogi.";

  @override
  String get dailySalahTrackingRemoveStatusAction => "Status hatayen";

  @override
  String get dailySalahTrackingPrayed => "Parhi";

  @override
  String get dailySalahTrackingMissed => "Reh gayi";

  @override
  String get dailySalahTrackingUnrecorded => "Record nahi";

  @override
  String get dailySalahTrackingConfirmMissedTitle =>
      "Namaz ko missed record karein?";

  @override
  String get dailySalahTrackingConfirmMissedMessage =>
      "Is se namaz ka status Missed ho jayega aur Qaza Pending hogi. Agar matching Qaza pehle hi Completed hai, to use dobara Pending kar diya jayega.";

  @override
  String get dailySalahTrackingConfirmPrayedTitle =>
      'Namaz ko parhi hui mark karein?';

  @override
  String get dailySalahTrackingConfirmPrayedMessage =>
      'Is se namaz ka status Parhi ho jayega aur is se linked Qaza record mukammal ho jayega.';

  @override
  String get dailySalahTrackingUndoQaza =>
      "Tracker ka banaya Qaza wapas karein";

  @override
  String get dailySalahTrackingUndoTitle => "Yeh Qaza record hatayein?";

  @override
  String get dailySalahTrackingUndoMessage =>
      "Sirf Daily Salah Tracking ka banaya hua yahi Qaza record hataya jayega, aur sirf jab woh pending ho.";

  @override
  String get dailySalahTrackingPreviousDay => "Pichla din";

  @override
  String get dailySalahTrackingNextDay => "Agla din";

  @override
  String get dailySalahTrackingUndoUnavailable =>
      "Yeh Qaza record ab pending nahi, is liye hataya nahi gaya.";

  @override
  String get cloudRestoreProgressTitle =>
      'Google Drive backup restore ho raha hai';

  @override
  String get cloudRestoreProgressBody =>
      'Aap ka data download, verify aur mehfooz tareeqe se restore ho raha hai. App khuli rakhein.';

  @override
  String get cloudRestoreConnectingTitle =>
      'Google Drive se connection ho raha hai';

  @override
  String get cloudRestoreConnectingBody =>
      'Google account check ho raha hai aur mojooda backup talash kiya ja raha hai.';

  @override
  String get cloudRestoreStageChecking =>
      'Backup check aur verify ho raha hai…';

  @override
  String get cloudRestoreStageRestoring =>
      'Verified backup restore ho raha hai…';

  @override
  String get cloudRestoreStageTransferring =>
      'Backup data transfer ho raha hai…';

  @override
  String get cloudRestoreStageFinishing => 'Restore mukammal ho raha hai…';

  @override
  String get initialCloudBackupAppBarTitle => 'Apni progress mehfooz karein';

  @override
  String get initialCloudBackupTitle =>
      'Pehla Google Drive backup ban raha hai';

  @override
  String get initialCloudBackupBody =>
      'Aap ka profile aur Qaza Namaz data device par save hai. Initial backup banne tak app khuli rakhein.';

  @override
  String get initialCloudBackupFailedTitle =>
      'Aap ka data is device par mehfooz hai';

  @override
  String get initialCloudBackupFailedBody =>
      'Cloud backup mukammal nahi ho saka. Aap ka local profile aur Qaza data mehfooz hai.';

  @override
  String get initialCloudBackupStageChecking =>
      'Google Drive check ho raha hai…';

  @override
  String get initialCloudBackupStagePreparing => 'Backup tayyar ho raha hai…';

  @override
  String get initialCloudBackupStageUploading => 'Backup upload ho raha hai…';

  @override
  String get initialCloudBackupStageCompleted =>
      'Backup kamyabi se save ho gaya';

  @override
  String get initialCloudBackupRetry => 'Backup dobara try karein';

  @override
  String get initialCloudBackupContinueHome => 'Home par jayein';

  @override
  String get initialCloudBackupStageDownloading =>
      'Backup download ho raha hai…';

  @override
  String get profileEstimateUsingAge => 'Umar ke andazay se';
}
