// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Qaza Namaz';

  @override
  String get navHome => 'Home';

  @override
  String get navQaza => 'Qaza';

  @override
  String get navKnowledge => 'Knowledge';

  @override
  String get settingsRemindersSection => 'Reminders';

  @override
  String get settingsRemindersSubtitle =>
      'Daily reminder to complete your Qaza.';

  @override
  String get settingsBackupSection => 'Data & Storage';

  @override
  String get settingsBackupSubtitle => 'Cloud sync, export and import.';

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
  String get statusPending => 'Pending';

  @override
  String get statusDeleted => 'Recently deleted';

  @override
  String get statusCompleted => 'Completed';

  @override
  String get qazaSelectAllMatching => 'Select all matching';

  @override
  String qazaSelectAllMatchingCapped(String count) {
    return 'Selected the first $count matching records.';
  }

  @override
  String qazaConfirmBulkTitle(String count) {
    return 'Complete $count records?';
  }

  @override
  String qazaConfirmBulkMessage(String count) {
    return 'This marks $count pending prayers as completed. You can undo it straight afterwards, but not later.';
  }

  @override
  String get qazaConfirmBulkAction => 'Complete them';

  @override
  String get errorNetwork =>
      'No connection. Your Qaza are saved on this device and will sync when you are back online.';

  @override
  String get errorTimeout => 'That took too long. Try again in a moment.';

  @override
  String get errorPermission =>
      'Permission is needed for this. Open Settings to grant it.';

  @override
  String get errorAuthentication => 'You need to be signed in for this.';

  @override
  String get errorValidation =>
      'That input was not accepted. Check it and try again.';

  @override
  String get errorMalformedData =>
      'That file is not a Qaza backup, or it is damaged.';

  @override
  String get errorStorage =>
      'This device could not save the change. Free some space and try again.';

  @override
  String get errorUnknown => 'Something went wrong.';

  @override
  String get commonOpenSettings => 'Open Settings';

  @override
  String get homeTartibCheckingTitle => 'Checking the prayer order';

  @override
  String get homeTartibCheckingBody =>
      'Sahib al-Tartib decides which Fard prayer comes next. One moment.';

  @override
  String get homeTartibFailedTitle => 'Could not check the prayer order';

  @override
  String get homeTartibFailedBody =>
      'Fard prayers are held back until the order is known, so nothing is completed out of sequence. Witr can still be completed from the prayer menu.';

  @override
  String get qazaSortLabel => 'Sort';

  @override
  String get qazaSortOldestFirst => 'Oldest first';

  @override
  String get qazaSortNewestFirst => 'Newest first';

  @override
  String get filterAll => 'All';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonTotal => 'Total';

  @override
  String get commonVersion => 'Version';

  @override
  String get stateErrorTitle => 'Something went wrong';

  @override
  String get prayerRakatFajr => 'Fajr • 2 Rakat Fard';

  @override
  String get prayerRakatZuhr => 'Zuhr • 4 Rakat Fard';

  @override
  String get prayerRakatAsr => 'Asr • 4 Rakat Fard';

  @override
  String get prayerRakatMaghrib => 'Maghrib • 3 Rakat Fard';

  @override
  String get prayerRakatIsha => 'Isha • 4 Rakat Fard';

  @override
  String get prayerRakatWitr => 'Witr • 3 Rakat Wajib • Independent';

  @override
  String get syncSettingUp => 'Setting up';

  @override
  String get syncSettingUpDetail =>
      'Preparing your Qaza records on this device.';

  @override
  String get syncRestoring => 'Restoring';

  @override
  String get syncRestoringDetail =>
      'Bringing your saved Qaza records to this device.';

  @override
  String get syncSynced => 'Synced';

  @override
  String syncSyncedAt(String timestamp) {
    return 'Synced • $timestamp';
  }

  @override
  String get syncSyncing => 'Syncing';

  @override
  String get syncSaved => 'Saved';

  @override
  String get syncSavedDetail =>
      'Your changes are saved on this device and will sync automatically.';

  @override
  String get syncErrorLabel => 'Sync Error';

  @override
  String get syncErrorDetail =>
      'Your changes are saved on this device. We will retry automatically.';

  @override
  String get commonClose => 'Close';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonDone => 'Done';

  @override
  String get commonReset => 'Reset';

  @override
  String get commonClear => 'Clear';

  @override
  String get commonBack => 'Back';

  @override
  String get commonContinue => 'Continue';

  @override
  String get commonLoading => 'Loading...';

  @override
  String hijriDate(Object day, Object month, Object year) {
    return '$day $month $year AH';
  }

  @override
  String get homeTitle => 'Home';

  @override
  String get homeProfileTooltip => 'Profile';

  @override
  String get homeHeadingSetup => 'Start Your Qaza Journey';

  @override
  String get homeHeadingPending => 'Keep going';

  @override
  String get homeHeadingCompleted => 'You are all caught up';

  @override
  String get homeSetupMessage => 'You haven\'t added any Qaza prayers yet.';

  @override
  String get homeCompleteQaza => 'Complete Qaza';

  @override
  String get homeAddNewQaza => 'Add New Qaza';

  @override
  String get homeAddManually => 'Add Qaza Manually';

  @override
  String get homeStatTotal => 'Total';

  @override
  String get homeAddQaza => 'Add Qaza';

  @override
  String homeCompletedCount(int count) {
    return '$count completed';
  }

  @override
  String get homeProgressTitle => 'Your progress';

  @override
  String get homeProgressError =>
      'Unable to load your Qaza progress. Pull to retry.';

  @override
  String get homeTodayProgress => 'Today\'s progress';

  @override
  String homeDailyProgress(int completed, int target) {
    return '$completed / $target completed';
  }

  @override
  String homeDailyRemaining(int count) {
    return '$count remaining';
  }

  @override
  String get homeQazaPlan => 'Qaza plan';

  @override
  String get homeCompleteOldestQaza => 'Complete Oldest Qaza';

  @override
  String get homeAuto => 'Auto';

  @override
  String get homeQazaTargetReachedTitle => 'Alhamdulillah!';

  @override
  String get homeQazaTargetReachedMessage =>
      'You have completed your Qaza plan for today.\nMay Allah accept your efforts.';

  @override
  String get homeDailyTarget => 'Daily target';

  @override
  String homePerDay(int count) {
    return '$count per day';
  }

  @override
  String homeEstimatedCompletion(String date) {
    return 'Estimated completion: $date';
  }

  @override
  String get homeNextQaza => 'Next Qaza';

  @override
  String get homeCompleteNextQaza => 'Complete next Qaza';

  @override
  String get homeViewAllQaza => 'View all Qaza';

  @override
  String get homeDailyProgressError => 'Today\'s progress could not be loaded.';

  @override
  String progressPendingCompleted(String pending, String completed) {
    return '$pending pending • $completed completed';
  }

  @override
  String progressCompletedPending(String completed, String pending) {
    return '$completed completed • $pending pending';
  }

  @override
  String get qazaTitle => 'Qaza';

  @override
  String get qazaProgressLabel => 'Progress';

  @override
  String get qazaAddTooltip => 'Add Qaza';

  @override
  String get qazaDateFilterAny => 'Original date: any';

  @override
  String get qazaDateFilterHelp => 'Filter by original Qaza date';

  @override
  String qazaDateFilterRange(String from, String to) {
    return '$from — $to';
  }

  @override
  String get qazaLoading => 'Loading your Qaza records...';

  @override
  String get qazaEmptyTitle => 'No Qaza records yet';

  @override
  String get qazaEmptyMessage =>
      'Add missed prayers or calculate an estimate to begin.';

  @override
  String get qazaFilteredEmptyTitle => 'No records match these filters';

  @override
  String get qazaFilteredEmptyMessage =>
      'Try a different status, prayer or date range.';

  @override
  String get qazaResetFilters => 'Reset filters';

  @override
  String qazaLoadError(String error) {
    return 'Could not load your Qaza records: $error';
  }

  @override
  String qazaLoadMoreError(String error) {
    return 'Could not load more records: $error';
  }

  @override
  String qazaCompleteError(String error) {
    return 'Could not complete the selected Qaza: $error';
  }

  @override
  String get qazaTartibRequiredTitle => 'Qaza order is required';

  @override
  String qazaTartibRequiredMessage(int count, String prayer) {
    return 'You have $count outstanding Fard prayers. According to this ruling, complete $prayer Qaza before other pending prayers.';
  }

  @override
  String qazaTartibBlocked(String prayer) {
    return 'Qaza order is required. Complete $prayer Qaza first.';
  }

  @override
  String qazaCompletedOn(String date) {
    return 'Completed $date';
  }

  @override
  String qazaCompleteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Complete $count Qaza',
      one: 'Complete 1 Qaza',
    );
    return '$_temp0';
  }

  @override
  String get qazaRecordActions => 'Record actions';

  @override
  String get qazaEditRecord => 'Edit';

  @override
  String get qazaDeleteRecord => 'Delete';

  @override
  String get qazaEditRecordTitle => 'Edit Qaza';

  @override
  String get qazaEditPrayer => 'Prayer';

  @override
  String get qazaEditDate => 'Original date';

  @override
  String get qazaEditDateHelp => 'Select original Qaza date';

  @override
  String get qazaSaveChanges => 'Save changes';

  @override
  String get qazaDeleteRecordTitle => 'Delete Qaza record?';

  @override
  String qazaDeleteRecordMessage(Object date, Object prayer) {
    return 'Move the $prayer Qaza from $date to Recently Deleted? You can restore it for 30 days.';
  }

  @override
  String get qazaRecordUpdated => 'Qaza record updated.';

  @override
  String qazaDuplicateRecord(Object date, Object prayer) {
    return '$prayer Qaza already exists for $date.';
  }

  @override
  String get qazaRecordUpdateFailed =>
      'Qaza record could not be updated. Please try again.';

  @override
  String get qazaRecordDeleted => 'Qaza moved to Recently Deleted.';

  @override
  String get qazaRecordDeleteFailed =>
      'Qaza record could not be deleted. Please try again.';

  @override
  String get qazaUndoAction => 'Undo';

  @override
  String qazaUndoAvailable(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Recent completions can be undone.',
      one: 'Recent completion can be undone.',
    );
    return '$_temp0';
  }

  @override
  String qazaUndoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Qaza restored.',
      one: '1 Qaza restored.',
    );
    return '$_temp0';
  }

  @override
  String qazaCompletedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Completed $count Qaza.',
      one: 'Completed 1 Qaza.',
      zero: 'Nothing was completed.',
    );
    return '$_temp0';
  }

  @override
  String get calendarSelectYear => 'Select year';

  @override
  String get calendarSelectHint => 'Tap an available date to select it.';

  @override
  String calendarSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dates selected.',
      one: '1 date selected.',
    );
    return '$_temp0';
  }

  @override
  String get authTitle => 'Sign in';

  @override
  String get authWelcomeBack => 'Welcome back';

  @override
  String get authSubtitle => 'Sign in to continue to your Qaza Namaz tracker.';

  @override
  String get authContinueWithGoogle => 'Continue with Google';

  @override
  String get authSigningIn => 'Signing in...';

  @override
  String get authProviderNote =>
      'Google is the currently connected authentication provider. Sign-in status is restored automatically from Firebase.';

  @override
  String get authHelpTooltip => 'Authentication help';

  @override
  String get authHelpTitle => 'Authentication';

  @override
  String get authHelpBody =>
      'Google Sign-In is the connected authentication method in this release. Your Qaza data is scoped to the Firebase account you use to sign in.';

  @override
  String get authDismiss => 'Dismiss';

  @override
  String get authFailed => 'Unable to sign in. Please try again.';

  @override
  String get welcomeTagline => 'Spiritual Devotion & Prayer Accountability';

  @override
  String get welcomeHeadline =>
      'Track your missed prayers with clarity and consistency.';

  @override
  String get welcomeBody =>
      'Record, complete, and keep track of your Qaza Namaz — one prayer at a time.';

  @override
  String get welcomeGetStarted => 'Get Started';

  @override
  String get welcomeSignIn => 'Already have an account? Sign In';

  @override
  String get splashTagline => 'A calm place for prayer accountability';

  @override
  String get accountTitle => 'Account';

  @override
  String get accountSignInMethod => 'Sign-in method';

  @override
  String get accountGoogleAuth => 'Google';

  @override
  String get accountSignedInWithGoogle => 'Signed in with Google';

  @override
  String get accountStatus => 'Account status';

  @override
  String get accountSignedIn => 'Signed in';

  @override
  String get accountRecordsRetained =>
      'Your saved Qaza records remain stored and will be restored after the next sign-in.';

  @override
  String get accountDeveloperContext => 'Developer context';

  @override
  String get accountFirebaseUid => 'Firebase UID';

  @override
  String get accountNotAvailable => 'Not available';

  @override
  String get accountSignOut => 'Sign out';

  @override
  String get accountSignOutPrompt => 'Sign out?';

  @override
  String get accountSignOutExplanation =>
      'Signing out disconnects your Google account. Your Qaza progress remains on this device.';

  @override
  String get dataTitle => 'Export & Import';

  @override
  String get dataExportTitle => 'Export data';

  @override
  String get dataExportBody =>
      'Save a versioned JSON copy of your Qaza ledger. Nothing is uploaded by the export action.';

  @override
  String get dataExportAction => 'Export';

  @override
  String get dataExportDialogTitle => 'Save Qaza data export';

  @override
  String get dataExportSaved => 'Export saved successfully.';

  @override
  String get dataExportCanceled =>
      'Export canceled. Your data was not changed.';

  @override
  String get dataExportSignInRequired =>
      'Sign in before exporting your Qaza data.';

  @override
  String dataExportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String get dataImportTitle => 'Import data';

  @override
  String get dataImportBody =>
      'Open a JSON export, validate it completely, preview the merge, then apply it to this account.';

  @override
  String get dataImportAction => 'Import';

  @override
  String get dataImportReviewTitle => 'Review data import';

  @override
  String get dataImportCanceled =>
      'Import canceled. Your data was not changed.';

  @override
  String get dataImportSignInRequired => 'Sign in before importing data.';

  @override
  String get dataImportEmptyFile => 'The selected file is empty or unreadable.';

  @override
  String dataImportRejected(String error) {
    return 'Import rejected: $error\nNo partial import was applied.';
  }

  @override
  String dataImportComplete(int added, int completed, int unchanged) {
    return 'Import complete: $added added, $completed completed, $unchanged unchanged.';
  }

  @override
  String get dataProcessing => 'Processing data…';

  @override
  String get dataSafetyTitle => 'Data safety';

  @override
  String get dataSafetyBody =>
      'Export does not delete cloud data. Import does not erase existing records. Sign-out is not data deletion, and uninstalling the app does not delete cloud records.';

  @override
  String get dataRemapNote =>
      'Imported records are remapped to the currently signed-in account. The existing local-first sync layer then confirms changes with Firestore in the background.';

  @override
  String get addQazaTitle => 'Add Qaza';

  @override
  String get addQazaStep1 => 'Step 1 of 3 • Select Dates';

  @override
  String get addQazaStep2 => 'Step 2 of 3 • Select Missed Prayers';

  @override
  String get addQazaStep3 => 'Step 3 of 3 • Review & Add';

  @override
  String get addQazaModeSingle => 'Single';

  @override
  String get addQazaModeRange => 'Range';

  @override
  String get addQazaModeMultiple => 'Multiple';

  @override
  String get addQazaModeSingleTitle => 'Single date';

  @override
  String get addQazaModeRangeTitle => 'Date range';

  @override
  String get addQazaModeMultipleTitle => 'Multiple dates';

  @override
  String get addQazaChooseSingle => 'Choose a date';

  @override
  String get addQazaChooseRange => 'Choose a date range';

  @override
  String get addQazaChooseMultiple => 'Choose multiple dates';

  @override
  String get addQazaAvailabilityNote =>
      'A date is disabled only when no prayer remains eligible.';

  @override
  String get addQazaStepNameDates => 'Select Dates';

  @override
  String get addQazaStepNamePrayers => 'Missed Prayers';

  @override
  String get addQazaStepNameReview => 'Review';

  @override
  String addQazaStepSemantics(int step, String name) {
    return 'Step $step: $name';
  }

  @override
  String addQazaPartialAvailability(int available, int total) {
    return 'Available on $available of $total dates';
  }

  @override
  String get addQazaAvailableEveryDate => 'Available on every selected date';

  @override
  String get addQazaEligibleOnlyNote =>
      'Only eligible date + prayer combinations are added. Anything already recorded is skipped.';

  @override
  String addQazaAddCount(String count) {
    return 'Add $count Qaza';
  }

  @override
  String get addQazaNothingNew =>
      'Nothing new to add — these combinations are already recorded.';

  @override
  String get addQazaChecking => 'Checking your ledger...';

  @override
  String get addQazaNextPrayers => 'Next: Review & Add';

  @override
  String get addQazaPrayersHeading => 'Missed Prayers';

  @override
  String get addQazaSelectAll => 'Select All';

  @override
  String get addQazaAllSelected => 'All selected';

  @override
  String get addQazaReviewHeading => 'Review & Add';

  @override
  String get addQazaReviewNote =>
      'Confirm the summary, then add these Qaza records to your ledger.';

  @override
  String get addQazaCombinationNote =>
      'Each date + prayer combination becomes an independent pending record. Existing combinations are skipped automatically.';

  @override
  String get addQazaSelectionLabel => 'Selection';

  @override
  String get addQazaDatesLabel => 'Dates';

  @override
  String get addQazaDateCountLabel => 'Date count';

  @override
  String get addQazaDateRangeLabel => 'Date range';

  @override
  String get addQazaPrayersLabel => 'Prayers';

  @override
  String get addQazaPrayersPerDateLabel => 'Prayers per date';

  @override
  String get addQazaExistingLabel => 'Existing combinations';

  @override
  String get addQazaNewRecordsLabel => 'New records';

  @override
  String get addQazaNewQazaLabel => 'New Qaza records';

  @override
  String get addQazaInProgress => 'Adding Qaza...';

  @override
  String get addQazaCreatedTitle => 'Qaza records created';

  @override
  String addQazaSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days selected • Which prayers did you miss?',
      one: '1 day selected • Which prayers did you miss?',
    );
    return '$_temp0';
  }

  @override
  String addQazaDateCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dates',
      one: '1 date',
    );
    return '$_temp0';
  }

  @override
  String addQazaCreatedMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count records were added to your ledger.',
      one: '1 record was added to your ledger.',
    );
    return '$_temp0';
  }

  @override
  String addQazaUnavailablePrayer(String rakats) {
    return '$rakats • Already recorded/prayed or its prayer time has not ended yet';
  }

  @override
  String get commonNone => 'None';

  @override
  String get completeTitle => 'Complete Qaza';

  @override
  String get completeHeading => 'Complete the latest pending record';

  @override
  String get completeIntro =>
      'Complete one record at a time. After success, the next pending record is shown immediately.';

  @override
  String get completeLoading => 'Loading latest pending record…';

  @override
  String get completeLoadError => 'We could not load your Qaza record.';

  @override
  String get completeNoPendingTitle => 'No pending Qaza for this prayer.';

  @override
  String get completeNoPendingMessage =>
      'Choose another prayer or add a Qaza record first.';

  @override
  String get completeOldestSubtitle => 'Latest pending record';

  @override
  String get completeOriginalDate => 'Original missed date';

  @override
  String get completeTimestampNote =>
      'Completion timestamp is recorded separately.';

  @override
  String get completeAction => 'Complete latest pending';

  @override
  String get completeInProgress => 'Completing...';

  @override
  String get completeFailed => 'Qaza could not be completed. Please try again.';

  @override
  String completePrayerQaza(String prayer) {
    return '$prayer Qaza';
  }

  @override
  String completeSuccess(String prayer) {
    return '$prayer Qaza completed successfully.';
  }

  @override
  String completeSuccessNext(String prayer) {
    return '$prayer Qaza completed • the next one is ready.';
  }

  @override
  String get knowledgeBaseTitle => 'Knowledge Base';

  @override
  String get knowledgeBaseSearchHint => 'Search Masail & Mugalat';

  @override
  String get knowledgeBaseClearSearch => 'Clear search';

  @override
  String get knowledgeCategoryMasail => 'Masail';

  @override
  String get knowledgeCategoryMugalat => 'Mugalat';

  @override
  String get knowledgeBaseTopicAll => 'All topics';

  @override
  String get knowledgeTopicBasic => 'Basics';

  @override
  String get knowledgeTopicPrayerUnits => 'Prayer units';

  @override
  String get knowledgeTopicSleepForgetfulness => 'Sleep & forgetfulness';

  @override
  String get knowledgeTopicIntentionalOmission => 'Intentional omission';

  @override
  String get knowledgeTopicFriday => 'Friday';

  @override
  String get knowledgeTopicMenstruation => 'Menstruation';

  @override
  String get knowledgeTopicNifas => 'Nifas';

  @override
  String get knowledgeTopicMenstruationNifas => 'Menstruation & Nifas';

  @override
  String get knowledgeTopicMisconceptions => 'Misconceptions';

  @override
  String get knowledgeBaseEmptyTitle => 'No articles found';

  @override
  String get knowledgeBaseEmptyMessage => 'Try another search or category.';

  @override
  String get knowledgeBaseLoadError => 'Knowledge Base could not be loaded.';

  @override
  String get knowledgeBaseLanguage => 'Knowledge Base language';

  @override
  String get knowledgeArticleTitle => 'Article';

  @override
  String get knowledgeArticleReferences => 'References';

  @override
  String get knowledgeArticleRelated => 'Related articles';

  @override
  String get knowledgeArticleNotFound => 'Article not found.';

  @override
  String get settingsAccountSection => 'Account';

  @override
  String get settingsAccountSubtitle =>
      'Manage your sign-in and account details.';

  @override
  String get settingsGoogleSignIn => 'Google sign-in';

  @override
  String get settingsKnowledgeBaseSubtitle => 'Browse Masail & Mugalat';

  @override
  String get settingsDataSection => 'Data & Storage';

  @override
  String get settingsDataSubtitle =>
      'Sync, backup, export, and import your Qaza data.';

  @override
  String get settingsDataCloud => 'Data & Cloud';

  @override
  String get settingsDataCloudSubtitle => 'Sync, export and import status';

  @override
  String get settingsResetCounterTitle => 'Reset Qaza Counter';

  @override
  String get settingsResetCounterSubtitle =>
      'Delete every recorded Qaza and start the count again from zero.';

  @override
  String get settingsResetCounterEmpty => 'There are no Qaza records to reset.';

  @override
  String get settingsResetCounterDialogTitle => 'Reset Qaza Counter?';

  @override
  String get settingsResetCounterDialogMessage =>
      'This permanently deletes every Qaza record on this account — pending and completed — from this device and from your cloud backup.\n\nYour counter returns to zero and the completion progress you have built up is lost. This cannot be undone. Export your data first if you may want it back.';

  @override
  String settingsResetCounterAcknowledge(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'I understand that $count Qaza records will be permanently deleted',
      one: 'I understand that 1 Qaza record will be permanently deleted',
    );
    return '$_temp0';
  }

  @override
  String get settingsResetCounterConfirm => 'Reset counter';

  @override
  String get settingsResetCounterDone => 'Qaza counter reset.';

  @override
  String settingsResetCounterFailed(String error) {
    return 'Could not reset the Qaza counter: $error';
  }

  @override
  String get authContinueAsGuest => 'Continue as Guest';

  @override
  String get authGuestNote =>
      'You can sign in with Google later to keep your progress with your account.';

  @override
  String get backupPromptTitle => 'Keep your progress safe';

  @override
  String get backupPromptBody =>
      'Sign in with Google to keep your Qaza progress available with your account.';

  @override
  String get backupPromptConfirm => 'Continue with Google';

  @override
  String get backupPromptDismiss => 'Not Now';

  @override
  String get settingsBackupSignIn => 'Back up / Sign in';

  @override
  String get settingsBackupSignInSubtitle =>
      'You are using the app as a guest. Sign in to back up your Qaza.';

  @override
  String get backupSignInFailed =>
      'Sign-in failed. Your progress is still on this device.';

  @override
  String get backupSignInCancelled =>
      'Sign-in canceled. Your progress is still on this device.';

  @override
  String backupSignInFailedReason(String reason) {
    return 'Sign-in failed: $reason Your progress is still on this device.';
  }

  @override
  String backupMigrationDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Signed in. Your Qaza progress is now linked to your account.',
      one: 'Signed in. Your Qaza progress is now linked to your account.',
      zero: 'Signed in. Your Qaza progress is now linked to your account.',
    );
    return '$_temp0';
  }

  @override
  String get settingsAboutSection => 'About';

  @override
  String get settingsAboutSubtitle => 'App information and version details.';

  @override
  String settingsAboutRowSubtitle(String version) {
    return 'Qaza Namaz • version $version';
  }

  @override
  String get settingsAppDescription => 'Islamic Prayer Qaza Tracker';

  @override
  String get cloudSyncTitle => 'Cloud Sync';

  @override
  String get cloudSyncNow => 'Sync now';

  @override
  String get cloudPendingChanges => 'Pending changes';

  @override
  String get cloudLastSynced => 'Last synced';

  @override
  String get cloudExportImportSubtitle =>
      'User-controlled JSON backup and safe restore. No cloud data is deleted by these actions.';

  @override
  String get cloudInactive => 'Offline storage is not active in this build.';

  @override
  String get cloudBootstrapping =>
      'Setting up your Qaza records on this device…';

  @override
  String get cloudHydrating =>
      'Restoring your saved Qaza records to this device…';

  @override
  String get cloudSynced => 'All your Qaza records are saved in the cloud.';

  @override
  String get cloudSyncing => 'Syncing your ledger…';

  @override
  String get cloudOffline =>
      'Offline — records are saved on this device and sync automatically.';

  @override
  String cloudPendingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count changes waiting to sync.',
      one: '1 change waiting to sync.',
    );
    return '$_temp0';
  }

  @override
  String get cloudSyncProblem =>
      'Sync problem — your data is safe on this device.';

  @override
  String get cloudQazaCount => 'Qaza count';

  @override
  String cloudQazaCountValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Qaza records',
      one: '1 Qaza record',
      zero: 'No Qaza records',
    );
    return '$_temp0';
  }

  @override
  String get cloudBackupStatus => 'Cloud backup';

  @override
  String get cloudBackupDeleted => 'Cloud copy deleted; local records remain.';

  @override
  String get cloudLocalVsCloudTitle => 'Local vs cloud';

  @override
  String get cloudLocalVsCloudBody =>
      'Your Qaza records are stored locally for offline use. When you are signed in, changes can be synchronized to your private cloud account. Export is a local backup; deleting cloud data does not delete your local records.';

  @override
  String get cloudDeleteTitle => 'Delete cloud data';

  @override
  String get cloudDeleteBody =>
      'This permanently deletes your Qaza records from your cloud account. Your local records on this device will remain. This cannot be undone. Export your data first if you may need a backup.';

  @override
  String get cloudDeleteAcknowledge =>
      'I understand the cloud copy will be permanently deleted.';

  @override
  String get cloudDeleteAction => 'Delete cloud data';

  @override
  String get cloudDeleteDone =>
      'Cloud Qaza data was deleted. Your local records remain on this device.';

  @override
  String get cloudDeleteFailed =>
      'Cloud data could not be deleted. Your local records are still safe.';

  @override
  String get cloudDeleteSignInRequired => 'Sign in to manage cloud data.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsPreferences => 'Preferences';

  @override
  String get settingsPreferencesSubtitle => 'Language and appearance settings.';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsAppearanceSubtitle =>
      'Choose how the app looks on this device.';

  @override
  String get settingsThemeSystem => 'System';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageSubtitle =>
      'Select the language used throughout the app.';

  @override
  String get settingsLanguageNote =>
      'Prayer names and Hijri dates follow the selected language. Urdu is written right to left.';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageUrdu => 'اردو';

  @override
  String get settingsPrivacySecurity => 'Privacy & Security';

  @override
  String get settingsPrivacySecuritySubtitle =>
      'Protect access to your Qaza records on this device.';

  @override
  String get settingsAppLock => 'App Lock';

  @override
  String get settingsAppLockSubtitle =>
      'Require device authentication before showing your Qaza records.';

  @override
  String get settingsAppLockWhen => 'Lock when you leave the app';

  @override
  String get settingsAppLockImmediate => 'Immediately';

  @override
  String get settingsAppLockOneMinute => 'After 1 minute';

  @override
  String get settingsAppLockFiveMinutes => 'After 5 minutes';

  @override
  String get settingsAppLockNever => 'Never';

  @override
  String get settingsAppLockDeviceNote =>
      'App Lock uses your device security, such as fingerprint, face unlock, PIN, pattern, or password. Your device must have a supported screen lock configured.';

  @override
  String get appLockEnableReason =>
      'Authenticate to turn on App Lock for Qaza Namaz.';

  @override
  String get appLockDisableReason => 'Authenticate to turn off App Lock.';

  @override
  String get appLockAuthenticationReason =>
      'Authenticate to open your Qaza records.';

  @override
  String get appLockLockedTitle => 'Qaza Namaz is locked';

  @override
  String get appLockLockedBody =>
      'Authenticate with your device security to continue. Your Qaza data is hidden until you unlock the app.';

  @override
  String get appLockUnlock => 'Unlock';

  @override
  String get appLockUnlocking => 'Unlocking...';

  @override
  String get appLockUnavailable =>
      'Device authentication is not available. Set up a screen lock or supported biometric and try again.';

  @override
  String get appLockCanceled =>
      'Unlock canceled. Your Qaza data is still protected.';

  @override
  String get appLockTemporarilyLocked =>
      'Device authentication is temporarily locked. Wait a moment and try again.';

  @override
  String get appLockFailed => 'Device authentication failed. Please try again.';

  @override
  String get homeTodayProgressHeader => 'Today\'s Progress';

  @override
  String get homeNextQazaCurrentPrayer => 'Next Qaza (Current Prayer)';

  @override
  String get homeOldestPending => 'Oldest Pending';

  @override
  String get homeOverallQaza => 'Overall Qaza';

  @override
  String get homePendingByPrayer => 'Pending by Prayer';

  @override
  String get homePrayerBreakdown => 'Prayer Breakdown';

  @override
  String get homeViewDetails => 'View details';

  @override
  String get homeViewAll => 'View all';

  @override
  String get homeCompleted => 'Completed';

  @override
  String get homePending => 'Pending';

  @override
  String get homeYourProgress => 'Your Progress';

  @override
  String get homeRange7Days => '7 Days';

  @override
  String get homeRange30Days => '30 Days';

  @override
  String get homeRangeMonthly => 'Monthly';

  @override
  String get homeDetailedStatistics => 'View Detailed Statistics';

  @override
  String get homeDetailedStatisticsSubtitle =>
      'Overall and prayer-wise completion';

  @override
  String get homeChartNoData => 'No completed Qaza in this period.';

  @override
  String get homeTodayDate => 'Today';

  @override
  String homeCurrentPrayerLabel(String prayer) {
    return 'Current prayer: $prayer';
  }

  @override
  String homeSahibOrderLabel(String prayer) {
    return 'Sahib al-Tartib: $prayer';
  }

  @override
  String get profileLanguageTitle => 'Choose your language';

  @override
  String get profileLanguageIntro =>
      'Select the language you want to use throughout the app.';

  @override
  String get profileSetupTitle => 'Set up your profile';

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileIntro =>
      'These details personalize your Qaza plan and are used by the app\'s prayer rules.';

  @override
  String get profileSettingsSubtitle =>
      'Your prayer profile and Qaza plan settings.';

  @override
  String get profileGender => 'Gender';

  @override
  String get profileMale => 'Male';

  @override
  String get profileFemale => 'Female';

  @override
  String get profileMadhab => 'Madhab / School of Thought';

  @override
  String get profileHanafi => 'Hanafi';

  @override
  String get profileShafi => 'Shafi';

  @override
  String get profileMaliki => 'Maliki';

  @override
  String get profileHanbali => 'Hanbali';

  @override
  String get profileOther => 'Other';

  @override
  String get profileDateOfBirth => 'Date of Birth';

  @override
  String get profileSelectDate => 'Select date';

  @override
  String get profileSelectDobHelp => 'Select your date of birth';

  @override
  String get profileHijriHint =>
      'Hijri date is shown after you select the Gregorian date.';

  @override
  String get profilePubertyAge => 'Puberty Age';

  @override
  String get profileStartPrayingAge => 'Start Praying Age';

  @override
  String get profileSelectGenderFirst => 'Select gender first';

  @override
  String get profileSelectPubertyFirst => 'Select puberty age first';

  @override
  String get profileSelectDobFirst => 'Select date of birth first';

  @override
  String get profileWitr => 'Witr';

  @override
  String get profileWitrOptional =>
      'For Other, you can choose whether Witr is included.';

  @override
  String get profileWitrIncluded => 'Included';

  @override
  String get profileWitrExcluded => 'Not included';

  @override
  String get profileSubmit => 'Continue';

  @override
  String get profileSave => 'Save Changes';

  @override
  String get qazaReviewTitle => 'Review Your Qaza Plan';

  @override
  String get qazaReviewSubtitle =>
      'Please review your Qaza details before adding them to your tracker.';

  @override
  String get qazaReviewTotal => 'Total Estimated Qaza';

  @override
  String get qazaReviewPeriod => 'Qaza Period';

  @override
  String get qazaReviewBreakdown => 'Prayer Breakdown';

  @override
  String get qazaReviewNote =>
      'These are estimated Qaza prayers based on the information in your profile.';

  @override
  String get qazaReviewEdit => 'Edit My Details';

  @override
  String get qazaReviewAdd => 'Add Qaza to My Tracker';

  @override
  String get qazaReviewAdding => 'Adding Qaza…';

  @override
  String get qazaReviewError => 'Qaza could not be added. Please try again.';

  @override
  String get profileErrorLanguage => 'Please select a language.';

  @override
  String get profileErrorGender => 'Please select your gender.';

  @override
  String get profileErrorMadhab => 'Please select your school of thought.';

  @override
  String get profileErrorDob => 'Please enter a valid date of birth.';

  @override
  String get profileErrorPuberty =>
      'Please select a valid puberty age for the selected gender.';

  @override
  String get profileErrorStartPraying =>
      'Please select a valid praying start age.';

  @override
  String get profileErrorWitr => 'Please select a valid Witr setting.';
}
