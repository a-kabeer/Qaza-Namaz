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

  /// No description provided for @navKnowledge.
  ///
  /// In en, this message translates to:
  /// **'Knowledge'**
  String get navKnowledge;

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

  /// No description provided for @statusDeleted.
  ///
  /// In en, this message translates to:
  /// **'Recently deleted'**
  String get statusDeleted;

  /// No description provided for @statusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get statusCompleted;

  /// No description provided for @qazaConfirmBulkTitle.
  ///
  /// In en, this message translates to:
  /// **'Complete {count} records?'**
  String qazaConfirmBulkTitle(String count);

  /// No description provided for @qazaConfirmBulkMessage.
  ///
  /// In en, this message translates to:
  /// **'This marks {count} pending prayers as completed. You can undo it straight afterwards, but not later.'**
  String qazaConfirmBulkMessage(String count);

  /// No description provided for @qazaConfirmBulkAction.
  ///
  /// In en, this message translates to:
  /// **'Complete them'**
  String get qazaConfirmBulkAction;

  /// No description provided for @errorNetwork.
  ///
  /// In en, this message translates to:
  /// **'No connection. Your Qaza are saved on this device and will sync when you are back online.'**
  String get errorNetwork;

  /// No description provided for @errorTimeout.
  ///
  /// In en, this message translates to:
  /// **'That took too long. Try again in a moment.'**
  String get errorTimeout;

  /// No description provided for @errorPermission.
  ///
  /// In en, this message translates to:
  /// **'Permission is needed for this. Open Settings to grant it.'**
  String get errorPermission;

  /// No description provided for @errorAuthentication.
  ///
  /// In en, this message translates to:
  /// **'You need to be signed in for this.'**
  String get errorAuthentication;

  /// No description provided for @errorValidation.
  ///
  /// In en, this message translates to:
  /// **'That input was not accepted. Check it and try again.'**
  String get errorValidation;

  /// No description provided for @errorMalformedData.
  ///
  /// In en, this message translates to:
  /// **'That file is not a Qaza backup, or it is damaged.'**
  String get errorMalformedData;

  /// No description provided for @errorStorage.
  ///
  /// In en, this message translates to:
  /// **'This device could not save the change. Free some space and try again.'**
  String get errorStorage;

  /// No description provided for @errorUnknown.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong.'**
  String get errorUnknown;

  /// No description provided for @homeTartibCheckingTitle.
  ///
  /// In en, this message translates to:
  /// **'Checking the prayer order'**
  String get homeTartibCheckingTitle;

  /// No description provided for @homeTartibCheckingBody.
  ///
  /// In en, this message translates to:
  /// **'Sahib al-Tartib decides which Fard prayer comes next. One moment.'**
  String get homeTartibCheckingBody;

  /// No description provided for @homeTartibFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not check the prayer order'**
  String get homeTartibFailedTitle;

  /// No description provided for @homeTartibFailedBody.
  ///
  /// In en, this message translates to:
  /// **'Fard prayers are held back until the order is known, so nothing is completed out of sequence. Witr can still be completed from the prayer menu.'**
  String get homeTartibFailedBody;

  /// No description provided for @qazaSortOldestFirst.
  ///
  /// In en, this message translates to:
  /// **'Oldest first'**
  String get qazaSortOldestFirst;

  /// No description provided for @qazaSortNewestFirst.
  ///
  /// In en, this message translates to:
  /// **'Newest first'**
  String get qazaSortNewestFirst;

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

  /// No description provided for @homeSetupMessage.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t added any Qaza prayers yet.'**
  String get homeSetupMessage;

  /// No description provided for @homeCompleteQaza.
  ///
  /// In en, this message translates to:
  /// **'Complete Qaza'**
  String get homeCompleteQaza;

  /// No description provided for @homeStatTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get homeStatTotal;

  /// No description provided for @homeProgressError.
  ///
  /// In en, this message translates to:
  /// **'Unable to load your Qaza progress. Pull to retry.'**
  String get homeProgressError;

  /// No description provided for @homeQazaPlan.
  ///
  /// In en, this message translates to:
  /// **'Qaza plan'**
  String get homeQazaPlan;

  /// No description provided for @homeAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get homeAuto;

  /// No description provided for @homeDailyTarget.
  ///
  /// In en, this message translates to:
  /// **'Daily target'**
  String get homeDailyTarget;

  /// No description provided for @homePerDay.
  ///
  /// In en, this message translates to:
  /// **'{count} per day'**
  String homePerDay(int count);

  /// No description provided for @homeEstimatedCompletion.
  ///
  /// In en, this message translates to:
  /// **'Estimated completion: {date}'**
  String homeEstimatedCompletion(String date);

  /// No description provided for @homeNextQaza.
  ///
  /// In en, this message translates to:
  /// **'Next Qaza'**
  String get homeNextQaza;

  /// No description provided for @homeDailyProgressError.
  ///
  /// In en, this message translates to:
  /// **'Today\'s progress could not be loaded.'**
  String get homeDailyProgressError;

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

  /// No description provided for @qazaTartibRequiredMessage.
  ///
  /// In en, this message translates to:
  /// **'You have {count} outstanding Fard prayers. According to this ruling, complete {prayer} Qaza before other pending prayers.'**
  String qazaTartibRequiredMessage(int count, String prayer);

  /// No description provided for @qazaTartibBlocked.
  ///
  /// In en, this message translates to:
  /// **'Qaza order is required. Complete {prayer} Qaza first.'**
  String qazaTartibBlocked(String prayer);

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

  /// No description provided for @qazaEditRecordTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Qaza'**
  String get qazaEditRecordTitle;

  /// No description provided for @qazaEditPrayer.
  ///
  /// In en, this message translates to:
  /// **'Prayer'**
  String get qazaEditPrayer;

  /// No description provided for @qazaEditDate.
  ///
  /// In en, this message translates to:
  /// **'Original date'**
  String get qazaEditDate;

  /// No description provided for @qazaEditDateHelp.
  ///
  /// In en, this message translates to:
  /// **'Select original Qaza date'**
  String get qazaEditDateHelp;

  /// No description provided for @qazaSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get qazaSaveChanges;

  /// No description provided for @qazaUndoAction.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get qazaUndoAction;

  /// No description provided for @qazaUndoAvailable.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Recent completion can be undone.} other{Recent completions can be undone.}}'**
  String qazaUndoAvailable(int count);

  /// No description provided for @splashTagline.
  ///
  /// In en, this message translates to:
  /// **'A calm place for prayer accountability'**
  String get splashTagline;

  /// No description provided for @addQazaNothingNew.
  ///
  /// In en, this message translates to:
  /// **'Nothing new to add — these combinations are already recorded.'**
  String get addQazaNothingNew;

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

  /// No description provided for @addQazaInProgress.
  ///
  /// In en, this message translates to:
  /// **'Adding Qaza...'**
  String get addQazaInProgress;

  /// No description provided for @addQazaCreatedMessage.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 record was added to your ledger.} other{{count} records were added to your ledger.}}'**
  String addQazaCreatedMessage(int count);

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

  /// No description provided for @settingsAboutSection.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAboutSection;

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

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

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

  /// No description provided for @homeTodayProgressHeader.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Progress'**
  String get homeTodayProgressHeader;

  /// No description provided for @homeOldestPending.
  ///
  /// In en, this message translates to:
  /// **'Oldest Pending'**
  String get homeOldestPending;

  /// No description provided for @homeOverallQaza.
  ///
  /// In en, this message translates to:
  /// **'Overall Qaza'**
  String get homeOverallQaza;

  /// No description provided for @homePendingByPrayer.
  ///
  /// In en, this message translates to:
  /// **'Pending by Prayer'**
  String get homePendingByPrayer;

  /// No description provided for @homePrayerBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Prayer Breakdown'**
  String get homePrayerBreakdown;

  /// No description provided for @homeViewDetails.
  ///
  /// In en, this message translates to:
  /// **'View details'**
  String get homeViewDetails;

  /// No description provided for @homeViewAll.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get homeViewAll;

  /// No description provided for @homeCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get homeCompleted;

  /// No description provided for @homePending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get homePending;

  /// No description provided for @homeDetailedStatistics.
  ///
  /// In en, this message translates to:
  /// **'View Detailed Statistics'**
  String get homeDetailedStatistics;

  /// No description provided for @homeSahibOrderLabel.
  ///
  /// In en, this message translates to:
  /// **'Sahib al-Tartib: {prayer}'**
  String homeSahibOrderLabel(String prayer);

  /// No description provided for @profileLanguageTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose your language'**
  String get profileLanguageTitle;

  /// No description provided for @profileLanguageIntro.
  ///
  /// In en, this message translates to:
  /// **'Select the language you want to use throughout the app.'**
  String get profileLanguageIntro;

  /// No description provided for @profileSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Set up your profile'**
  String get profileSetupTitle;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// No description provided for @profileIntro.
  ///
  /// In en, this message translates to:
  /// **'These details personalize your Qaza plan and are used by the app\'s prayer rules.'**
  String get profileIntro;

  /// No description provided for @profileSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your prayer profile and Qaza plan settings.'**
  String get profileSettingsSubtitle;

  /// No description provided for @profileGender.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get profileGender;

  /// No description provided for @profileMale.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get profileMale;

  /// No description provided for @profileFemale.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get profileFemale;

  /// No description provided for @profileMadhab.
  ///
  /// In en, this message translates to:
  /// **'Madhab / School of Thought'**
  String get profileMadhab;

  /// No description provided for @profileHanafi.
  ///
  /// In en, this message translates to:
  /// **'Hanafi'**
  String get profileHanafi;

  /// No description provided for @profileShafi.
  ///
  /// In en, this message translates to:
  /// **'Shafi'**
  String get profileShafi;

  /// No description provided for @profileMaliki.
  ///
  /// In en, this message translates to:
  /// **'Maliki'**
  String get profileMaliki;

  /// No description provided for @profileHanbali.
  ///
  /// In en, this message translates to:
  /// **'Hanbali'**
  String get profileHanbali;

  /// No description provided for @profileOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get profileOther;

  /// No description provided for @profileDateOfBirth.
  ///
  /// In en, this message translates to:
  /// **'Date of Birth'**
  String get profileDateOfBirth;

  /// No description provided for @profileSelectDate.
  ///
  /// In en, this message translates to:
  /// **'Select date'**
  String get profileSelectDate;

  /// No description provided for @profileSelectDobHelp.
  ///
  /// In en, this message translates to:
  /// **'Select your date of birth'**
  String get profileSelectDobHelp;

  /// No description provided for @profilePubertyAge.
  ///
  /// In en, this message translates to:
  /// **'Puberty Age'**
  String get profilePubertyAge;

  /// No description provided for @profileStartPrayingAge.
  ///
  /// In en, this message translates to:
  /// **'Start Praying Age'**
  String get profileStartPrayingAge;

  /// No description provided for @profileSelectGenderFirst.
  ///
  /// In en, this message translates to:
  /// **'Select gender first'**
  String get profileSelectGenderFirst;

  /// No description provided for @profileSelectPubertyFirst.
  ///
  /// In en, this message translates to:
  /// **'Select puberty age first'**
  String get profileSelectPubertyFirst;

  /// No description provided for @profileSelectDobFirst.
  ///
  /// In en, this message translates to:
  /// **'Select date of birth first'**
  String get profileSelectDobFirst;

  /// No description provided for @profileWitr.
  ///
  /// In en, this message translates to:
  /// **'Witr'**
  String get profileWitr;

  /// No description provided for @profileWitrOptional.
  ///
  /// In en, this message translates to:
  /// **'For Other, you can choose whether Witr is included.'**
  String get profileWitrOptional;

  /// No description provided for @profileWitrIncluded.
  ///
  /// In en, this message translates to:
  /// **'Included'**
  String get profileWitrIncluded;

  /// No description provided for @profileWitrExcluded.
  ///
  /// In en, this message translates to:
  /// **'Not included'**
  String get profileWitrExcluded;

  /// No description provided for @profileSubmit.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get profileSubmit;

  /// No description provided for @profileSave.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get profileSave;

  /// No description provided for @qazaReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Review Your Qaza Plan'**
  String get qazaReviewTitle;

  /// No description provided for @qazaReviewSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Please review your Qaza details before adding them to your tracker.'**
  String get qazaReviewSubtitle;

  /// No description provided for @qazaReviewTotal.
  ///
  /// In en, this message translates to:
  /// **'Total Estimated Qaza'**
  String get qazaReviewTotal;

  /// No description provided for @qazaReviewPeriod.
  ///
  /// In en, this message translates to:
  /// **'Qaza Period'**
  String get qazaReviewPeriod;

  /// No description provided for @qazaReviewBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Prayer Breakdown'**
  String get qazaReviewBreakdown;

  /// No description provided for @qazaReviewNote.
  ///
  /// In en, this message translates to:
  /// **'These are estimated Qaza prayers based on the information in your profile.'**
  String get qazaReviewNote;

  /// No description provided for @qazaReviewEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit My Details'**
  String get qazaReviewEdit;

  /// No description provided for @qazaReviewAdd.
  ///
  /// In en, this message translates to:
  /// **'Add Qaza to My Tracker'**
  String get qazaReviewAdd;

  /// No description provided for @qazaReviewAdding.
  ///
  /// In en, this message translates to:
  /// **'Adding Qaza…'**
  String get qazaReviewAdding;

  /// No description provided for @qazaReviewError.
  ///
  /// In en, this message translates to:
  /// **'Qaza could not be added. Please try again.'**
  String get qazaReviewError;

  /// No description provided for @profileErrorLanguage.
  ///
  /// In en, this message translates to:
  /// **'Please select a language.'**
  String get profileErrorLanguage;

  /// No description provided for @profileErrorGender.
  ///
  /// In en, this message translates to:
  /// **'Please select your gender.'**
  String get profileErrorGender;

  /// No description provided for @profileErrorMadhab.
  ///
  /// In en, this message translates to:
  /// **'Please select your school of thought.'**
  String get profileErrorMadhab;

  /// No description provided for @profileErrorDob.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid date of birth.'**
  String get profileErrorDob;

  /// No description provided for @profileErrorPuberty.
  ///
  /// In en, this message translates to:
  /// **'Please select a valid puberty age for the selected gender.'**
  String get profileErrorPuberty;

  /// No description provided for @profileErrorStartPraying.
  ///
  /// In en, this message translates to:
  /// **'Please select a valid praying start age.'**
  String get profileErrorStartPraying;

  /// No description provided for @profileErrorWitr.
  ///
  /// In en, this message translates to:
  /// **'Please select a valid Witr setting.'**
  String get profileErrorWitr;
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
