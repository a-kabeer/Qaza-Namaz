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
  String get qazaSortOldestFirst => 'Oldest first';

  @override
  String get qazaSortNewestFirst => 'Newest first';

  @override
  String get filterAll => 'All';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonVersion => 'Version';

  @override
  String get stateErrorTitle => 'Something went wrong';

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
  String get homeSetupMessage => 'You haven\'t added any Qaza prayers yet.';

  @override
  String get homeCompleteQaza => 'Complete Qaza';

  @override
  String get homeStatTotal => 'Total';

  @override
  String get homeProgressError =>
      'Unable to load your Qaza progress. Pull to retry.';

  @override
  String get homeQazaPlan => 'Qaza plan';

  @override
  String get homeAuto => 'Auto';

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
  String get homeDailyProgressError => 'Today\'s progress could not be loaded.';

  @override
  String progressCompletedPending(String completed, String pending) {
    return '$completed completed • $pending pending';
  }

  @override
  String get qazaTitle => 'Qaza';

  @override
  String get qazaProgressLabel => 'Progress';

  @override
  String get qazaDateFilterAny => 'Original date: any';

  @override
  String get qazaDateFilterHelp => 'Filter by original Qaza date';

  @override
  String qazaDateFilterRange(String from, String to) {
    return '$from — $to';
  }

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
  String get splashTagline => 'A calm place for prayer accountability';

  @override
  String get addQazaNothingNew =>
      'Nothing new to add — these combinations are already recorded.';

  @override
  String get addQazaExistingLabel => 'Existing combinations';

  @override
  String get addQazaNewRecordsLabel => 'New records';

  @override
  String get addQazaInProgress => 'Adding Qaza...';

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
  String get completeLoadError => 'We could not load your Qaza record.';

  @override
  String get completeNoPendingTitle => 'No pending Qaza for this prayer.';

  @override
  String get completeNoPendingMessage =>
      'Choose another prayer or add a Qaza record first.';

  @override
  String get completeInProgress => 'Completing...';

  @override
  String get completeFailed => 'Qaza could not be completed. Please try again.';

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
  String get settingsAboutSection => 'About';

  @override
  String settingsAboutRowSubtitle(String version) {
    return 'Qaza Namaz • version $version';
  }

  @override
  String get settingsAppDescription => 'Islamic Prayer Qaza Tracker';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageSubtitle =>
      'Select the language used throughout the app.';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageUrdu => 'اردو';

  @override
  String get homeTodayProgressHeader => 'Today\'s Progress';

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
  String get homeDetailedStatistics => 'View Detailed Statistics';

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
