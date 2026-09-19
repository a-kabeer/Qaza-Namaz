import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ur.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ur')
  ];

  /// Application name shown in the OS task switcher
  ///
  /// In en, this message translates to:
  /// **'Qaza Namaz'**
  String get appTitle;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navQaza.
  ///
  /// In en, this message translates to:
  /// **'Qaza'**
  String get navQaza;

  /// No description provided for @navCalculator.
  ///
  /// In en, this message translates to:
  /// **'Calculator'**
  String get navCalculator;

  /// No description provided for @navKnowledge.
  ///
  /// In en, this message translates to:
  /// **'Knowledge'**
  String get navKnowledge;

  /// No description provided for @settingsRemindersSection.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get settingsRemindersSection;

  /// No description provided for @settingsRemindersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Daily reminder to complete your Qaza.'**
  String get settingsRemindersSubtitle;

  /// No description provided for @settingsBackupSection.
  ///
  /// In en, this message translates to:
  /// **'Backup & Data'**
  String get settingsBackupSection;

  /// No description provided for @settingsBackupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Cloud sync, export and import.'**
  String get settingsBackupSubtitle;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @prayerFajr.
  ///
  /// In en, this message translates to:
  /// **'Fajr'**
  String get prayerFajr;

  /// No description provided for @prayerZuhr.
  ///
  /// In en, this message translates to:
  /// **'Zuhr'**
  String get prayerZuhr;

  /// No description provided for @prayerAsr.
  ///
  /// In en, this message translates to:
  /// **'Asr'**
  String get prayerAsr;

  /// No description provided for @prayerMaghrib.
  ///
  /// In en, this message translates to:
  /// **'Maghrib'**
  String get prayerMaghrib;

  /// No description provided for @prayerIsha.
  ///
  /// In en, this message translates to:
  /// **'Isha'**
  String get prayerIsha;

  /// No description provided for @prayerWitr.
  ///
  /// In en, this message translates to:
  /// **'Witr'**
  String get prayerWitr;

  /// No description provided for @statusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get statusPending;

  /// No description provided for @statusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get statusCompleted;

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get commonTotal;

  /// No description provided for @commonVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get commonVersion;

  /// No description provided for @stateErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get stateErrorTitle;

  /// No description provided for @prayerRakatFajr.
  ///
  /// In en, this message translates to:
  /// **'Fajr • 2 Rakat Fard'**
  String get prayerRakatFajr;

  /// No description provided for @prayerRakatZuhr.
  ///
  /// In en, this message translates to:
  /// **'Zuhr • 4 Rakat Fard'**
  String get prayerRakatZuhr;

  /// No description provided for @prayerRakatAsr.
  ///
  /// In en, this message translates to:
  /// **'Asr • 4 Rakat Fard'**
  String get prayerRakatAsr;

  /// No description provided for @prayerRakatMaghrib.
  ///
  /// In en, this message translates to:
  /// **'Maghrib • 3 Rakat Fard'**
  String get prayerRakatMaghrib;

  /// No description provided for @prayerRakatIsha.
  ///
  /// In en, this message translates to:
  /// **'Isha • 4 Rakat Fard'**
  String get prayerRakatIsha;

  /// No description provided for @prayerRakatWitr.
  ///
  /// In en, this message translates to:
  /// **'Witr • 3 Rakat Wajib • Independent'**
  String get prayerRakatWitr;

  /// No description provided for @syncSettingUp.
  ///
  /// In en, this message translates to:
  /// **'Setting up'**
  String get syncSettingUp;

  /// No description provided for @syncSettingUpDetail.
  ///
  /// In en, this message translates to:
  /// **'Preparing your Qaza records on this device.'**
  String get syncSettingUpDetail;

  /// No description provided for @syncRestoring.
  ///
  /// In en, this message translates to:
  /// **'Restoring'**
  String get syncRestoring;

  /// No description provided for @syncRestoringDetail.
  ///
  /// In en, this message translates to:
  /// **'Bringing your saved Qaza records to this device.'**
  String get syncRestoringDetail;

  /// No description provided for @syncSynced.
  ///
  /// In en, this message translates to:
  /// **'Synced'**
  String get syncSynced;

  /// No description provided for @syncSyncedAt.
  ///
  /// In en, this message translates to:
  /// **'Synced • {timestamp}'**
  String syncSyncedAt(String timestamp);

  /// No description provided for @syncSyncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing'**
  String get syncSyncing;

  /// No description provided for @syncSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get syncSaved;

  /// No description provided for @syncSavedDetail.
  ///
  /// In en, this message translates to:
  /// **'Your changes are saved on this device and will sync automatically.'**
  String get syncSavedDetail;

  /// No description provided for @syncErrorLabel.
  ///
  /// In en, this message translates to:
  /// **'Sync Error'**
  String get syncErrorLabel;

  /// No description provided for @syncErrorDetail.
  ///
  /// In en, this message translates to:
  /// **'Your changes are saved on this device. We will retry automatically.'**
  String get syncErrorDetail;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get commonDone;

  /// No description provided for @commonReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get commonReset;

  /// No description provided for @commonClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get commonClear;

  /// No description provided for @commonBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonBack;

  /// No description provided for @commonContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get commonContinue;

  /// No description provided for @commonLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get commonLoading;

  /// Secondary Hijri date line; Gregorian remains primary
  ///
  /// In en, this message translates to:
  /// **'{day} {month} {year} AH'**
  String hijriDate(Object day, Object month, Object year);

  /// No description provided for @homeTitle.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get homeTitle;

  /// No description provided for @homeNotificationsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get homeNotificationsTooltip;

  /// No description provided for @homeProfileTooltip.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get homeProfileTooltip;

  /// No description provided for @homeHeadingSetup.
  ///
  /// In en, this message translates to:
  /// **'Start Your Qaza Journey'**
  String get homeHeadingSetup;

  /// No description provided for @homeHeadingPending.
  ///
  /// In en, this message translates to:
  /// **'Keep going'**
  String get homeHeadingPending;

  /// No description provided for @homeHeadingCompleted.
  ///
  /// In en, this message translates to:
  /// **'You are all caught up'**
  String get homeHeadingCompleted;

  /// No description provided for @homeSetupMessage.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t added any Qaza prayers yet.'**
  String get homeSetupMessage;

  /// No description provided for @homeCalculateQaza.
  ///
  /// In en, this message translates to:
  /// **'Calculate Qaza'**
  String get homeCalculateQaza;

  /// No description provided for @homeCompleteQaza.
  ///
  /// In en, this message translates to:
  /// **'Complete Qaza'**
  String get homeCompleteQaza;

  /// No description provided for @homeAddNewQaza.
  ///
  /// In en, this message translates to:
  /// **'Add New Qaza'**
  String get homeAddNewQaza;

  /// No description provided for @homeAddManually.
  ///
  /// In en, this message translates to:
  /// **'Add Qaza Manually'**
  String get homeAddManually;

  /// No description provided for @homeStatTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get homeStatTotal;

  /// No description provided for @homeAddQaza.
  ///
  /// In en, this message translates to:
  /// **'Add Qaza'**
  String get homeAddQaza;

  /// No description provided for @homeCompletedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} completed'**
  String homeCompletedCount(int count);

  /// No description provided for @homeProgressTitle.
  ///
  /// In en, this message translates to:
  /// **'Your progress'**
  String get homeProgressTitle;

  /// No description provided for @homeProgressError.
  ///
  /// In en, this message translates to:
  /// **'Unable to load your Qaza progress. Pull to retry.'**
  String get homeProgressError;

  /// No description provided for @progressPendingCompleted.
  ///
  /// In en, this message translates to:
  /// **'{pending} pending • {completed} completed'**
  String progressPendingCompleted(String pending, String completed);

  /// No description provided for @progressCompletedPending.
  ///
  /// In en, this message translates to:
  /// **'{completed} completed • {pending} pending'**
  String progressCompletedPending(String completed, String pending);

  /// No description provided for @qazaTitle.
  ///
  /// In en, this message translates to:
  /// **'Qaza'**
  String get qazaTitle;

  /// No description provided for @qazaProgressLabel.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get qazaProgressLabel;

  /// No description provided for @qazaAddTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add Qaza'**
  String get qazaAddTooltip;

  /// No description provided for @qazaDateFilterAny.
  ///
  /// In en, this message translates to:
  /// **'Original date: any'**
  String get qazaDateFilterAny;

  /// No description provided for @qazaDateFilterHelp.
  ///
  /// In en, this message translates to:
  /// **'Filter by original Qaza date'**
  String get qazaDateFilterHelp;

  /// No description provided for @qazaDateFilterRange.
  ///
  /// In en, this message translates to:
  /// **'{from} — {to}'**
  String qazaDateFilterRange(String from, String to);

  /// No description provided for @qazaLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading your Qaza records...'**
  String get qazaLoading;

  /// No description provided for @qazaEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No Qaza records yet'**
  String get qazaEmptyTitle;

  /// No description provided for @qazaEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Add missed prayers or calculate an estimate to begin.'**
  String get qazaEmptyMessage;

  /// No description provided for @qazaFilteredEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No records match these filters'**
  String get qazaFilteredEmptyTitle;

  /// No description provided for @qazaFilteredEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Try a different status, prayer or date range.'**
  String get qazaFilteredEmptyMessage;

  /// No description provided for @qazaResetFilters.
  ///
  /// In en, this message translates to:
  /// **'Reset filters'**
  String get qazaResetFilters;

  /// No description provided for @qazaLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load your Qaza records: {error}'**
  String qazaLoadError(String error);

  /// No description provided for @qazaLoadMoreError.
  ///
  /// In en, this message translates to:
  /// **'Could not load more records: {error}'**
  String qazaLoadMoreError(String error);

  /// No description provided for @qazaCompleteError.
  ///
  /// In en, this message translates to:
  /// **'Could not complete the selected Qaza: {error}'**
  String qazaCompleteError(String error);

  /// No description provided for @qazaCompletedOn.
  ///
  /// In en, this message translates to:
  /// **'Completed {date}'**
  String qazaCompletedOn(String date);

  /// Bulk completion action label
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Complete 1 Qaza} other{Complete {count} Qaza}}'**
  String qazaCompleteCount(int count);

  /// Confirmation after bulk completion
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Nothing was completed.} =1{Completed 1 Qaza.} other{Completed {count} Qaza.}}'**
  String qazaCompletedCount(int count);

  /// No description provided for @calcAboutYouIntro.
  ///
  /// In en, this message translates to:
  /// **'Start with your date of birth and Baligh information. Dates are selected in the Gregorian calendar; the Hijri date is shown alongside.'**
  String get calcAboutYouIntro;

  /// No description provided for @calcDateOfBirth.
  ///
  /// In en, this message translates to:
  /// **'Date of birth'**
  String get calcDateOfBirth;

  /// No description provided for @calcSelectDate.
  ///
  /// In en, this message translates to:
  /// **'Select date'**
  String get calcSelectDate;

  /// No description provided for @calcSelectDobHelp.
  ///
  /// In en, this message translates to:
  /// **'Select your date of birth'**
  String get calcSelectDobHelp;

  /// No description provided for @calcCurrentAge.
  ///
  /// In en, this message translates to:
  /// **'Current age'**
  String get calcCurrentAge;

  /// No description provided for @calcAgeYears.
  ///
  /// In en, this message translates to:
  /// **'{years} years'**
  String calcAgeYears(int years);

  /// No description provided for @calcBalighInformation.
  ///
  /// In en, this message translates to:
  /// **'Baligh information'**
  String get calcBalighInformation;

  /// No description provided for @calcModeAge.
  ///
  /// In en, this message translates to:
  /// **'Age'**
  String get calcModeAge;

  /// No description provided for @calcModeExactDate.
  ///
  /// In en, this message translates to:
  /// **'Exact date'**
  String get calcModeExactDate;

  /// No description provided for @calcBalighAgeLabel.
  ///
  /// In en, this message translates to:
  /// **'Baligh age (years)'**
  String get calcBalighAgeLabel;

  /// No description provided for @calcSelectExactDate.
  ///
  /// In en, this message translates to:
  /// **'Select exact date'**
  String get calcSelectExactDate;

  /// No description provided for @calcSelectBalighHelp.
  ///
  /// In en, this message translates to:
  /// **'Select exact Baligh date'**
  String get calcSelectBalighHelp;

  /// No description provided for @calcEstimatedBalighDate.
  ///
  /// In en, this message translates to:
  /// **'Estimated Baligh date: {date}'**
  String calcEstimatedBalighDate(String date);

  /// No description provided for @calcExactBalighDate.
  ///
  /// In en, this message translates to:
  /// **'Exact Baligh date: {date}'**
  String calcExactBalighDate(String date);

  /// No description provided for @calcPrayerHistoryIntro.
  ///
  /// In en, this message translates to:
  /// **'Tell us when regular prayer started so we can calculate the Qaza period.'**
  String get calcPrayerHistoryIntro;

  /// No description provided for @calcRegularPrayerStart.
  ///
  /// In en, this message translates to:
  /// **'Regular prayer start'**
  String get calcRegularPrayerStart;

  /// No description provided for @calcPrayerStartAgeUnavailable.
  ///
  /// In en, this message translates to:
  /// **'You are younger than the Baligh age you selected, so there is no prayer-start age to choose. Adjust your date of birth or Baligh information.'**
  String get calcPrayerStartAgeUnavailable;

  /// No description provided for @calcPrayerStartAgeLabel.
  ///
  /// In en, this message translates to:
  /// **'Regular prayer start age (years)'**
  String get calcPrayerStartAgeLabel;

  /// No description provided for @calcSelectPrayerStartHelp.
  ///
  /// In en, this message translates to:
  /// **'Select exact prayer start date'**
  String get calcSelectPrayerStartHelp;

  /// No description provided for @calcEstimatedPrayerStartDate.
  ///
  /// In en, this message translates to:
  /// **'Estimated prayer-start date: {date}'**
  String calcEstimatedPrayerStartDate(String date);

  /// No description provided for @calcExactPrayerStartDate.
  ///
  /// In en, this message translates to:
  /// **'Exact prayer-start date: {date}'**
  String calcExactPrayerStartDate(String date);

  /// No description provided for @calcIncludeWitr.
  ///
  /// In en, this message translates to:
  /// **'Include Witr separately'**
  String get calcIncludeWitr;

  /// No description provided for @calcIncludeWitrSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Witr is counted independently from the five daily prayers.'**
  String get calcIncludeWitrSubtitle;

  /// No description provided for @calcQazaPeriod.
  ///
  /// In en, this message translates to:
  /// **'Qaza period'**
  String get calcQazaPeriod;

  /// No description provided for @calcBalighDate.
  ///
  /// In en, this message translates to:
  /// **'Baligh date'**
  String get calcBalighDate;

  /// No description provided for @calcPrayerStartDate.
  ///
  /// In en, this message translates to:
  /// **'Prayer-start date'**
  String get calcPrayerStartDate;

  /// No description provided for @calcCalendarPeriod.
  ///
  /// In en, this message translates to:
  /// **'Calendar period'**
  String get calcCalendarPeriod;

  /// No description provided for @calcPeriodValue.
  ///
  /// In en, this message translates to:
  /// **'{years} years • {days} days'**
  String calcPeriodValue(int years, int days);

  /// No description provided for @calcCompleteDatesPrompt.
  ///
  /// In en, this message translates to:
  /// **'Complete valid dates to calculate the Qaza period.'**
  String get calcCompleteDatesPrompt;

  /// No description provided for @calcNoResultPrompt.
  ///
  /// In en, this message translates to:
  /// **'Calculate a valid prayer period to view your Qaza estimate.'**
  String get calcNoResultPrompt;

  /// No description provided for @calcElapsedDays.
  ///
  /// In en, this message translates to:
  /// **'Elapsed days'**
  String get calcElapsedDays;

  /// No description provided for @calcEstimatedPrayers.
  ///
  /// In en, this message translates to:
  /// **'Estimated prayers'**
  String get calcEstimatedPrayers;

  /// No description provided for @calcPrayerBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Prayer breakdown'**
  String get calcPrayerBreakdown;

  /// No description provided for @calcWitrNotIncluded.
  ///
  /// In en, this message translates to:
  /// **'Witr is not included. Change this on Prayer History.'**
  String get calcWitrNotIncluded;

  /// No description provided for @calcPreflightErrorShort.
  ///
  /// In en, this message translates to:
  /// **'Could not check existing records.'**
  String get calcPreflightErrorShort;

  /// No description provided for @calcAddErrorShort.
  ///
  /// In en, this message translates to:
  /// **'Could not add the estimate.'**
  String get calcAddErrorShort;

  /// No description provided for @calculatorTitle.
  ///
  /// In en, this message translates to:
  /// **'Calculator'**
  String get calculatorTitle;

  /// No description provided for @calcStepAboutYou.
  ///
  /// In en, this message translates to:
  /// **'About You'**
  String get calcStepAboutYou;

  /// No description provided for @calcStepPrayerHistory.
  ///
  /// In en, this message translates to:
  /// **'Prayer History'**
  String get calcStepPrayerHistory;

  /// No description provided for @calcStepResult.
  ///
  /// In en, this message translates to:
  /// **'Result'**
  String get calcStepResult;

  /// No description provided for @calcStepOf.
  ///
  /// In en, this message translates to:
  /// **'Step {step} of 3'**
  String calcStepOf(int step);

  /// Screen-reader label for the step indicator
  ///
  /// In en, this message translates to:
  /// **'Step {step}: {name}'**
  String calcStepSemantics(int step, String name);

  /// No description provided for @calcCalculate.
  ///
  /// In en, this message translates to:
  /// **'Calculate'**
  String get calcCalculate;

  /// No description provided for @calcAddToTracker.
  ///
  /// In en, this message translates to:
  /// **'Add to Tracker'**
  String get calcAddToTracker;

  /// No description provided for @calcAddQazaCount.
  ///
  /// In en, this message translates to:
  /// **'Add {count} Qaza'**
  String calcAddQazaCount(String count);

  /// No description provided for @calcPreflightTitle.
  ///
  /// In en, this message translates to:
  /// **'Add to Qaza Tracker'**
  String get calcPreflightTitle;

  /// No description provided for @calcCalculated.
  ///
  /// In en, this message translates to:
  /// **'Calculated'**
  String get calcCalculated;

  /// No description provided for @calcAlreadyRecorded.
  ///
  /// In en, this message translates to:
  /// **'Already Recorded'**
  String get calcAlreadyRecorded;

  /// No description provided for @calcAlreadyCompleted.
  ///
  /// In en, this message translates to:
  /// **'Already Completed'**
  String get calcAlreadyCompleted;

  /// No description provided for @calcNewToAdd.
  ///
  /// In en, this message translates to:
  /// **'New to Add'**
  String get calcNewToAdd;

  /// No description provided for @calcExistingUntouched.
  ///
  /// In en, this message translates to:
  /// **'Existing records are never changed.'**
  String get calcExistingUntouched;

  /// No description provided for @calcAddCountToTracker.
  ///
  /// In en, this message translates to:
  /// **'Add {count} to Qaza Tracker'**
  String calcAddCountToTracker(String count);

  /// No description provided for @calcAddingTitle.
  ///
  /// In en, this message translates to:
  /// **'Adding Qaza to your tracker'**
  String get calcAddingTitle;

  /// No description provided for @calcAddingProgress.
  ///
  /// In en, this message translates to:
  /// **'{processed} of {total} records'**
  String calcAddingProgress(String processed, String total);

  /// No description provided for @calcAddedResult.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Nothing new to add — your tracker already had these.} =1{1 record added to your tracker.} other{{count} records added to your tracker.}}'**
  String calcAddedResult(int count);

  /// No description provided for @calcAddFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not add to your tracker'**
  String get calcAddFailedTitle;

  /// No description provided for @calcAddedDoneHint.
  ///
  /// In en, this message translates to:
  /// **'Your tracker is up to date. Your date of birth and prayer settings are saved for next time.'**
  String get calcAddedDoneHint;

  /// No description provided for @calcCalculateAgain.
  ///
  /// In en, this message translates to:
  /// **'Calculate Again'**
  String get calcCalculateAgain;

  /// No description provided for @calcEstimateAdded.
  ///
  /// In en, this message translates to:
  /// **'Estimate added'**
  String get calcEstimateAdded;

  /// No description provided for @calcEstimateAddedMessage.
  ///
  /// In en, this message translates to:
  /// **'{count} Qaza records were added. Existing records were not overwritten.'**
  String calcEstimateAddedMessage(String count);

  /// No description provided for @calcPreflightError.
  ///
  /// In en, this message translates to:
  /// **'Could not check your existing records: {error}'**
  String calcPreflightError(String error);

  /// No description provided for @calcAddError.
  ///
  /// In en, this message translates to:
  /// **'Could not add the estimate: {error}'**
  String calcAddError(String error);

  /// No description provided for @calendarSelectYear.
  ///
  /// In en, this message translates to:
  /// **'Select year'**
  String get calendarSelectYear;

  /// No description provided for @calendarSelectHint.
  ///
  /// In en, this message translates to:
  /// **'Tap an available date to select it.'**
  String get calendarSelectHint;

  /// No description provided for @calendarSelectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 date selected.} other{{count} dates selected.}}'**
  String calendarSelectedCount(int count);

  /// No description provided for @authTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get authTitle;

  /// No description provided for @authWelcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get authWelcomeBack;

  /// No description provided for @authSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue to your Qaza Namaz tracker.'**
  String get authSubtitle;

  /// No description provided for @authContinueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get authContinueWithGoogle;

  /// No description provided for @authSigningIn.
  ///
  /// In en, this message translates to:
  /// **'Signing in...'**
  String get authSigningIn;

  /// No description provided for @authProviderNote.
  ///
  /// In en, this message translates to:
  /// **'Google is the currently connected authentication provider. Sign-in status is restored automatically from Firebase.'**
  String get authProviderNote;

  /// No description provided for @authHelpTooltip.
  ///
  /// In en, this message translates to:
  /// **'Authentication help'**
  String get authHelpTooltip;

  /// No description provided for @authHelpTitle.
  ///
  /// In en, this message translates to:
  /// **'Authentication'**
  String get authHelpTitle;

  /// No description provided for @authHelpBody.
  ///
  /// In en, this message translates to:
  /// **'Google Sign-In is the connected authentication method in this release. Your Qaza data is scoped to the Firebase account you use to sign in.'**
  String get authHelpBody;

  /// No description provided for @authDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get authDismiss;

  /// No description provided for @authFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to sign in. Please try again.'**
  String get authFailed;

  /// No description provided for @notificationsOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get notificationsOff;

  /// No description provided for @notificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsTitle;

  /// No description provided for @notificationsLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading notification settings…'**
  String get notificationsLoading;

  /// No description provided for @notificationsLoadError.
  ///
  /// In en, this message translates to:
  /// **'Notification settings could not be loaded: {error}'**
  String notificationsLoadError(String error);

  /// No description provided for @notificationsOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open notification settings'**
  String get notificationsOpenSettings;

  /// No description provided for @notificationsTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get notificationsTryAgain;

  /// No description provided for @notificationsDailyTitle.
  ///
  /// In en, this message translates to:
  /// **'Daily Qaza reminder'**
  String get notificationsDailyTitle;

  /// No description provided for @notificationsDailySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Get one gentle reminder to continue pending Qaza prayers.'**
  String get notificationsDailySubtitle;

  /// No description provided for @notificationsDailyToggle.
  ///
  /// In en, this message translates to:
  /// **'Daily reminder'**
  String get notificationsDailyToggle;

  /// No description provided for @notificationsReminderTime.
  ///
  /// In en, this message translates to:
  /// **'Reminder time'**
  String get notificationsReminderTime;

  /// No description provided for @notificationsChooseTime.
  ///
  /// In en, this message translates to:
  /// **'Choose daily reminder time'**
  String get notificationsChooseTime;

  /// No description provided for @notificationsEnableToChangeTime.
  ///
  /// In en, this message translates to:
  /// **'Enable the reminder to change the time'**
  String get notificationsEnableToChangeTime;

  /// No description provided for @notificationsEveryDayAt.
  ///
  /// In en, this message translates to:
  /// **'Every day at {time}'**
  String notificationsEveryDayAt(String time);

  /// No description provided for @notificationsStatusHeading.
  ///
  /// In en, this message translates to:
  /// **'Reminder status'**
  String get notificationsStatusHeading;

  /// No description provided for @notificationsOffStatus.
  ///
  /// In en, this message translates to:
  /// **'Reminder is off.'**
  String get notificationsOffStatus;

  /// No description provided for @notificationsPermissionRequired.
  ///
  /// In en, this message translates to:
  /// **'Notification permission is required.'**
  String get notificationsPermissionRequired;

  /// No description provided for @notificationsPendingUnknown.
  ///
  /// In en, this message translates to:
  /// **'Pending Qaza could not be checked. Pull to retry.'**
  String get notificationsPendingUnknown;

  /// No description provided for @notificationsNoPending.
  ///
  /// In en, this message translates to:
  /// **'No pending Qaza. No reminder is scheduled.'**
  String get notificationsNoPending;

  /// No description provided for @notificationsScheduledAt.
  ///
  /// In en, this message translates to:
  /// **'Scheduled daily at {time}.'**
  String notificationsScheduledAt(String time);

  /// No description provided for @notificationsOnAt.
  ///
  /// In en, this message translates to:
  /// **'On • {time}'**
  String notificationsOnAt(String time);

  /// No description provided for @notificationsOnPendingWait.
  ///
  /// In en, this message translates to:
  /// **'On • starts when pending Qaza exists'**
  String get notificationsOnPendingWait;

  /// No description provided for @notificationsPermissionNeeded.
  ///
  /// In en, this message translates to:
  /// **'Permission needed'**
  String get notificationsPermissionNeeded;

  /// No description provided for @notificationsAllowPrompt.
  ///
  /// In en, this message translates to:
  /// **'Allow notifications so the app can remind you.'**
  String get notificationsAllowPrompt;

  /// No description provided for @notificationsAllow.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get notificationsAllow;

  /// No description provided for @notificationsAllowed.
  ///
  /// In en, this message translates to:
  /// **'Notifications allowed'**
  String get notificationsAllowed;

  /// No description provided for @notificationsDeviceCanDeliver.
  ///
  /// In en, this message translates to:
  /// **'This device can deliver your reminder.'**
  String get notificationsDeviceCanDeliver;

  /// No description provided for @notificationsBlocked.
  ///
  /// In en, this message translates to:
  /// **'Notifications blocked'**
  String get notificationsBlocked;

  /// No description provided for @notificationsBlockedDetail.
  ///
  /// In en, this message translates to:
  /// **'Notifications are blocked. Allow them in system settings, then try again.'**
  String get notificationsBlockedDetail;

  /// No description provided for @notificationsEnableInSettings.
  ///
  /// In en, this message translates to:
  /// **'Enable notifications in system settings to use reminders.'**
  String get notificationsEnableInSettings;

  /// No description provided for @notificationsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Notifications unavailable'**
  String get notificationsUnavailable;

  /// No description provided for @notificationsUnavailableDetail.
  ///
  /// In en, this message translates to:
  /// **'Notifications are not available on this device.'**
  String get notificationsUnavailableDetail;

  /// No description provided for @notificationsRestricted.
  ///
  /// In en, this message translates to:
  /// **'Notifications restricted'**
  String get notificationsRestricted;

  /// No description provided for @notificationsRestrictedDetail.
  ///
  /// In en, this message translates to:
  /// **'Notification delivery is restricted on this device.'**
  String get notificationsRestrictedDetail;

  /// No description provided for @notificationsEnableFailed.
  ///
  /// In en, this message translates to:
  /// **'Notifications could not be enabled on this device.'**
  String get notificationsEnableFailed;

  /// No description provided for @notificationsSendTest.
  ///
  /// In en, this message translates to:
  /// **'Send test notification'**
  String get notificationsSendTest;

  /// No description provided for @notificationsSendTestSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Send one notification now to check delivery.'**
  String get notificationsSendTestSubtitle;

  /// No description provided for @notificationsTestSent.
  ///
  /// In en, this message translates to:
  /// **'Test notification sent.'**
  String get notificationsTestSent;

  /// No description provided for @notificationsTestFailed.
  ///
  /// In en, this message translates to:
  /// **'Test notification failed: {error}'**
  String notificationsTestFailed(String error);

  /// No description provided for @welcomeTagline.
  ///
  /// In en, this message translates to:
  /// **'Spiritual Devotion & Prayer Accountability'**
  String get welcomeTagline;

  /// No description provided for @welcomeHeadline.
  ///
  /// In en, this message translates to:
  /// **'Track your missed prayers with clarity and consistency.'**
  String get welcomeHeadline;

  /// No description provided for @welcomeBody.
  ///
  /// In en, this message translates to:
  /// **'Record, complete, and keep track of your Qaza Namaz — one prayer at a time.'**
  String get welcomeBody;

  /// No description provided for @welcomeGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get welcomeGetStarted;

  /// No description provided for @welcomeSignIn.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Sign In'**
  String get welcomeSignIn;

  /// No description provided for @splashTagline.
  ///
  /// In en, this message translates to:
  /// **'A calm place for prayer accountability'**
  String get splashTagline;

  /// No description provided for @accountTitle.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountTitle;

  /// No description provided for @accountSignInMethod.
  ///
  /// In en, this message translates to:
  /// **'Sign-in method'**
  String get accountSignInMethod;

  /// No description provided for @accountGoogleAuth.
  ///
  /// In en, this message translates to:
  /// **'Google authentication'**
  String get accountGoogleAuth;

  /// No description provided for @accountSignedInWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Signed in with Google'**
  String get accountSignedInWithGoogle;

  /// No description provided for @accountStatus.
  ///
  /// In en, this message translates to:
  /// **'Account status'**
  String get accountStatus;

  /// No description provided for @accountSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Signed in'**
  String get accountSignedIn;

  /// No description provided for @accountRecordsRetained.
  ///
  /// In en, this message translates to:
  /// **'Your saved Qaza records remain stored and will be restored after the next sign-in.'**
  String get accountRecordsRetained;

  /// No description provided for @accountDeveloperContext.
  ///
  /// In en, this message translates to:
  /// **'Developer context'**
  String get accountDeveloperContext;

  /// No description provided for @accountFirebaseUid.
  ///
  /// In en, this message translates to:
  /// **'Firebase UID'**
  String get accountFirebaseUid;

  /// No description provided for @accountNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Not available'**
  String get accountNotAvailable;

  /// No description provided for @accountSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get accountSignOut;

  /// No description provided for @accountSignOutPrompt.
  ///
  /// In en, this message translates to:
  /// **'Sign out?'**
  String get accountSignOutPrompt;

  /// No description provided for @accountSignOutExplanation.
  ///
  /// In en, this message translates to:
  /// **'Signing out returns you to the welcome screen. Your saved Qaza records are NOT deleted and will be restored the next time you sign in.'**
  String get accountSignOutExplanation;

  /// No description provided for @dataTitle.
  ///
  /// In en, this message translates to:
  /// **'Export & Import'**
  String get dataTitle;

  /// No description provided for @dataExportTitle.
  ///
  /// In en, this message translates to:
  /// **'Export data'**
  String get dataExportTitle;

  /// No description provided for @dataExportBody.
  ///
  /// In en, this message translates to:
  /// **'Save a versioned JSON copy of your Qaza ledger. Nothing is uploaded by the export action.'**
  String get dataExportBody;

  /// No description provided for @dataExportAction.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get dataExportAction;

  /// No description provided for @dataExportDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Save Qaza data export'**
  String get dataExportDialogTitle;

  /// No description provided for @dataExportSaved.
  ///
  /// In en, this message translates to:
  /// **'Export saved successfully.'**
  String get dataExportSaved;

  /// No description provided for @dataExportCanceled.
  ///
  /// In en, this message translates to:
  /// **'Export canceled. Your data was not changed.'**
  String get dataExportCanceled;

  /// No description provided for @dataExportSignInRequired.
  ///
  /// In en, this message translates to:
  /// **'Sign in before exporting your Qaza data.'**
  String get dataExportSignInRequired;

  /// No description provided for @dataExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String dataExportFailed(String error);

  /// No description provided for @dataImportTitle.
  ///
  /// In en, this message translates to:
  /// **'Import data'**
  String get dataImportTitle;

  /// No description provided for @dataImportBody.
  ///
  /// In en, this message translates to:
  /// **'Open a JSON export, validate it completely, preview the merge, then apply it to this account.'**
  String get dataImportBody;

  /// No description provided for @dataImportAction.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get dataImportAction;

  /// No description provided for @dataImportReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Review data import'**
  String get dataImportReviewTitle;

  /// No description provided for @dataImportCanceled.
  ///
  /// In en, this message translates to:
  /// **'Import canceled. Your data was not changed.'**
  String get dataImportCanceled;

  /// No description provided for @dataImportSignInRequired.
  ///
  /// In en, this message translates to:
  /// **'Sign in before importing data.'**
  String get dataImportSignInRequired;

  /// No description provided for @dataImportEmptyFile.
  ///
  /// In en, this message translates to:
  /// **'The selected file is empty or unreadable.'**
  String get dataImportEmptyFile;

  /// No description provided for @dataImportRejected.
  ///
  /// In en, this message translates to:
  /// **'Import rejected: {error}\nNo partial import was applied.'**
  String dataImportRejected(String error);

  /// No description provided for @dataImportComplete.
  ///
  /// In en, this message translates to:
  /// **'Import complete: {added} added, {completed} completed, {unchanged} unchanged.'**
  String dataImportComplete(int added, int completed, int unchanged);

  /// No description provided for @dataProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing data…'**
  String get dataProcessing;

  /// No description provided for @dataSafetyTitle.
  ///
  /// In en, this message translates to:
  /// **'Data safety'**
  String get dataSafetyTitle;

  /// No description provided for @dataSafetyBody.
  ///
  /// In en, this message translates to:
  /// **'Export does not delete cloud data. Import does not erase existing records. Sign-out is not data deletion, and uninstalling the app does not delete cloud records.'**
  String get dataSafetyBody;

  /// No description provided for @dataRemapNote.
  ///
  /// In en, this message translates to:
  /// **'Imported records are remapped to the currently signed-in account. The existing local-first sync layer then confirms changes with Firestore in the background.'**
  String get dataRemapNote;

  /// No description provided for @addQazaTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Qaza'**
  String get addQazaTitle;

  /// No description provided for @addQazaStep1.
  ///
  /// In en, this message translates to:
  /// **'Step 1 of 3 • Select Dates'**
  String get addQazaStep1;

  /// No description provided for @addQazaStep2.
  ///
  /// In en, this message translates to:
  /// **'Step 2 of 3 • Select Missed Prayers'**
  String get addQazaStep2;

  /// No description provided for @addQazaStep3.
  ///
  /// In en, this message translates to:
  /// **'Step 3 of 3 • Review & Add'**
  String get addQazaStep3;

  /// No description provided for @addQazaModeSingle.
  ///
  /// In en, this message translates to:
  /// **'Single'**
  String get addQazaModeSingle;

  /// No description provided for @addQazaModeRange.
  ///
  /// In en, this message translates to:
  /// **'Range'**
  String get addQazaModeRange;

  /// No description provided for @addQazaModeMultiple.
  ///
  /// In en, this message translates to:
  /// **'Multiple'**
  String get addQazaModeMultiple;

  /// No description provided for @addQazaModeSingleTitle.
  ///
  /// In en, this message translates to:
  /// **'Single date'**
  String get addQazaModeSingleTitle;

  /// No description provided for @addQazaModeRangeTitle.
  ///
  /// In en, this message translates to:
  /// **'Date range'**
  String get addQazaModeRangeTitle;

  /// No description provided for @addQazaModeMultipleTitle.
  ///
  /// In en, this message translates to:
  /// **'Multiple dates'**
  String get addQazaModeMultipleTitle;

  /// No description provided for @addQazaChooseSingle.
  ///
  /// In en, this message translates to:
  /// **'Choose a date'**
  String get addQazaChooseSingle;

  /// No description provided for @addQazaChooseRange.
  ///
  /// In en, this message translates to:
  /// **'Choose a date range'**
  String get addQazaChooseRange;

  /// No description provided for @addQazaChooseMultiple.
  ///
  /// In en, this message translates to:
  /// **'Choose multiple dates'**
  String get addQazaChooseMultiple;

  /// No description provided for @addQazaAvailabilityNote.
  ///
  /// In en, this message translates to:
  /// **'A date is disabled only when no prayer remains eligible.'**
  String get addQazaAvailabilityNote;

  /// No description provided for @addQazaStepNameDates.
  ///
  /// In en, this message translates to:
  /// **'Select Dates'**
  String get addQazaStepNameDates;

  /// No description provided for @addQazaStepNamePrayers.
  ///
  /// In en, this message translates to:
  /// **'Missed Prayers'**
  String get addQazaStepNamePrayers;

  /// No description provided for @addQazaStepNameReview.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get addQazaStepNameReview;

  /// No description provided for @addQazaStepSemantics.
  ///
  /// In en, this message translates to:
  /// **'Step {step}: {name}'**
  String addQazaStepSemantics(int step, String name);

  /// No description provided for @addQazaPartialAvailability.
  ///
  /// In en, this message translates to:
  /// **'Available on {available} of {total} dates'**
  String addQazaPartialAvailability(int available, int total);

  /// No description provided for @addQazaAvailableEveryDate.
  ///
  /// In en, this message translates to:
  /// **'Available on every selected date'**
  String get addQazaAvailableEveryDate;

  /// No description provided for @addQazaEligibleOnlyNote.
  ///
  /// In en, this message translates to:
  /// **'Only eligible date + prayer combinations are added. Anything already recorded is skipped.'**
  String get addQazaEligibleOnlyNote;

  /// No description provided for @addQazaAddCount.
  ///
  /// In en, this message translates to:
  /// **'Add {count} Qaza'**
  String addQazaAddCount(String count);

  /// No description provided for @addQazaNothingNew.
  ///
  /// In en, this message translates to:
  /// **'Nothing new to add — these combinations are already recorded.'**
  String get addQazaNothingNew;

  /// No description provided for @addQazaChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking your ledger...'**
  String get addQazaChecking;

  /// No description provided for @addQazaNextPrayers.
  ///
  /// In en, this message translates to:
  /// **'Next: Review & Add'**
  String get addQazaNextPrayers;

  /// No description provided for @addQazaPrayersHeading.
  ///
  /// In en, this message translates to:
  /// **'Missed Prayers'**
  String get addQazaPrayersHeading;

  /// No description provided for @addQazaSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select All'**
  String get addQazaSelectAll;

  /// No description provided for @addQazaAllSelected.
  ///
  /// In en, this message translates to:
  /// **'All selected'**
  String get addQazaAllSelected;

  /// No description provided for @addQazaReviewHeading.
  ///
  /// In en, this message translates to:
  /// **'Review & Add'**
  String get addQazaReviewHeading;

  /// No description provided for @addQazaReviewNote.
  ///
  /// In en, this message translates to:
  /// **'Confirm the summary, then add these Qaza records to your ledger.'**
  String get addQazaReviewNote;

  /// No description provided for @addQazaCombinationNote.
  ///
  /// In en, this message translates to:
  /// **'Each date + prayer combination becomes an independent pending record. Existing combinations are skipped automatically.'**
  String get addQazaCombinationNote;

  /// No description provided for @addQazaSelectionLabel.
  ///
  /// In en, this message translates to:
  /// **'Selection'**
  String get addQazaSelectionLabel;

  /// No description provided for @addQazaDatesLabel.
  ///
  /// In en, this message translates to:
  /// **'Dates'**
  String get addQazaDatesLabel;

  /// No description provided for @addQazaDateCountLabel.
  ///
  /// In en, this message translates to:
  /// **'Date count'**
  String get addQazaDateCountLabel;

  /// No description provided for @addQazaDateRangeLabel.
  ///
  /// In en, this message translates to:
  /// **'Date range'**
  String get addQazaDateRangeLabel;

  /// No description provided for @addQazaPrayersLabel.
  ///
  /// In en, this message translates to:
  /// **'Prayers'**
  String get addQazaPrayersLabel;

  /// No description provided for @addQazaPrayersPerDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Prayers per date'**
  String get addQazaPrayersPerDateLabel;

  /// No description provided for @addQazaExistingLabel.
  ///
  /// In en, this message translates to:
  /// **'Existing combinations'**
  String get addQazaExistingLabel;

  /// No description provided for @addQazaNewRecordsLabel.
  ///
  /// In en, this message translates to:
  /// **'New records'**
  String get addQazaNewRecordsLabel;

  /// No description provided for @addQazaNewQazaLabel.
  ///
  /// In en, this message translates to:
  /// **'New Qaza records'**
  String get addQazaNewQazaLabel;

  /// No description provided for @addQazaInProgress.
  ///
  /// In en, this message translates to:
  /// **'Adding Qaza...'**
  String get addQazaInProgress;

  /// No description provided for @addQazaCreatedTitle.
  ///
  /// In en, this message translates to:
  /// **'Qaza records created'**
  String get addQazaCreatedTitle;

  /// No description provided for @addQazaSelectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day selected • Which prayers did you miss?} other{{count} days selected • Which prayers did you miss?}}'**
  String addQazaSelectedCount(int count);

  /// No description provided for @addQazaDateCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 date} other{{count} dates}}'**
  String addQazaDateCount(int count);

  /// No description provided for @addQazaCreatedMessage.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 record was added to your ledger.} other{{count} records were added to your ledger.}}'**
  String addQazaCreatedMessage(int count);

  /// No description provided for @addQazaUnavailablePrayer.
  ///
  /// In en, this message translates to:
  /// **'{rakats} • Already recorded or prayed on every selected date'**
  String addQazaUnavailablePrayer(String rakats);

  /// No description provided for @commonNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get commonNone;

  /// No description provided for @completeTitle.
  ///
  /// In en, this message translates to:
  /// **'Complete Qaza'**
  String get completeTitle;

  /// No description provided for @completeHeading.
  ///
  /// In en, this message translates to:
  /// **'Complete the latest pending record'**
  String get completeHeading;

  /// No description provided for @completeIntro.
  ///
  /// In en, this message translates to:
  /// **'Complete one record at a time. After success, the next pending record is shown immediately.'**
  String get completeIntro;

  /// No description provided for @completeLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading latest pending record…'**
  String get completeLoading;

  /// No description provided for @completeLoadError.
  ///
  /// In en, this message translates to:
  /// **'We could not load your Qaza record.'**
  String get completeLoadError;

  /// No description provided for @completeNoPendingTitle.
  ///
  /// In en, this message translates to:
  /// **'No pending Qaza for this prayer.'**
  String get completeNoPendingTitle;

  /// No description provided for @completeNoPendingMessage.
  ///
  /// In en, this message translates to:
  /// **'Choose another prayer or add a Qaza record first.'**
  String get completeNoPendingMessage;

  /// No description provided for @completeOldestSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Latest pending record'**
  String get completeOldestSubtitle;

  /// No description provided for @completeOriginalDate.
  ///
  /// In en, this message translates to:
  /// **'Original missed date'**
  String get completeOriginalDate;

  /// No description provided for @completeTimestampNote.
  ///
  /// In en, this message translates to:
  /// **'Completion timestamp is recorded separately.'**
  String get completeTimestampNote;

  /// No description provided for @completeAction.
  ///
  /// In en, this message translates to:
  /// **'Complete latest pending'**
  String get completeAction;

  /// No description provided for @completeInProgress.
  ///
  /// In en, this message translates to:
  /// **'Completing...'**
  String get completeInProgress;

  /// No description provided for @completeFailed.
  ///
  /// In en, this message translates to:
  /// **'Qaza could not be completed. Please try again.'**
  String get completeFailed;

  /// No description provided for @completePrayerQaza.
  ///
  /// In en, this message translates to:
  /// **'{prayer} Qaza'**
  String completePrayerQaza(String prayer);

  /// No description provided for @completeSuccess.
  ///
  /// In en, this message translates to:
  /// **'{prayer} Qaza completed successfully.'**
  String completeSuccess(String prayer);

  /// No description provided for @completeSuccessNext.
  ///
  /// In en, this message translates to:
  /// **'{prayer} Qaza completed • the next one is ready.'**
  String completeSuccessNext(String prayer);

  /// No description provided for @knowledgeBaseTitle.
  ///
  /// In en, this message translates to:
  /// **'Knowledge Base'**
  String get knowledgeBaseTitle;

  /// No description provided for @knowledgeBaseSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search Masail & Mugalat'**
  String get knowledgeBaseSearchHint;

  /// No description provided for @knowledgeBaseClearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get knowledgeBaseClearSearch;

  /// No description provided for @knowledgeCategoryMasail.
  ///
  /// In en, this message translates to:
  /// **'Masail'**
  String get knowledgeCategoryMasail;

  /// No description provided for @knowledgeCategoryMugalat.
  ///
  /// In en, this message translates to:
  /// **'Mugalat'**
  String get knowledgeCategoryMugalat;

  /// No description provided for @knowledgeBaseTopicAll.
  ///
  /// In en, this message translates to:
  /// **'All topics'**
  String get knowledgeBaseTopicAll;

  /// No description provided for @knowledgeTopicBasic.
  ///
  /// In en, this message translates to:
  /// **'Basics'**
  String get knowledgeTopicBasic;

  /// No description provided for @knowledgeTopicPrayerUnits.
  ///
  /// In en, this message translates to:
  /// **'Prayer units'**
  String get knowledgeTopicPrayerUnits;

  /// No description provided for @knowledgeTopicSleepForgetfulness.
  ///
  /// In en, this message translates to:
  /// **'Sleep & forgetfulness'**
  String get knowledgeTopicSleepForgetfulness;

  /// No description provided for @knowledgeTopicIntentionalOmission.
  ///
  /// In en, this message translates to:
  /// **'Intentional omission'**
  String get knowledgeTopicIntentionalOmission;

  /// No description provided for @knowledgeTopicFriday.
  ///
  /// In en, this message translates to:
  /// **'Friday'**
  String get knowledgeTopicFriday;

  /// No description provided for @knowledgeTopicMenstruation.
  ///
  /// In en, this message translates to:
  /// **'Menstruation'**
  String get knowledgeTopicMenstruation;

  /// No description provided for @knowledgeTopicNifas.
  ///
  /// In en, this message translates to:
  /// **'Nifas'**
  String get knowledgeTopicNifas;

  /// No description provided for @knowledgeTopicMenstruationNifas.
  ///
  /// In en, this message translates to:
  /// **'Menstruation & Nifas'**
  String get knowledgeTopicMenstruationNifas;

  /// No description provided for @knowledgeTopicMisconceptions.
  ///
  /// In en, this message translates to:
  /// **'Misconceptions'**
  String get knowledgeTopicMisconceptions;

  /// No description provided for @knowledgeBaseEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No articles found'**
  String get knowledgeBaseEmptyTitle;

  /// No description provided for @knowledgeBaseEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Try another search or category.'**
  String get knowledgeBaseEmptyMessage;

  /// No description provided for @knowledgeBaseLoadError.
  ///
  /// In en, this message translates to:
  /// **'Knowledge Base could not be loaded.'**
  String get knowledgeBaseLoadError;

  /// No description provided for @knowledgeBaseLanguage.
  ///
  /// In en, this message translates to:
  /// **'Knowledge Base language'**
  String get knowledgeBaseLanguage;

  /// No description provided for @knowledgeArticleTitle.
  ///
  /// In en, this message translates to:
  /// **'Article'**
  String get knowledgeArticleTitle;

  /// No description provided for @knowledgeArticleReferences.
  ///
  /// In en, this message translates to:
  /// **'References'**
  String get knowledgeArticleReferences;

  /// No description provided for @knowledgeArticleRelated.
  ///
  /// In en, this message translates to:
  /// **'Related articles'**
  String get knowledgeArticleRelated;

  /// No description provided for @knowledgeArticleNotFound.
  ///
  /// In en, this message translates to:
  /// **'Article not found.'**
  String get knowledgeArticleNotFound;

  /// Title of the daily reminder notification
  ///
  /// In en, this message translates to:
  /// **'Qaza Namaz reminder'**
  String get notificationReminderTitle;

  /// No description provided for @notificationReminderBody.
  ///
  /// In en, this message translates to:
  /// **'Continue your Qaza prayers with consistency.'**
  String get notificationReminderBody;

  /// No description provided for @notificationTestTitle.
  ///
  /// In en, this message translates to:
  /// **'Qaza Namaz'**
  String get notificationTestTitle;

  /// No description provided for @notificationTestBody.
  ///
  /// In en, this message translates to:
  /// **'Test notification received successfully.'**
  String get notificationTestBody;

  /// No description provided for @notificationChannelName.
  ///
  /// In en, this message translates to:
  /// **'Qaza daily reminder'**
  String get notificationChannelName;

  /// No description provided for @notificationChannelDescription.
  ///
  /// In en, this message translates to:
  /// **'Daily reminder to continue completing Qaza prayers.'**
  String get notificationChannelDescription;

  /// No description provided for @settingsAccountSection.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsAccountSection;

  /// No description provided for @settingsAccountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage your sign-in and account details.'**
  String get settingsAccountSubtitle;

  /// No description provided for @settingsGoogleSignIn.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in'**
  String get settingsGoogleSignIn;

  /// No description provided for @settingsKnowledgeBaseSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Browse Masail & Mugalat'**
  String get settingsKnowledgeBaseSubtitle;

  /// No description provided for @settingsNotificationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage reminders and notification scheduling.'**
  String get settingsNotificationsSubtitle;

  /// No description provided for @settingsNotificationsRowSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Daily reminder and schedule'**
  String get settingsNotificationsRowSubtitle;

  /// No description provided for @settingsDataSection.
  ///
  /// In en, this message translates to:
  /// **'Data & Storage'**
  String get settingsDataSection;

  /// No description provided for @settingsDataSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sync, backup, export, and import your Qaza data.'**
  String get settingsDataSubtitle;

  /// No description provided for @settingsDataCloud.
  ///
  /// In en, this message translates to:
  /// **'Data & Cloud'**
  String get settingsDataCloud;

  /// No description provided for @settingsDataCloudSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sync, export and import status'**
  String get settingsDataCloudSubtitle;

  /// No description provided for @settingsResetCounterTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset Qaza Counter'**
  String get settingsResetCounterTitle;

  /// No description provided for @settingsResetCounterSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Delete every recorded Qaza and start the count again from zero.'**
  String get settingsResetCounterSubtitle;

  /// No description provided for @settingsResetCounterEmpty.
  ///
  /// In en, this message translates to:
  /// **'There are no Qaza records to reset.'**
  String get settingsResetCounterEmpty;

  /// No description provided for @settingsResetCounterDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset Qaza Counter?'**
  String get settingsResetCounterDialogTitle;

  /// No description provided for @settingsResetCounterDialogMessage.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes every Qaza record on this account — pending and completed — from this device and from your cloud backup.\n\nYour counter returns to zero and the completion progress you have built up is lost. This cannot be undone. Export your data first if you may want it back.'**
  String get settingsResetCounterDialogMessage;

  /// No description provided for @settingsResetCounterAcknowledge.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{I understand that 1 Qaza record will be permanently deleted} other{I understand that {count} Qaza records will be permanently deleted}}'**
  String settingsResetCounterAcknowledge(int count);

  /// No description provided for @settingsResetCounterConfirm.
  ///
  /// In en, this message translates to:
  /// **'Reset counter'**
  String get settingsResetCounterConfirm;

  /// No description provided for @settingsResetCounterDone.
  ///
  /// In en, this message translates to:
  /// **'Qaza counter reset.'**
  String get settingsResetCounterDone;

  /// No description provided for @settingsResetCounterFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not reset the Qaza counter: {error}'**
  String settingsResetCounterFailed(String error);

  /// No description provided for @authContinueAsGuest.
  ///
  /// In en, this message translates to:
  /// **'Continue as Guest'**
  String get authContinueAsGuest;

  /// No description provided for @authGuestNote.
  ///
  /// In en, this message translates to:
  /// **'You can sign in later to back up your progress.'**
  String get authGuestNote;

  /// No description provided for @backupPromptTitle.
  ///
  /// In en, this message translates to:
  /// **'Keep your progress safe'**
  String get backupPromptTitle;

  /// No description provided for @backupPromptBody.
  ///
  /// In en, this message translates to:
  /// **'Your Qaza progress is saved on this device. Sign in to back it up and restore it on another device.'**
  String get backupPromptBody;

  /// No description provided for @backupPromptConfirm.
  ///
  /// In en, this message translates to:
  /// **'Back Up My Progress'**
  String get backupPromptConfirm;

  /// No description provided for @backupPromptDismiss.
  ///
  /// In en, this message translates to:
  /// **'Not Now'**
  String get backupPromptDismiss;

  /// No description provided for @settingsBackupSignIn.
  ///
  /// In en, this message translates to:
  /// **'Back up / Sign in'**
  String get settingsBackupSignIn;

  /// No description provided for @settingsBackupSignInSubtitle.
  ///
  /// In en, this message translates to:
  /// **'You are using the app as a guest. Sign in to back up your Qaza.'**
  String get settingsBackupSignInSubtitle;

  /// No description provided for @backupSignInFailed.
  ///
  /// In en, this message translates to:
  /// **'Sign-in failed. Your progress is still on this device.'**
  String get backupSignInFailed;

  /// No description provided for @backupMigrationDone.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Signed in. Your progress is backed up.} =1{Signed in. 1 record was added to your account.} other{Signed in. {count} records were added to your account.}}'**
  String backupMigrationDone(int count);

  /// No description provided for @settingsAboutSection.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAboutSection;

  /// No description provided for @settingsAboutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'App information and version details.'**
  String get settingsAboutSubtitle;

  /// No description provided for @settingsAboutRowSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Qaza Namaz • version {version}'**
  String settingsAboutRowSubtitle(String version);

  /// No description provided for @settingsAppDescription.
  ///
  /// In en, this message translates to:
  /// **'Islamic Prayer Qaza Tracker'**
  String get settingsAppDescription;

  /// No description provided for @cloudSyncTitle.
  ///
  /// In en, this message translates to:
  /// **'Cloud Sync'**
  String get cloudSyncTitle;

  /// No description provided for @cloudSyncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get cloudSyncNow;

  /// No description provided for @cloudPendingChanges.
  ///
  /// In en, this message translates to:
  /// **'Pending changes'**
  String get cloudPendingChanges;

  /// No description provided for @cloudLastSynced.
  ///
  /// In en, this message translates to:
  /// **'Last synced'**
  String get cloudLastSynced;

  /// No description provided for @cloudExportImportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'User-controlled JSON backup and safe restore. No cloud data is deleted by these actions.'**
  String get cloudExportImportSubtitle;

  /// No description provided for @cloudInactive.
  ///
  /// In en, this message translates to:
  /// **'Offline storage is not active in this build.'**
  String get cloudInactive;

  /// No description provided for @cloudBootstrapping.
  ///
  /// In en, this message translates to:
  /// **'Setting up your Qaza records on this device…'**
  String get cloudBootstrapping;

  /// No description provided for @cloudHydrating.
  ///
  /// In en, this message translates to:
  /// **'Restoring your saved Qaza records to this device…'**
  String get cloudHydrating;

  /// No description provided for @cloudSynced.
  ///
  /// In en, this message translates to:
  /// **'All your Qaza records are saved in the cloud.'**
  String get cloudSynced;

  /// No description provided for @cloudSyncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing your ledger…'**
  String get cloudSyncing;

  /// No description provided for @cloudOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline — records are saved on this device and sync automatically.'**
  String get cloudOffline;

  /// No description provided for @cloudPendingCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 change waiting to sync.} other{{count} changes waiting to sync.}}'**
  String cloudPendingCount(int count);

  /// No description provided for @cloudSyncProblem.
  ///
  /// In en, this message translates to:
  /// **'Sync problem — your data is safe on this device.'**
  String get cloudSyncProblem;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// No description provided for @settingsAppearanceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose how the app looks on this device.'**
  String get settingsAppearanceSubtitle;

  /// No description provided for @settingsThemeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsThemeSystem;

  /// No description provided for @settingsThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsThemeDark;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Select the language used throughout the app.'**
  String get settingsLanguageSubtitle;

  /// No description provided for @settingsLanguageNote.
  ///
  /// In en, this message translates to:
  /// **'Prayer names and Hijri dates follow the selected language. Urdu is written right to left.'**
  String get settingsLanguageNote;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageUrdu.
  ///
  /// In en, this message translates to:
  /// **'اردو'**
  String get languageUrdu;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ur'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ur':
      return AppLocalizationsUr();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
