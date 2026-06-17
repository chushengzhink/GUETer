import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

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

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
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
    Locale('zh'),
  ];

  /// No description provided for @appCourses.
  ///
  /// In en, this message translates to:
  /// **'Courses'**
  String get appCourses;

  /// No description provided for @appAccounts.
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get appAccounts;

  /// No description provided for @appTodos.
  ///
  /// In en, this message translates to:
  /// **'Todos'**
  String get appTodos;

  /// No description provided for @appTools.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get appTools;

  /// No description provided for @appSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get appSettings;

  /// No description provided for @updateAvailableTitle.
  ///
  /// In en, this message translates to:
  /// **'New version available'**
  String get updateAvailableTitle;

  /// No description provided for @latestVersionLabel.
  ///
  /// In en, this message translates to:
  /// **'Latest version: v{version}'**
  String latestVersionLabel(String version);

  /// No description provided for @updateNotesLabel.
  ///
  /// In en, this message translates to:
  /// **'What\'s new:'**
  String get updateNotesLabel;

  /// No description provided for @laterButton.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get laterButton;

  /// No description provided for @downloadButton.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get downloadButton;

  /// No description provided for @anonymousChatTitle.
  ///
  /// In en, this message translates to:
  /// **'💬 Anonymous Chat'**
  String get anonymousChatTitle;

  /// No description provided for @anonymousChatSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Nearby rooms using Google Nearby or BLE + Hotspot automatically'**
  String get anonymousChatSubtitle;

  /// No description provided for @localTransferTitle.
  ///
  /// In en, this message translates to:
  /// **'Local Transfer'**
  String get localTransferTitle;

  /// No description provided for @localTransferSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Compatible with LocalSend for local file and text transfer'**
  String get localTransferSubtitle;

  /// No description provided for @readingTitle.
  ///
  /// In en, this message translates to:
  /// **'Reading'**
  String get readingTitle;

  /// No description provided for @readingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Reading tools have been merged into the tools page'**
  String get readingSubtitle;

  /// No description provided for @academicSearchTitle.
  ///
  /// In en, this message translates to:
  /// **'📎 Paper Search'**
  String get academicSearchTitle;

  /// No description provided for @academicSearchSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Search CrossRef and arXiv in parallel with BibTeX and PDF export support'**
  String get academicSearchSubtitle;

  /// No description provided for @apodCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Sky'**
  String get apodCardTitle;

  /// No description provided for @apodLoadingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Loading NASA Astronomy Picture of the Day...'**
  String get apodLoadingSubtitle;

  /// No description provided for @apodErrorSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Unable to load today\'s astronomy picture'**
  String get apodErrorSubtitle;

  /// No description provided for @apodUnavailableSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Today\'s APOD is not an image. Tap to view details.'**
  String get apodUnavailableSubtitle;

  /// No description provided for @apodRefreshTooltip.
  ///
  /// In en, this message translates to:
  /// **'Refresh astronomy picture'**
  String get apodRefreshTooltip;

  /// No description provided for @apodDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Sky'**
  String get apodDetailTitle;

  /// No description provided for @apodDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get apodDateLabel;

  /// No description provided for @apodAboutLabel.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get apodAboutLabel;

  /// No description provided for @apodNonImageNotice.
  ///
  /// In en, this message translates to:
  /// **'NASA APOD is not an image today. The original content may be a video or another media type.'**
  String get apodNonImageNotice;

  /// No description provided for @toolsPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get toolsPageTitle;

  /// No description provided for @toolsTabReading.
  ///
  /// In en, this message translates to:
  /// **'Reading'**
  String get toolsTabReading;

  /// No description provided for @toolsTabPdf.
  ///
  /// In en, this message translates to:
  /// **'PDF'**
  String get toolsTabPdf;

  /// No description provided for @toolsTabGueter.
  ///
  /// In en, this message translates to:
  /// **'GUETer'**
  String get toolsTabGueter;

  /// No description provided for @pickPdfOutputDirectory.
  ///
  /// In en, this message translates to:
  /// **'Choose PDF output directory'**
  String get pickPdfOutputDirectory;

  /// No description provided for @statusSelectTool.
  ///
  /// In en, this message translates to:
  /// **'Select a tool to start'**
  String get statusSelectTool;

  /// No description provided for @statusOutputDirChanged.
  ///
  /// In en, this message translates to:
  /// **'Output directory changed to: {path}'**
  String statusOutputDirChanged(String path);

  /// No description provided for @statusOutputDirReset.
  ///
  /// In en, this message translates to:
  /// **'Output directory reset to the default temp directory'**
  String get statusOutputDirReset;

  /// No description provided for @toolRunFailed.
  ///
  /// In en, this message translates to:
  /// **'Execution failed: {error}'**
  String toolRunFailed(String error);

  /// No description provided for @openFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Open failed: {message}'**
  String openFailedMessage(String message);

  /// No description provided for @pdfOutputShareText.
  ///
  /// In en, this message translates to:
  /// **'PDF tool output'**
  String get pdfOutputShareText;

  /// No description provided for @pdfToImagesTitle.
  ///
  /// In en, this message translates to:
  /// **'PDF to Images'**
  String get pdfToImagesTitle;

  /// No description provided for @pdfToImagesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Export as PNG'**
  String get pdfToImagesSubtitle;

  /// No description provided for @imagesToPdfTitle.
  ///
  /// In en, this message translates to:
  /// **'Images to PDF'**
  String get imagesToPdfTitle;

  /// No description provided for @imagesToPdfSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Merge images'**
  String get imagesToPdfSubtitle;

  /// No description provided for @compressPdfTitle.
  ///
  /// In en, this message translates to:
  /// **'Compress PDF'**
  String get compressPdfTitle;

  /// No description provided for @compressPdfSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Reduce size'**
  String get compressPdfSubtitle;

  /// No description provided for @extractPagesTitle.
  ///
  /// In en, this message translates to:
  /// **'Extract Pages'**
  String get extractPagesTitle;

  /// No description provided for @extractPagesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Extract by page number'**
  String get extractPagesSubtitle;

  /// No description provided for @watermarkTitle.
  ///
  /// In en, this message translates to:
  /// **'Watermark'**
  String get watermarkTitle;

  /// No description provided for @watermarkSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Anti-tampering'**
  String get watermarkSubtitle;

  /// No description provided for @extractPagesDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter page numbers'**
  String get extractPagesDialogTitle;

  /// No description provided for @extractPagesHint.
  ///
  /// In en, this message translates to:
  /// **'Example: 1,3,5-8 (total pages: {count})'**
  String extractPagesHint(int count);

  /// No description provided for @cancelButton.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelButton;

  /// No description provided for @confirmButton.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get confirmButton;

  /// No description provided for @pdfToImagesComplete.
  ///
  /// In en, this message translates to:
  /// **'PDF to images completed, exported {count} files'**
  String pdfToImagesComplete(int count);

  /// No description provided for @imagesToPdfComplete.
  ///
  /// In en, this message translates to:
  /// **'Images merged into PDF'**
  String get imagesToPdfComplete;

  /// No description provided for @compressPdfComplete.
  ///
  /// In en, this message translates to:
  /// **'PDF compression completed'**
  String get compressPdfComplete;

  /// No description provided for @extractPagesComplete.
  ///
  /// In en, this message translates to:
  /// **'PDF page extraction completed ({count} pages)'**
  String extractPagesComplete(int count);

  /// No description provided for @watermarkDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Watermark options'**
  String get watermarkDialogTitle;

  /// No description provided for @watermarkTextLabel.
  ///
  /// In en, this message translates to:
  /// **'Watermark text'**
  String get watermarkTextLabel;

  /// No description provided for @watermarkTextHint.
  ///
  /// In en, this message translates to:
  /// **'Example: Anti-tamper - Name - Date'**
  String get watermarkTextHint;

  /// No description provided for @watermarkOpacityLabel.
  ///
  /// In en, this message translates to:
  /// **'Opacity: {value}'**
  String watermarkOpacityLabel(String value);

  /// No description provided for @watermarkAngleLabel.
  ///
  /// In en, this message translates to:
  /// **'Rotation: {value}°'**
  String watermarkAngleLabel(String value);

  /// No description provided for @watermarkFontSizeLabel.
  ///
  /// In en, this message translates to:
  /// **'Font size: {value}'**
  String watermarkFontSizeLabel(String value);

  /// No description provided for @watermarkColorLabel.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get watermarkColorLabel;

  /// No description provided for @watermarkColorDeepRed.
  ///
  /// In en, this message translates to:
  /// **'Deep red'**
  String get watermarkColorDeepRed;

  /// No description provided for @watermarkColorDeepBlue.
  ///
  /// In en, this message translates to:
  /// **'Deep blue'**
  String get watermarkColorDeepBlue;

  /// No description provided for @watermarkColorDeepGray.
  ///
  /// In en, this message translates to:
  /// **'Deep gray'**
  String get watermarkColorDeepGray;

  /// No description provided for @watermarkColorBlack.
  ///
  /// In en, this message translates to:
  /// **'Black'**
  String get watermarkColorBlack;

  /// No description provided for @watermarkComplete.
  ///
  /// In en, this message translates to:
  /// **'PDF watermark completed'**
  String get watermarkComplete;

  /// No description provided for @pdfToolsTitle.
  ///
  /// In en, this message translates to:
  /// **'PDF Tools'**
  String get pdfToolsTitle;

  /// No description provided for @recentTasksTitle.
  ///
  /// In en, this message translates to:
  /// **'Recent tasks'**
  String get recentTasksTitle;

  /// No description provided for @recentTasksCount.
  ///
  /// In en, this message translates to:
  /// **'{count} records'**
  String recentTasksCount(int count);

  /// No description provided for @copyOutputPath.
  ///
  /// In en, this message translates to:
  /// **'Copy output path'**
  String get copyOutputPath;

  /// No description provided for @outputPathCopied.
  ///
  /// In en, this message translates to:
  /// **'Output path copied'**
  String get outputPathCopied;

  /// No description provided for @gueterToolsTitle.
  ///
  /// In en, this message translates to:
  /// **'GUETer Tools'**
  String get gueterToolsTitle;

  /// No description provided for @gueterToolsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Quick access to common GUET official entries'**
  String get gueterToolsSubtitle;

  /// No description provided for @guetEmailTitle.
  ///
  /// In en, this message translates to:
  /// **'GUET Mail'**
  String get guetEmailTitle;

  /// No description provided for @guetEmailSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Application entry'**
  String get guetEmailSubtitle;

  /// No description provided for @guetOfficialTitle.
  ///
  /// In en, this message translates to:
  /// **'GUET Official Site'**
  String get guetOfficialTitle;

  /// No description provided for @guetOfficialSubtitle.
  ///
  /// In en, this message translates to:
  /// **'School homepage'**
  String get guetOfficialSubtitle;

  /// No description provided for @aiFigureTitle.
  ///
  /// In en, this message translates to:
  /// **'AI Paper Figure Generator'**
  String get aiFigureTitle;

  /// No description provided for @aiFigureSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Describe the method and generate academic illustrations automatically'**
  String get aiFigureSubtitle;

  /// No description provided for @settingsAnnouncementTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings announcement'**
  String get settingsAnnouncementTitle;

  /// No description provided for @settingsAnnouncementContent.
  ///
  /// In en, this message translates to:
  /// **'Welcome to GUETer.\n\nThis project only provides local learning-assistant features and does not offer cloud account sync, password collection, or background upload services.\n\nAccounts, sessions, and related local records are encrypted and stored on device. They are not uploaded to this project\'s server, and your credentials are never proactively sent.\n\nThis announcement is versioned. If the terms are updated later, you will be reminded again.\n\nIf your school, platform provider, or rights holder believes any related feature is inappropriate, please contact us through a compliant channel.'**
  String get settingsAnnouncementContent;

  /// No description provided for @reviewLaterButton.
  ///
  /// In en, this message translates to:
  /// **'Review later'**
  String get reviewLaterButton;

  /// No description provided for @gotItButton.
  ///
  /// In en, this message translates to:
  /// **'Understood'**
  String get gotItButton;

  /// No description provided for @settingsSavedEmail.
  ///
  /// In en, this message translates to:
  /// **'Academic API email saved'**
  String get settingsSavedEmail;

  /// No description provided for @settingsClearedEmail.
  ///
  /// In en, this message translates to:
  /// **'Academic API email cleared'**
  String get settingsClearedEmail;

  /// No description provided for @languageLabel.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageLabel;

  /// No description provided for @languageChinese.
  ///
  /// In en, this message translates to:
  /// **'Simplified Chinese'**
  String get languageChinese;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageRestartHint.
  ///
  /// In en, this message translates to:
  /// **'Changes take effect after restarting the app'**
  String get languageRestartHint;

  /// No description provided for @languageSavedRestart.
  ///
  /// In en, this message translates to:
  /// **'Language saved. Restart the app to apply it.'**
  String get languageSavedRestart;

  /// No description provided for @themeAndAppearanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Appearance & Theme'**
  String get themeAndAppearanceTitle;

  /// No description provided for @themeAndAppearanceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Color schemes, style presets, and theme mode'**
  String get themeAndAppearanceSubtitle;

  /// No description provided for @themeModeLabel.
  ///
  /// In en, this message translates to:
  /// **'Theme mode'**
  String get themeModeLabel;

  /// No description provided for @themeModeSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow system'**
  String get themeModeSystem;

  /// No description provided for @themeModeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeModeLight;

  /// No description provided for @themeModeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark eye-care'**
  String get themeModeDark;

  /// No description provided for @themeStyleLabel.
  ///
  /// In en, this message translates to:
  /// **'Theme style'**
  String get themeStyleLabel;

  /// No description provided for @themeStyleModern.
  ///
  /// In en, this message translates to:
  /// **'Modern (recommended)'**
  String get themeStyleModern;

  /// No description provided for @themeStyleCompact.
  ///
  /// In en, this message translates to:
  /// **'Compact'**
  String get themeStyleCompact;

  /// No description provided for @themeStylePlayful.
  ///
  /// In en, this message translates to:
  /// **'Playful'**
  String get themeStylePlayful;

  /// No description provided for @themeStyleMinimal.
  ///
  /// In en, this message translates to:
  /// **'Minimal'**
  String get themeStyleMinimal;

  /// No description provided for @themeStyleBold.
  ///
  /// In en, this message translates to:
  /// **'Bold'**
  String get themeStyleBold;

  /// No description provided for @themeStyleSoft.
  ///
  /// In en, this message translates to:
  /// **'Soft'**
  String get themeStyleSoft;

  /// No description provided for @randomPaletteTitle.
  ///
  /// In en, this message translates to:
  /// **'Mystery palette'**
  String get randomPaletteTitle;

  /// No description provided for @randomPaletteSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Switch to a different global color palette randomly'**
  String get randomPaletteSubtitle;

  /// No description provided for @academicToolsTitle.
  ///
  /// In en, this message translates to:
  /// **'Academic Tools'**
  String get academicToolsTitle;

  /// No description provided for @academicToolsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'CrossRef mailto email and paper-search related settings'**
  String get academicToolsSubtitle;

  /// No description provided for @academicApiEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Academic API email'**
  String get academicApiEmailLabel;

  /// No description provided for @academicApiEmailHint.
  ///
  /// In en, this message translates to:
  /// **'Optional, used for the CrossRef mailto parameter'**
  String get academicApiEmailHint;

  /// No description provided for @academicApiEmailDescription.
  ///
  /// In en, this message translates to:
  /// **'CrossRef search works without it. If you provide one, requests will include the email to follow polite-usage guidance.'**
  String get academicApiEmailDescription;

  /// No description provided for @saveAcademicEmailTitle.
  ///
  /// In en, this message translates to:
  /// **'Save academic API email'**
  String get saveAcademicEmailTitle;

  /// No description provided for @currentEmailUnset.
  ///
  /// In en, this message translates to:
  /// **'No email configured'**
  String get currentEmailUnset;

  /// No description provided for @currentEmailValue.
  ///
  /// In en, this message translates to:
  /// **'Current email: {email}'**
  String currentEmailValue(String email);

  /// No description provided for @clearAcademicEmailTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear academic API email'**
  String get clearAcademicEmailTitle;

  /// No description provided for @clearAcademicEmailSubtitle.
  ///
  /// In en, this message translates to:
  /// **'CrossRef requests will no longer include the mailto parameter'**
  String get clearAcademicEmailSubtitle;

  /// No description provided for @diagnosticsToggleTitle.
  ///
  /// In en, this message translates to:
  /// **'Checks, diagnostics, and repair tools'**
  String get diagnosticsToggleTitle;

  /// No description provided for @diagnosticsToggleSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Disabled by default. Enable to use diagnostic tools.'**
  String get diagnosticsToggleSubtitle;

  /// No description provided for @diagnosticsTitle.
  ///
  /// In en, this message translates to:
  /// **'Checks, Diagnostics & Repair'**
  String get diagnosticsTitle;

  /// No description provided for @diagnosticsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Platform checks, report export, and one-click fixes'**
  String get diagnosticsSubtitle;

  /// No description provided for @checkPlatformsTitle.
  ///
  /// In en, this message translates to:
  /// **'Check connectivity for the four platforms'**
  String get checkPlatformsTitle;

  /// No description provided for @checkPlatformsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Chaoxing, Rain Classroom, TronClass, and Ketangpai'**
  String get checkPlatformsSubtitle;

  /// No description provided for @copyLastReportTooltip.
  ///
  /// In en, this message translates to:
  /// **'Copy last report'**
  String get copyLastReportTooltip;

  /// No description provided for @lastReportCopied.
  ///
  /// In en, this message translates to:
  /// **'Last report copied'**
  String get lastReportCopied;

  /// No description provided for @copyDiagnosticPackTitle.
  ///
  /// In en, this message translates to:
  /// **'Generate and copy diagnostic pack'**
  String get copyDiagnosticPackTitle;

  /// No description provided for @copyDiagnosticPackSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Includes settings snapshot, account counts, and permission states'**
  String get copyDiagnosticPackSubtitle;

  /// No description provided for @fixCommonIssuesTitle.
  ///
  /// In en, this message translates to:
  /// **'Fix common issues with one tap'**
  String get fixCommonIssuesTitle;

  /// No description provided for @fixCommonIssuesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Restore recommended strategies and default platform addresses'**
  String get fixCommonIssuesSubtitle;

  /// No description provided for @accountHealthTitle.
  ///
  /// In en, this message translates to:
  /// **'Account health check'**
  String get accountHealthTitle;

  /// No description provided for @accountHealthSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Check account availability across four platforms'**
  String get accountHealthSubtitle;

  /// No description provided for @batchPrecheckTitle.
  ///
  /// In en, this message translates to:
  /// **'Batch sign-in precheck'**
  String get batchPrecheckTitle;

  /// No description provided for @batchPrecheckSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Check whether accounts, permissions, and network are ready'**
  String get batchPrecheckSubtitle;

  /// No description provided for @signRecordsTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign-in record search'**
  String get signRecordsTitle;

  /// No description provided for @signRecordsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Filter by time/platform/course with copy and share support'**
  String get signRecordsSubtitle;

  /// No description provided for @requestConsoleTitle.
  ///
  /// In en, this message translates to:
  /// **'Request console'**
  String get requestConsoleTitle;

  /// No description provided for @requestConsoleSubtitle.
  ///
  /// In en, this message translates to:
  /// **'View recent request results, retries, and error logs'**
  String get requestConsoleSubtitle;

  /// No description provided for @securityAndPacingTitle.
  ///
  /// In en, this message translates to:
  /// **'Security & Request Pacing'**
  String get securityAndPacingTitle;

  /// No description provided for @securityAndPacingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Control request security level'**
  String get securityAndPacingSubtitle;

  /// No description provided for @strictSecurityModeTitle.
  ///
  /// In en, this message translates to:
  /// **'Strict security mode'**
  String get strictSecurityModeTitle;

  /// No description provided for @strictSecurityModeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enable this if you think requests may be too frequent'**
  String get strictSecurityModeSubtitle;

  /// No description provided for @securityLevelLabel.
  ///
  /// In en, this message translates to:
  /// **'Request security level:'**
  String get securityLevelLabel;

  /// No description provided for @securityLevelStrict.
  ///
  /// In en, this message translates to:
  /// **'Strict'**
  String get securityLevelStrict;

  /// No description provided for @securityLevelStandard.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get securityLevelStandard;

  /// No description provided for @securityModeStrictDescription.
  ///
  /// In en, this message translates to:
  /// **'Current mode: strict security mode (sign-in requests are additionally throttled)'**
  String get securityModeStrictDescription;

  /// No description provided for @securityModeStandardDescription.
  ///
  /// In en, this message translates to:
  /// **'Current mode: standard (default)'**
  String get securityModeStandardDescription;

  /// No description provided for @beginnerGuideCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Beginner Guide'**
  String get beginnerGuideCardTitle;

  /// No description provided for @beginnerGuideCardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'First-use tips and common troubleshooting advice'**
  String get beginnerGuideCardSubtitle;

  /// No description provided for @viewGuideButton.
  ///
  /// In en, this message translates to:
  /// **'View guide'**
  String get viewGuideButton;

  /// No description provided for @beginnerGuideDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Beginner Guide (can be disabled)'**
  String get beginnerGuideDialogTitle;

  /// No description provided for @beginnerGuideDialogContent.
  ///
  /// In en, this message translates to:
  /// **'1. Select a platform before logging in. Accounts on different platforms are independent.\n\n2. For TronClass, \"System browser first + session reuse first\" is recommended.\n\n3. Run the batch sign-in precheck once before signing in.\n\n4. If something goes wrong, try \"Fix common issues\" first, then generate a diagnostic pack for feedback.'**
  String get beginnerGuideDialogContent;

  /// No description provided for @quickActionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Quick actions'**
  String get quickActionsTitle;

  /// No description provided for @quickActionPlatformCheck.
  ///
  /// In en, this message translates to:
  /// **'Platform check'**
  String get quickActionPlatformCheck;

  /// No description provided for @quickActionFix.
  ///
  /// In en, this message translates to:
  /// **'Quick fix'**
  String get quickActionFix;

  /// No description provided for @quickActionRandomPalette.
  ///
  /// In en, this message translates to:
  /// **'Random palette'**
  String get quickActionRandomPalette;

  /// No description provided for @disclaimerCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Disclaimer (please read first)'**
  String get disclaimerCardTitle;

  /// No description provided for @disclaimerCardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Locally encrypted storage, never uploaded to a server'**
  String get disclaimerCardSubtitle;

  /// No description provided for @disclaimerDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Disclaimer'**
  String get disclaimerDialogTitle;

  /// No description provided for @disclaimerDialogSummary.
  ///
  /// In en, this message translates to:
  /// **'Summary: this project does not collect passwords or provide cloud sync. Account data is only encrypted and stored on your device.'**
  String get disclaimerDialogSummary;

  /// No description provided for @disclaimerDialogContent.
  ///
  /// In en, this message translates to:
  /// **'Disclaimer (please read first)\n\n1. This app is for learning exchange and technical research only and must not be used for any illegal or non-compliant purpose.\n\n2. This app has no official partnership with platforms such as Chaoxing, Rain Classroom, TronClass, Ketangpai, or Weizhujiao, nor with their affiliated institutions.\n\n3. Users must ensure they are legally authorized to use the relevant platform account and course. Any account risk, data loss, or other consequences caused by personal operation are the user\'s own responsibility.\n\n4. This app does not provide cloud account sync, password collection, or background upload services. Accounts, sessions, and related local records are encrypted and stored on device. They are not uploaded to this project\'s server, and your credentials are never proactively sent.\n\n5. This app does not guarantee continuous availability and is not responsible for issues caused by network fluctuations, platform policy changes, API changes, or device compatibility issues.\n\n6. If your school, platform provider, or rights holder believes any related feature or displayed content is inappropriate, please contact us in time.\n\nFor infringement concerns, contact: 3177401522a@gmai.com'**
  String get disclaimerDialogContent;

  /// No description provided for @copyFullTextButton.
  ///
  /// In en, this message translates to:
  /// **'Copy full text'**
  String get copyFullTextButton;

  /// No description provided for @disclaimerCopied.
  ///
  /// In en, this message translates to:
  /// **'Disclaimer copied'**
  String get disclaimerCopied;

  /// No description provided for @themePaletteLabel.
  ///
  /// In en, this message translates to:
  /// **'Color palette'**
  String get themePaletteLabel;

  /// No description provided for @themePaletteLongPress.
  ///
  /// In en, this message translates to:
  /// **'Long press to switch'**
  String get themePaletteLongPress;

  /// No description provided for @themeModeStatLabel.
  ///
  /// In en, this message translates to:
  /// **'Theme mode'**
  String get themeModeStatLabel;

  /// No description provided for @themeModeSwitched.
  ///
  /// In en, this message translates to:
  /// **'Switched to {mode} mode'**
  String themeModeSwitched(String mode);

  /// No description provided for @colorSchemeSwitched.
  ///
  /// In en, this message translates to:
  /// **'Switched palette: {name}'**
  String colorSchemeSwitched(String name);

  /// No description provided for @randomPaletteSwitched.
  ///
  /// In en, this message translates to:
  /// **'Mystery palette switched to: {name}'**
  String randomPaletteSwitched(String name);

  /// No description provided for @colorSchemeAqua.
  ///
  /// In en, this message translates to:
  /// **'Aqua'**
  String get colorSchemeAqua;

  /// No description provided for @colorSchemeOcean.
  ///
  /// In en, this message translates to:
  /// **'Ocean Blue'**
  String get colorSchemeOcean;

  /// No description provided for @colorSchemeForest.
  ///
  /// In en, this message translates to:
  /// **'Forest Green'**
  String get colorSchemeForest;

  /// No description provided for @colorSchemeAmber.
  ///
  /// In en, this message translates to:
  /// **'Amber'**
  String get colorSchemeAmber;

  /// No description provided for @colorSchemeNight.
  ///
  /// In en, this message translates to:
  /// **'Night Care'**
  String get colorSchemeNight;

  /// No description provided for @colorSchemeRose.
  ///
  /// In en, this message translates to:
  /// **'Warm Rose'**
  String get colorSchemeRose;

  /// No description provided for @colorSchemePurple.
  ///
  /// In en, this message translates to:
  /// **'Violet'**
  String get colorSchemePurple;

  /// No description provided for @colorSchemeCyan.
  ///
  /// In en, this message translates to:
  /// **'Cyan'**
  String get colorSchemeCyan;

  /// No description provided for @colorSchemeOrange.
  ///
  /// In en, this message translates to:
  /// **'Energy Orange'**
  String get colorSchemeOrange;

  /// No description provided for @autoCloseWebLoginTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto return after web login succeeds'**
  String get autoCloseWebLoginTitle;

  /// No description provided for @autoCloseWebLoginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Close the page automatically after TronClass web login obtains a session'**
  String get autoCloseWebLoginSubtitle;

  /// No description provided for @batchPrecheckResultTitle.
  ///
  /// In en, this message translates to:
  /// **'Batch sign-in precheck result'**
  String get batchPrecheckResultTitle;

  /// No description provided for @copyReportButton.
  ///
  /// In en, this message translates to:
  /// **'Copy report'**
  String get copyReportButton;

  /// No description provided for @closeButton.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get closeButton;

  /// No description provided for @precheckReportCopied.
  ///
  /// In en, this message translates to:
  /// **'Precheck report copied'**
  String get precheckReportCopied;

  /// No description provided for @copyButton.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copyButton;

  /// No description provided for @passwordCopied.
  ///
  /// In en, this message translates to:
  /// **'Password copied to clipboard'**
  String get passwordCopied;

  /// No description provided for @computerHelpTitle.
  ///
  /// In en, this message translates to:
  /// **'Computer Quick Manual'**
  String get computerHelpTitle;

  /// No description provided for @computerHelpSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Offline step cards for common Windows and Android tasks'**
  String get computerHelpSubtitle;

  /// No description provided for @computerHelpPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Computer Quick Manual'**
  String get computerHelpPageTitle;

  /// No description provided for @computerHelpSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by problem title or keyword'**
  String get computerHelpSearchHint;

  /// No description provided for @computerHelpAllCategories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get computerHelpAllCategories;

  /// No description provided for @computerHelpAllPlatforms.
  ///
  /// In en, this message translates to:
  /// **'Platforms'**
  String get computerHelpAllPlatforms;

  /// No description provided for @computerHelpPlatformBoth.
  ///
  /// In en, this message translates to:
  /// **'Windows + Android'**
  String get computerHelpPlatformBoth;

  /// No description provided for @computerHelpPlatformWindows.
  ///
  /// In en, this message translates to:
  /// **'Windows'**
  String get computerHelpPlatformWindows;

  /// No description provided for @computerHelpPlatformAndroid.
  ///
  /// In en, this message translates to:
  /// **'Android'**
  String get computerHelpPlatformAndroid;

  /// No description provided for @computerHelpDiagnosisLabel.
  ///
  /// In en, this message translates to:
  /// **'When to use'**
  String get computerHelpDiagnosisLabel;

  /// No description provided for @computerHelpStepsLabel.
  ///
  /// In en, this message translates to:
  /// **'Steps'**
  String get computerHelpStepsLabel;

  /// No description provided for @computerHelpTipsLabel.
  ///
  /// In en, this message translates to:
  /// **'Common mistakes and tips'**
  String get computerHelpTipsLabel;

  /// No description provided for @computerHelpKeywordsLabel.
  ///
  /// In en, this message translates to:
  /// **'Keywords'**
  String get computerHelpKeywordsLabel;

  /// No description provided for @computerHelpCopySteps.
  ///
  /// In en, this message translates to:
  /// **'Copy steps'**
  String get computerHelpCopySteps;

  /// No description provided for @computerHelpCopyKeywords.
  ///
  /// In en, this message translates to:
  /// **'Copy keywords'**
  String get computerHelpCopyKeywords;

  /// No description provided for @computerHelpCopiedSteps.
  ///
  /// In en, this message translates to:
  /// **'Steps copied'**
  String get computerHelpCopiedSteps;

  /// No description provided for @computerHelpCopiedKeywords.
  ///
  /// In en, this message translates to:
  /// **'Keywords copied'**
  String get computerHelpCopiedKeywords;

  /// No description provided for @computerHelpEmptyState.
  ///
  /// In en, this message translates to:
  /// **'No matching quick-help topic yet'**
  String get computerHelpEmptyState;

  /// No description provided for @computerHelpViewDetails.
  ///
  /// In en, this message translates to:
  /// **'View steps'**
  String get computerHelpViewDetails;

  /// No description provided for @computerHelpCategoryFileTransfer.
  ///
  /// In en, this message translates to:
  /// **'File transfer'**
  String get computerHelpCategoryFileTransfer;

  /// No description provided for @computerHelpCategoryArchives.
  ///
  /// In en, this message translates to:
  /// **'Archives'**
  String get computerHelpCategoryArchives;

  /// No description provided for @computerHelpCategoryFileBasics.
  ///
  /// In en, this message translates to:
  /// **'File names'**
  String get computerHelpCategoryFileBasics;

  /// No description provided for @computerHelpCategoryPdf.
  ///
  /// In en, this message translates to:
  /// **'PDF'**
  String get computerHelpCategoryPdf;

  /// No description provided for @computerHelpCategoryCaptureProjection.
  ///
  /// In en, this message translates to:
  /// **'Capture & casting'**
  String get computerHelpCategoryCaptureProjection;

  /// No description provided for @computerHelpCategorySoftwareInstall.
  ///
  /// In en, this message translates to:
  /// **'Software install'**
  String get computerHelpCategorySoftwareInstall;

  /// No description provided for @computerHelpCategoryDownloads.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get computerHelpCategoryDownloads;

  /// No description provided for @computerHelpCategoryDeviceConnection.
  ///
  /// In en, this message translates to:
  /// **'USB / Bluetooth / WeChat'**
  String get computerHelpCategoryDeviceConnection;

  /// No description provided for @computerHelpCategoryNetworkBlock.
  ///
  /// In en, this message translates to:
  /// **'Blocked downloads'**
  String get computerHelpCategoryNetworkBlock;
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
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
