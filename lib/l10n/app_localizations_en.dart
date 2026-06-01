// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appCourses => 'Courses';

  @override
  String get appAccounts => 'Accounts';

  @override
  String get appTodos => 'Todos';

  @override
  String get appTools => 'Tools';

  @override
  String get appSettings => 'Settings';

  @override
  String get updateAvailableTitle => 'New version available';

  @override
  String latestVersionLabel(String version) {
    return 'Latest version: v$version';
  }

  @override
  String get updateNotesLabel => 'What\'s new:';

  @override
  String get laterButton => 'Later';

  @override
  String get downloadButton => 'Download';

  @override
  String get anonymousChatTitle => '💬 Anonymous Chat';

  @override
  String get anonymousChatSubtitle =>
      'Nearby anonymous chat and file sharing powered by Nearby Connections';

  @override
  String get localTransferTitle => 'Local Transfer';

  @override
  String get localTransferSubtitle =>
      'Compatible with LocalSend for local file and text transfer';

  @override
  String get readingTitle => 'Reading';

  @override
  String get readingSubtitle =>
      'Reading tools have been merged into the tools page';

  @override
  String get academicSearchTitle => '📎 Paper Search';

  @override
  String get academicSearchSubtitle =>
      'Search CrossRef and arXiv in parallel with BibTeX and PDF export support';

  @override
  String get apodCardTitle => 'Today\'s Sky';

  @override
  String get apodLoadingSubtitle =>
      'Loading NASA Astronomy Picture of the Day...';

  @override
  String get apodErrorSubtitle => 'Unable to load today\'s astronomy picture';

  @override
  String get apodUnavailableSubtitle =>
      'Today\'s APOD is not an image. Tap to view details.';

  @override
  String get apodRefreshTooltip => 'Refresh astronomy picture';

  @override
  String get apodDetailTitle => 'Today\'s Sky';

  @override
  String get apodDateLabel => 'Date';

  @override
  String get apodAboutLabel => 'About';

  @override
  String get apodNonImageNotice =>
      'NASA APOD is not an image today. The original content may be a video or another media type.';

  @override
  String get toolsPageTitle => 'Tools';

  @override
  String get toolsTabReading => 'Reading';

  @override
  String get toolsTabPdf => 'PDF';

  @override
  String get toolsTabGueter => 'GUETer';

  @override
  String get pickPdfOutputDirectory => 'Choose PDF output directory';

  @override
  String get statusSelectTool => 'Select a tool to start';

  @override
  String statusOutputDirChanged(String path) {
    return 'Output directory changed to: $path';
  }

  @override
  String get statusOutputDirReset =>
      'Output directory reset to the default temp directory';

  @override
  String toolRunFailed(String error) {
    return 'Execution failed: $error';
  }

  @override
  String openFailedMessage(String message) {
    return 'Open failed: $message';
  }

  @override
  String get pdfOutputShareText => 'PDF tool output';

  @override
  String get pdfToImagesTitle => 'PDF to Images';

  @override
  String get pdfToImagesSubtitle => 'Export as PNG';

  @override
  String get imagesToPdfTitle => 'Images to PDF';

  @override
  String get imagesToPdfSubtitle => 'Merge images';

  @override
  String get compressPdfTitle => 'Compress PDF';

  @override
  String get compressPdfSubtitle => 'Reduce size';

  @override
  String get extractPagesTitle => 'Extract Pages';

  @override
  String get extractPagesSubtitle => 'Extract by page number';

  @override
  String get watermarkTitle => 'Watermark';

  @override
  String get watermarkSubtitle => 'Anti-tampering';

  @override
  String get extractPagesDialogTitle => 'Enter page numbers';

  @override
  String extractPagesHint(int count) {
    return 'Example: 1,3,5-8 (total pages: $count)';
  }

  @override
  String get cancelButton => 'Cancel';

  @override
  String get confirmButton => 'OK';

  @override
  String pdfToImagesComplete(int count) {
    return 'PDF to images completed, exported $count files';
  }

  @override
  String get imagesToPdfComplete => 'Images merged into PDF';

  @override
  String get compressPdfComplete => 'PDF compression completed';

  @override
  String extractPagesComplete(int count) {
    return 'PDF page extraction completed ($count pages)';
  }

  @override
  String get watermarkDialogTitle => 'Watermark options';

  @override
  String get watermarkTextLabel => 'Watermark text';

  @override
  String get watermarkTextHint => 'Example: Anti-tamper - Name - Date';

  @override
  String watermarkOpacityLabel(String value) {
    return 'Opacity: $value';
  }

  @override
  String watermarkAngleLabel(String value) {
    return 'Rotation: $value°';
  }

  @override
  String watermarkFontSizeLabel(String value) {
    return 'Font size: $value';
  }

  @override
  String get watermarkColorLabel => 'Color';

  @override
  String get watermarkColorDeepRed => 'Deep red';

  @override
  String get watermarkColorDeepBlue => 'Deep blue';

  @override
  String get watermarkColorDeepGray => 'Deep gray';

  @override
  String get watermarkColorBlack => 'Black';

  @override
  String get watermarkComplete => 'PDF watermark completed';

  @override
  String get pdfToolsTitle => 'PDF Tools';

  @override
  String get recentTasksTitle => 'Recent tasks';

  @override
  String recentTasksCount(int count) {
    return '$count records';
  }

  @override
  String get copyOutputPath => 'Copy output path';

  @override
  String get outputPathCopied => 'Output path copied';

  @override
  String get gueterToolsTitle => 'GUETer Tools';

  @override
  String get gueterToolsSubtitle =>
      'Quick access to common GUET official entries';

  @override
  String get guetEmailTitle => 'GUET Mail';

  @override
  String get guetEmailSubtitle => 'Application entry';

  @override
  String get guetOfficialTitle => 'GUET Official Site';

  @override
  String get guetOfficialSubtitle => 'School homepage';

  @override
  String get aiFigureTitle => 'AI Paper Figure Generator';

  @override
  String get aiFigureSubtitle =>
      'Describe the method and generate academic illustrations automatically';

  @override
  String get settingsAnnouncementTitle => 'Settings announcement';

  @override
  String get settingsAnnouncementContent =>
      'Welcome to GUETer.\n\nThis project only provides local learning-assistant features and does not offer cloud account sync, password collection, or background upload services.\n\nAccounts, sessions, and related local records are encrypted and stored on device. They are not uploaded to this project\'s server, and your credentials are never proactively sent.\n\nThis announcement is versioned. If the terms are updated later, you will be reminded again.\n\nIf your school, platform provider, or rights holder believes any related feature is inappropriate, please contact us through a compliant channel.';

  @override
  String get reviewLaterButton => 'Review later';

  @override
  String get gotItButton => 'Understood';

  @override
  String get settingsSavedEmail => 'Academic API email saved';

  @override
  String get settingsClearedEmail => 'Academic API email cleared';

  @override
  String get languageLabel => 'Language';

  @override
  String get languageChinese => 'Simplified Chinese';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageRestartHint =>
      'Changes take effect after restarting the app';

  @override
  String get languageSavedRestart =>
      'Language saved. Restart the app to apply it.';

  @override
  String get themeAndAppearanceTitle => 'Appearance & Theme';

  @override
  String get themeAndAppearanceSubtitle =>
      'Color schemes, style presets, and theme mode';

  @override
  String get themeModeLabel => 'Theme mode';

  @override
  String get themeModeSystem => 'Follow system';

  @override
  String get themeModeLight => 'Light';

  @override
  String get themeModeDark => 'Dark eye-care';

  @override
  String get themeStyleLabel => 'Theme style';

  @override
  String get themeStyleModern => 'Modern (recommended)';

  @override
  String get themeStyleCompact => 'Compact';

  @override
  String get themeStylePlayful => 'Playful';

  @override
  String get themeStyleMinimal => 'Minimal';

  @override
  String get themeStyleBold => 'Bold';

  @override
  String get themeStyleSoft => 'Soft';

  @override
  String get randomPaletteTitle => 'Mystery palette';

  @override
  String get randomPaletteSubtitle =>
      'Switch to a different global color palette randomly';

  @override
  String get academicToolsTitle => 'Academic Tools';

  @override
  String get academicToolsSubtitle =>
      'CrossRef mailto email and paper-search related settings';

  @override
  String get academicApiEmailLabel => 'Academic API email';

  @override
  String get academicApiEmailHint =>
      'Optional, used for the CrossRef mailto parameter';

  @override
  String get academicApiEmailDescription =>
      'CrossRef search works without it. If you provide one, requests will include the email to follow polite-usage guidance.';

  @override
  String get saveAcademicEmailTitle => 'Save academic API email';

  @override
  String get currentEmailUnset => 'No email configured';

  @override
  String currentEmailValue(String email) {
    return 'Current email: $email';
  }

  @override
  String get clearAcademicEmailTitle => 'Clear academic API email';

  @override
  String get clearAcademicEmailSubtitle =>
      'CrossRef requests will no longer include the mailto parameter';

  @override
  String get diagnosticsToggleTitle => 'Checks, diagnostics, and repair tools';

  @override
  String get diagnosticsToggleSubtitle =>
      'Disabled by default. Enable to use diagnostic tools.';

  @override
  String get diagnosticsTitle => 'Checks, Diagnostics & Repair';

  @override
  String get diagnosticsSubtitle =>
      'Platform checks, report export, and one-click fixes';

  @override
  String get checkPlatformsTitle => 'Check connectivity for the four platforms';

  @override
  String get checkPlatformsSubtitle =>
      'Chaoxing, Rain Classroom, TronClass, and Ketangpai';

  @override
  String get copyLastReportTooltip => 'Copy last report';

  @override
  String get lastReportCopied => 'Last report copied';

  @override
  String get copyDiagnosticPackTitle => 'Generate and copy diagnostic pack';

  @override
  String get copyDiagnosticPackSubtitle =>
      'Includes settings snapshot, account counts, and permission states';

  @override
  String get fixCommonIssuesTitle => 'Fix common issues with one tap';

  @override
  String get fixCommonIssuesSubtitle =>
      'Restore recommended strategies and default platform addresses';

  @override
  String get accountHealthTitle => 'Account health check';

  @override
  String get accountHealthSubtitle =>
      'Check account availability across four platforms';

  @override
  String get batchPrecheckTitle => 'Batch sign-in precheck';

  @override
  String get batchPrecheckSubtitle =>
      'Check whether accounts, permissions, and network are ready';

  @override
  String get signRecordsTitle => 'Sign-in record search';

  @override
  String get signRecordsSubtitle =>
      'Filter by time/platform/course with copy and share support';

  @override
  String get requestConsoleTitle => 'Request console';

  @override
  String get requestConsoleSubtitle =>
      'View recent request results, retries, and error logs';

  @override
  String get securityAndPacingTitle => 'Security & Request Pacing';

  @override
  String get securityAndPacingSubtitle => 'Control request security level';

  @override
  String get strictSecurityModeTitle => 'Strict security mode';

  @override
  String get strictSecurityModeSubtitle =>
      'Enable this if you think requests may be too frequent';

  @override
  String get securityLevelLabel => 'Request security level:';

  @override
  String get securityLevelStrict => 'Strict';

  @override
  String get securityLevelStandard => 'Standard';

  @override
  String get securityModeStrictDescription =>
      'Current mode: strict security mode (sign-in requests are additionally throttled)';

  @override
  String get securityModeStandardDescription =>
      'Current mode: standard (default)';

  @override
  String get beginnerGuideCardTitle => 'Beginner Guide';

  @override
  String get beginnerGuideCardSubtitle =>
      'First-use tips and common troubleshooting advice';

  @override
  String get viewGuideButton => 'View guide';

  @override
  String get beginnerGuideDialogTitle => 'Beginner Guide (can be disabled)';

  @override
  String get beginnerGuideDialogContent =>
      '1. Select a platform before logging in. Accounts on different platforms are independent.\n\n2. For TronClass, \"System browser first + session reuse first\" is recommended.\n\n3. Run the batch sign-in precheck once before signing in.\n\n4. If something goes wrong, try \"Fix common issues\" first, then generate a diagnostic pack for feedback.';

  @override
  String get quickActionsTitle => 'Quick actions';

  @override
  String get quickActionPlatformCheck => 'Platform check';

  @override
  String get quickActionFix => 'Quick fix';

  @override
  String get quickActionRandomPalette => 'Random palette';

  @override
  String get disclaimerCardTitle => 'Disclaimer (please read first)';

  @override
  String get disclaimerCardSubtitle =>
      'Locally encrypted storage, never uploaded to a server';

  @override
  String get disclaimerDialogTitle => 'Disclaimer';

  @override
  String get disclaimerDialogSummary =>
      'Summary: this project does not collect passwords or provide cloud sync. Account data is only encrypted and stored on your device.';

  @override
  String get disclaimerDialogContent =>
      'Disclaimer (please read first)\n\n1. This app is for learning exchange and technical research only and must not be used for any illegal or non-compliant purpose.\n\n2. This app has no official partnership with platforms such as Chaoxing, Rain Classroom, TronClass, Ketangpai, or Weizhujiao, nor with their affiliated institutions.\n\n3. Users must ensure they are legally authorized to use the relevant platform account and course. Any account risk, data loss, or other consequences caused by personal operation are the user\'s own responsibility.\n\n4. This app does not provide cloud account sync, password collection, or background upload services. Accounts, sessions, and related local records are encrypted and stored on device. They are not uploaded to this project\'s server, and your credentials are never proactively sent.\n\n5. This app does not guarantee continuous availability and is not responsible for issues caused by network fluctuations, platform policy changes, API changes, or device compatibility issues.\n\n6. If your school, platform provider, or rights holder believes any related feature or displayed content is inappropriate, please contact us in time.\n\nFor infringement concerns, contact: 3177401522a@gmai.com';

  @override
  String get copyFullTextButton => 'Copy full text';

  @override
  String get disclaimerCopied => 'Disclaimer copied';

  @override
  String get themePaletteLabel => 'Color palette';

  @override
  String get themePaletteLongPress => 'Long press to switch';

  @override
  String get themeModeStatLabel => 'Theme mode';

  @override
  String themeModeSwitched(String mode) {
    return 'Switched to $mode mode';
  }

  @override
  String colorSchemeSwitched(String name) {
    return 'Switched palette: $name';
  }

  @override
  String randomPaletteSwitched(String name) {
    return 'Mystery palette switched to: $name';
  }

  @override
  String get colorSchemeAqua => 'Aqua';

  @override
  String get colorSchemeOcean => 'Ocean Blue';

  @override
  String get colorSchemeForest => 'Forest Green';

  @override
  String get colorSchemeAmber => 'Amber';

  @override
  String get colorSchemeNight => 'Night Care';

  @override
  String get colorSchemeRose => 'Warm Rose';

  @override
  String get colorSchemePurple => 'Violet';

  @override
  String get colorSchemeCyan => 'Cyan';

  @override
  String get colorSchemeOrange => 'Energy Orange';

  @override
  String get autoCloseWebLoginTitle => 'Auto return after web login succeeds';

  @override
  String get autoCloseWebLoginSubtitle =>
      'Close the page automatically after TronClass web login obtains a session';

  @override
  String get batchPrecheckResultTitle => 'Batch sign-in precheck result';

  @override
  String get copyReportButton => 'Copy report';

  @override
  String get closeButton => 'Close';

  @override
  String get precheckReportCopied => 'Precheck report copied';

  @override
  String get copyButton => 'Copy';

  @override
  String get passwordCopied => 'Password copied to clipboard';

  @override
  String get computerHelpTitle => 'Computer Quick Manual';

  @override
  String get computerHelpSubtitle =>
      'Offline step cards for common Windows and Android tasks';

  @override
  String get computerHelpPageTitle => 'Computer Quick Manual';

  @override
  String get computerHelpSearchHint => 'Search by problem title or keyword';

  @override
  String get computerHelpAllCategories => 'Categories';

  @override
  String get computerHelpAllPlatforms => 'Platforms';

  @override
  String get computerHelpPlatformBoth => 'Windows + Android';

  @override
  String get computerHelpPlatformWindows => 'Windows';

  @override
  String get computerHelpPlatformAndroid => 'Android';

  @override
  String get computerHelpDiagnosisLabel => 'When to use';

  @override
  String get computerHelpStepsLabel => 'Steps';

  @override
  String get computerHelpTipsLabel => 'Common mistakes and tips';

  @override
  String get computerHelpKeywordsLabel => 'Keywords';

  @override
  String get computerHelpCopySteps => 'Copy steps';

  @override
  String get computerHelpCopyKeywords => 'Copy keywords';

  @override
  String get computerHelpCopiedSteps => 'Steps copied';

  @override
  String get computerHelpCopiedKeywords => 'Keywords copied';

  @override
  String get computerHelpEmptyState => 'No matching quick-help topic yet';

  @override
  String get computerHelpViewDetails => 'View steps';

  @override
  String get computerHelpCategoryFileTransfer => 'File transfer';

  @override
  String get computerHelpCategoryArchives => 'Archives';

  @override
  String get computerHelpCategoryFileBasics => 'File names';

  @override
  String get computerHelpCategoryPdf => 'PDF';

  @override
  String get computerHelpCategoryCaptureProjection => 'Capture & casting';

  @override
  String get computerHelpCategorySoftwareInstall => 'Software install';

  @override
  String get computerHelpCategoryDownloads => 'Downloads';

  @override
  String get computerHelpCategoryDeviceConnection => 'USB / Bluetooth / WeChat';

  @override
  String get computerHelpCategoryNetworkBlock => 'Blocked downloads';
}
