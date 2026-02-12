import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:xml/xml.dart' as xml;

// =============================================================================
// ENUMS
// =============================================================================

/// Enum to specify the Linux store type.
///
/// Used to determine which Linux app store to check for updates:
/// - [snap]: Snap Store (snapcraft.io)
/// - [flathub]: Flathub (flathub.org)
enum LinuxStoreType {
  /// Snap Store - Ubuntu's default package format
  snap,

  /// Flathub - Cross-distribution Flatpak repository
  flathub,
}

/// Enum to specify the update dialog style.
///
/// Each style provides a platform-native look and feel:
/// - [adaptive]: Automatically selects the best style based on the current platform
/// - [material]: Material Design 3 style (Android)
/// - [cupertino]: Apple's design language (iOS/macOS)
/// - [fluent]: Microsoft's Fluent Design (Windows)
/// - [adwaita]: GNOME's Adwaita design (Linux)
enum UpdateDialogStyle {
  /// Adaptive style based on platform - automatically selects the appropriate
  /// style for the current platform
  adaptive,

  /// Material Design 3 style (Android-like) with rounded corners and elevation
  material,

  /// Cupertino style (iOS/macOS-like) with Apple's native dialog appearance
  cupertino,

  /// Fluent Design style (Windows-like) with Microsoft's modern UI patterns
  fluent,

  /// GNOME/Adwaita style (Linux-like) with GTK-inspired design
  adwaita,
}

/// Enum to specify the urgency level of an update.
///
/// Use urgency levels to communicate the importance of updates to users:
/// - [low]: Minor updates, bug fixes, or small improvements
/// - [medium]: Regular feature updates or moderate improvements
/// - [high]: Important updates with significant features or fixes
/// - [critical]: Security patches or breaking changes that require immediate action
enum UpdateUrgency {
  /// Low priority - minor improvements, can be skipped
  low,

  /// Medium priority - regular updates with new features
  medium,

  /// High priority - important updates, strongly recommended
  high,

  /// Critical priority - security fixes or breaking changes, should not be skipped
  critical,
}

/// Enum to specify the type of Android in-app update.
///
/// Android's Play Core library supports two update flows:
/// - [flexible]: Downloads in background, user can continue using the app
/// - [immediate]: Full-screen update that blocks app usage until complete
enum AndroidUpdateType {
  /// Flexible update - downloads in background while user continues using app
  flexible,

  /// Immediate update - full-screen blocking update experience
  immediate,
}

// =============================================================================
// DATA CLASSES
// =============================================================================

/// Result of version check containing version info, update URL, and metadata.
///
/// This class encapsulates all information about an available update:
/// ```dart
/// final updateInfo = await appUpdater.checkForUpdate();
/// if (updateInfo.updateAvailable) {
///   print('New version: ${updateInfo.latestVersion}');
///   print('Release notes: ${updateInfo.releaseNotes}');
/// }
/// ```
class UpdateInfo {
  /// The current installed version of the app
  final String currentVersion;

  /// The latest available version from the store/endpoint (null if check failed)
  final String? latestVersion;

  /// The URL to update/download the app (null if not available)
  final String? updateUrl;

  /// Whether an update is available
  final bool updateAvailable;

  /// Release notes or changelog for the new version (if available)
  final String? releaseNotes;

  /// The urgency level of the update
  final UpdateUrgency urgency;

  /// Minimum required version - if current version is below this, force update
  final String? minimumVersion;

  /// Whether this update is mandatory (cannot be skipped)
  final bool isMandatory;

  /// Release date of the new version (if available)
  final DateTime? releaseDate;

  /// Size of the update in bytes (if available)
  final int? updateSizeBytes;

  /// Creates an UpdateInfo instance with version and update details.
  UpdateInfo({
    required this.currentVersion,
    this.latestVersion,
    this.updateUrl,
    required this.updateAvailable,
    this.releaseNotes,
    this.urgency = UpdateUrgency.medium,
    this.minimumVersion,
    this.isMandatory = false,
    this.releaseDate,
    this.updateSizeBytes,
  });

  /// Returns true if the current version is below the minimum required version.
  ///
  /// This indicates a forced update is required regardless of user preferences.
  bool get requiresForceUpdate {
    if (minimumVersion == null) return isMandatory;
    return _isNewerVersion(currentVersion, minimumVersion!);
  }

  /// Formatted update size string (e.g., "15.2 MB")
  String? get formattedUpdateSize {
    if (updateSizeBytes == null) return null;
    if (updateSizeBytes! < 1024) return '$updateSizeBytes B';
    if (updateSizeBytes! < 1024 * 1024) {
      return '${(updateSizeBytes! / 1024).toStringAsFixed(1)} KB';
    }
    if (updateSizeBytes! < 1024 * 1024 * 1024) {
      return '${(updateSizeBytes! / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(updateSizeBytes! / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Compare two version strings (returns true if latestVersion is newer)
  static bool _isNewerVersion(String currentVersion, String latestVersion) {
    try {
      final current = currentVersion.split('.').map(int.parse).toList();
      final latest = latestVersion.split('.').map(int.parse).toList();

      while (current.length < latest.length) {
        current.add(0);
      }
      while (latest.length < current.length) {
        latest.add(0);
      }

      for (var i = 0; i < current.length; i++) {
        if (latest[i] > current[i]) return true;
        if (latest[i] < current[i]) return false;
      }
      return false;
    } catch (e) {
      return currentVersion != latestVersion;
    }
  }

  @override
  String toString() {
    return 'UpdateInfo(currentVersion: $currentVersion, latestVersion: $latestVersion, '
        'updateUrl: $updateUrl, updateAvailable: $updateAvailable, urgency: $urgency, '
        'isMandatory: $isMandatory, releaseNotes: ${releaseNotes != null ? "[provided]" : "null"})';
  }

  /// Creates a copy of this UpdateInfo with the given fields replaced.
  UpdateInfo copyWith({
    String? currentVersion,
    String? latestVersion,
    String? updateUrl,
    bool? updateAvailable,
    String? releaseNotes,
    UpdateUrgency? urgency,
    String? minimumVersion,
    bool? isMandatory,
    DateTime? releaseDate,
    int? updateSizeBytes,
  }) {
    return UpdateInfo(
      currentVersion: currentVersion ?? this.currentVersion,
      latestVersion: latestVersion ?? this.latestVersion,
      updateUrl: updateUrl ?? this.updateUrl,
      updateAvailable: updateAvailable ?? this.updateAvailable,
      releaseNotes: releaseNotes ?? this.releaseNotes,
      urgency: urgency ?? this.urgency,
      minimumVersion: minimumVersion ?? this.minimumVersion,
      isMandatory: isMandatory ?? this.isMandatory,
      releaseDate: releaseDate ?? this.releaseDate,
      updateSizeBytes: updateSizeBytes ?? this.updateSizeBytes,
    );
  }
}

/// Analytics event data for update-related actions.
///
/// This class captures user interactions with update dialogs for analytics:
/// ```dart
/// appUpdater.onAnalyticsEvent = (event) {
///   analytics.logEvent(event.eventName, event.toMap());
/// };
/// ```
class UpdateAnalyticsEvent {
  /// The name of the event (e.g., 'update_dialog_shown', 'update_accepted')
  final String eventName;

  /// Current app version
  final String currentVersion;

  /// Available update version (if applicable)
  final String? latestVersion;

  /// The urgency level of the update
  final UpdateUrgency? urgency;

  /// Platform the event occurred on
  final String platform;

  /// Timestamp of the event
  final DateTime timestamp;

  /// Additional custom parameters
  final Map<String, dynamic>? customParams;

  /// Creates an analytics event with the given parameters.
  UpdateAnalyticsEvent({
    required this.eventName,
    required this.currentVersion,
    this.latestVersion,
    this.urgency,
    required this.platform,
    DateTime? timestamp,
    this.customParams,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Predefined event names for consistency
  static const String dialogShown = 'update_dialog_shown';
  static const String updateAccepted = 'update_accepted';
  static const String updateDeclined = 'update_declined';
  static const String versionSkipped = 'update_version_skipped';
  static const String doNotAskAgain = 'update_do_not_ask_again';
  static const String updateCheckStarted = 'update_check_started';
  static const String updateCheckCompleted = 'update_check_completed';
  static const String updateCheckFailed = 'update_check_failed';
  static const String storeOpened = 'update_store_opened';

  /// Converts the event to a map for analytics services.
  Map<String, dynamic> toMap() {
    return {
      'event_name': eventName,
      'current_version': currentVersion,
      if (latestVersion != null) 'latest_version': latestVersion,
      if (urgency != null) 'urgency': urgency!.name,
      'platform': platform,
      'timestamp': timestamp.toIso8601String(),
      ...?customParams,
    };
  }
}

/// Localized strings for update dialogs.
///
/// Use this class to provide translations for all dialog text:
/// ```dart
/// final frenchStrings = UpdateStrings(
///   updateAvailableTitle: 'Mise à jour disponible',
///   updateAvailableMessage: 'Une nouvelle version est disponible.',
///   updateButton: 'Mettre à jour',
///   laterButton: 'Plus tard',
/// );
/// ```
class UpdateStrings {
  /// Title for the update available dialog
  final String updateAvailableTitle;

  /// Message template for update available (use {currentVersion} and {latestVersion} as placeholders)
  final String updateAvailableMessage;

  /// Text for the update/download button
  final String updateButton;

  /// Text for the later/cancel button
  final String laterButton;

  /// Text for the skip version option
  final String skipVersionButton;

  /// Text for the do not ask again option
  final String doNotAskAgainButton;

  /// Title for critical/mandatory updates
  final String criticalUpdateTitle;

  /// Message for critical/mandatory updates
  final String criticalUpdateMessage;

  /// Title for release notes section
  final String releaseNotesTitle;

  /// Text shown when release notes are loading
  final String loadingText;

  /// Text shown when update check fails
  final String errorText;

  /// Text shown when app is up to date
  final String upToDateText;

  /// Creates localized strings with all required translations.
  const UpdateStrings({
    this.updateAvailableTitle = 'Update Available',
    this.updateAvailableMessage =
        'A new version ({latestVersion}) is available. You are currently on version {currentVersion}.',
    this.updateButton = 'Update Now',
    this.laterButton = 'Later',
    this.skipVersionButton = 'Skip this version',
    this.doNotAskAgainButton = "Don't remind me again",
    this.criticalUpdateTitle = 'Critical Update Required',
    this.criticalUpdateMessage =
        'This update contains important fixes. Please update to continue.',
    this.releaseNotesTitle = "What's New",
    this.loadingText = 'Checking for updates...',
    this.errorText = 'Unable to check for updates',
    this.upToDateText = 'Your app is up to date!',
  });

  /// Default English strings
  static const UpdateStrings defaultStrings = UpdateStrings();

  /// Formats the update message with version placeholders replaced.
  String formatUpdateMessage(String currentVersion, String latestVersion) {
    return updateAvailableMessage
        .replaceAll('{currentVersion}', currentVersion)
        .replaceAll('{latestVersion}', latestVersion);
  }
}

/// GitHub release information.
///
/// Contains metadata about a GitHub release for update checking:
/// ```dart
/// final appUpdater = AppUpdater.configure(
///   githubOwner: 'mycompany',
///   githubRepo: 'myapp',
/// );
/// ```
class GitHubRelease {
  /// The tag name (usually version number like 'v1.0.0' or '1.0.0')
  final String tagName;

  /// The release name/title
  final String name;

  /// Release notes body (markdown)
  final String body;

  /// Whether this is a prerelease
  final bool prerelease;

  /// Whether this is a draft release
  final bool draft;

  /// When the release was published
  final DateTime publishedAt;

  /// Direct download URL for the release assets
  final String? downloadUrl;

  /// URL to the release page on GitHub
  final String htmlUrl;

  /// Creates a GitHubRelease from parsed data.
  GitHubRelease({
    required this.tagName,
    required this.name,
    required this.body,
    required this.prerelease,
    required this.draft,
    required this.publishedAt,
    this.downloadUrl,
    required this.htmlUrl,
  });

  /// Parses version from tag name (removes 'v' prefix if present)
  String get version {
    if (tagName.toLowerCase().startsWith('v')) {
      return tagName.substring(1);
    }
    return tagName;
  }

  /// Creates a GitHubRelease from JSON API response.
  factory GitHubRelease.fromJson(Map<String, dynamic> json) {
    String? downloadUrl;
    final assets = json['assets'] as List?;
    if (assets != null && assets.isNotEmpty) {
      downloadUrl = assets[0]['browser_download_url'];
    }

    return GitHubRelease(
      tagName: json['tag_name'] ?? '',
      name: json['name'] ?? '',
      body: json['body'] ?? '',
      prerelease: json['prerelease'] ?? false,
      draft: json['draft'] ?? false,
      publishedAt: DateTime.parse(
          json['published_at'] ?? DateTime.now().toIso8601String()),
      downloadUrl: downloadUrl,
      htmlUrl: json['html_url'] ?? '',
    );
  }
}

/// TestFlight beta information for iOS.
///
/// Contains metadata about TestFlight builds:
/// ```dart
/// final appUpdater = AppUpdater.configure(
///   testFlightEnabled: true,
///   iosAppId: '123456789',
/// );
/// ```
class TestFlightInfo {
  /// The beta build version
  final String version;

  /// The build number
  final String buildNumber;

  /// When the build expires
  final DateTime? expiresAt;

  /// TestFlight URL
  final String testFlightUrl;

  /// Creates TestFlight info with the given details.
  TestFlightInfo({
    required this.version,
    required this.buildNumber,
    this.expiresAt,
    required this.testFlightUrl,
  });
}

/// Firebase Remote Config integration settings.
///
/// Configure how the package reads update info from Firebase Remote Config:
/// ```dart
/// final config = FirebaseRemoteConfigSettings(
///   minimumVersionKey: 'minimum_app_version',
///   latestVersionKey: 'latest_app_version',
///   updateUrlKey: 'app_update_url',
/// );
/// ```
class FirebaseRemoteConfigSettings {
  /// Key for minimum required version in Remote Config
  final String minimumVersionKey;

  /// Key for latest available version in Remote Config
  final String latestVersionKey;

  /// Key for update URL in Remote Config
  final String updateUrlKey;

  /// Key for release notes in Remote Config
  final String releaseNotesKey;

  /// Key for update urgency in Remote Config
  final String urgencyKey;

  /// Key for mandatory update flag in Remote Config
  final String mandatoryKey;

  /// Creates Firebase Remote Config settings with the specified keys.
  const FirebaseRemoteConfigSettings({
    this.minimumVersionKey = 'minimum_app_version',
    this.latestVersionKey = 'latest_app_version',
    this.updateUrlKey = 'app_update_url',
    this.releaseNotesKey = 'release_notes',
    this.urgencyKey = 'update_urgency',
    this.mandatoryKey = 'mandatory_update',
  });
}

// =============================================================================
// PREFERENCES MANAGER
// =============================================================================

/// Preferences manager for update dialog settings.
///
/// This class manages persistent storage of user preferences related to updates:
/// - Skipped versions
/// - "Do not ask again" setting
/// - Last check time for frequency control
/// - Last dismissed time
///
/// ```dart
/// // Check if user skipped a version
/// if (await UpdatePreferences.isVersionSkipped('2.0.0')) {
///   return; // Don't show dialog for skipped version
/// }
///
/// // Reset all preferences
/// await UpdatePreferences.clearAll();
/// ```
class UpdatePreferences {
  static const String _keySkippedVersion = 'app_updater_skipped_version';
  static const String _keyDoNotAskAgain = 'app_updater_do_not_ask_again';
  static const String _keyLastDismissedTime = 'app_updater_last_dismissed_time';
  static const String _keyLastCheckTime = 'app_updater_last_check_time';
  static const String _keyUpdateImpressions = 'app_updater_impressions';
  static const String _keyUpdateDismissals = 'app_updater_dismissals';

  /// Check if user has chosen to skip a specific version.
  ///
  /// Returns true if the user previously chose to skip [version].
  static Future<bool> isVersionSkipped(String version) async {
    final prefs = await SharedPreferences.getInstance();
    final skippedVersion = prefs.getString(_keySkippedVersion);
    return skippedVersion == version;
  }

  /// Skip a specific version (won't show dialog for this version again).
  ///
  /// Call this when the user clicks "Skip this version" to remember their choice.
  static Future<void> skipVersion(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySkippedVersion, version);
  }

  /// Check if user has chosen "do not ask again".
  ///
  /// Returns true if the user previously chose to not be reminded about updates.
  static Future<bool> isDoNotAskAgain() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyDoNotAskAgain) ?? false;
  }

  /// Set "do not ask again" preference.
  ///
  /// Set to true when the user clicks "Don't remind me again".
  static Future<void> setDoNotAskAgain(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDoNotAskAgain, value);
  }

  /// Get last dismissed time.
  ///
  /// Returns the DateTime when the user last dismissed an update dialog.
  static Future<DateTime?> getLastDismissedTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt(_keyLastDismissedTime);
    return timestamp != null
        ? DateTime.fromMillisecondsSinceEpoch(timestamp)
        : null;
  }

  /// Set last dismissed time.
  ///
  /// Called when the user dismisses an update dialog.
  static Future<void> setLastDismissedTime(DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyLastDismissedTime, time.millisecondsSinceEpoch);
  }

  /// Get last update check time.
  ///
  /// Returns the DateTime when updates were last checked.
  static Future<DateTime?> getLastCheckTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt(_keyLastCheckTime);
    return timestamp != null
        ? DateTime.fromMillisecondsSinceEpoch(timestamp)
        : null;
  }

  /// Set last update check time.
  ///
  /// Called automatically when checkForUpdate() is called.
  static Future<void> setLastCheckTime(DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyLastCheckTime, time.millisecondsSinceEpoch);
  }

  /// Check if enough time has passed since last check based on frequency.
  ///
  /// [checkFrequency] is the minimum duration between checks.
  /// Returns true if a check should be performed.
  static Future<bool> shouldCheckForUpdate(Duration checkFrequency) async {
    final lastCheck = await getLastCheckTime();
    if (lastCheck == null) return true;
    return DateTime.now().difference(lastCheck) >= checkFrequency;
  }

  /// Get the number of times update dialog has been shown.
  static Future<int> getUpdateImpressions() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyUpdateImpressions) ?? 0;
  }

  /// Increment update impressions count.
  static Future<void> incrementUpdateImpressions() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_keyUpdateImpressions) ?? 0;
    await prefs.setInt(_keyUpdateImpressions, current + 1);
  }

  /// Get the number of times user has dismissed update dialog.
  static Future<int> getUpdateDismissals() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyUpdateDismissals) ?? 0;
  }

  /// Increment update dismissals count.
  static Future<void> incrementUpdateDismissals() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_keyUpdateDismissals) ?? 0;
    await prefs.setInt(_keyUpdateDismissals, current + 1);
  }

  /// Clear all update preferences (reset).
  ///
  /// Resets all stored preferences including skipped versions and "do not ask again".
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySkippedVersion);
    await prefs.remove(_keyDoNotAskAgain);
    await prefs.remove(_keyLastDismissedTime);
    await prefs.remove(_keyLastCheckTime);
    await prefs.remove(_keyUpdateImpressions);
    await prefs.remove(_keyUpdateDismissals);
  }

  /// Clear skipped version only.
  ///
  /// Removes only the skipped version preference, keeping other settings.
  static Future<void> clearSkippedVersion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySkippedVersion);
  }
}

// =============================================================================
// CONFIGURATION
// =============================================================================

/// Configuration class for AppUpdater.
///
/// This class holds all configuration options for the update checker:
/// ```dart
/// final config = AppUpdaterConfig(
///   iosAppId: '123456789',
///   androidPackageName: 'com.example.app',
///   githubOwner: 'mycompany',
///   githubRepo: 'myapp',
///   checkFrequency: Duration(days: 1),
/// );
/// ```
class AppUpdaterConfig {
  /// iOS App Store app ID (numeric ID from App Store Connect)
  final String? iosAppId;

  /// macOS App Store app ID (numeric ID from App Store Connect)
  final String? macAppId;

  /// Android package name (auto-detected if not provided)
  final String? androidPackageName;

  /// Microsoft Store product ID
  final String? microsoftProductId;

  /// Snap Store package name
  final String? snapName;

  /// Flathub app ID (e.g., com.example.app)
  final String? flathubAppId;

  /// Custom XML endpoint URL for version checking
  final String? customXmlUrl;

  /// Custom JSON endpoint URL for version checking
  final String? customJsonUrl;

  /// Linux store type (snap or flathub)
  final LinuxStoreType linuxStoreType;

  // === GitHub Releases Support ===

  /// GitHub repository owner (username or organization)
  final String? githubOwner;

  /// GitHub repository name
  final String? githubRepo;

  /// Include GitHub prereleases in update checks
  final bool githubIncludePrereleases;

  /// GitHub personal access token for private repository support.
  ///
  /// This is the easiest way to access private GitHub repositories.
  /// Simply pass your GitHub PAT and the package handles authentication:
  /// ```dart
  /// AppUpdater.configure(
  ///   githubOwner: 'mycompany',
  ///   githubRepo: 'private-app',
  ///   githubToken: 'ghp_xxxxxxxxxxxxx',
  /// );
  /// ```
  final String? githubToken;

  /// Custom HTTP headers for GitHub API requests.
  ///
  /// Use this for advanced authentication scenarios (e.g., GitHub Enterprise)
  /// or when you need full control over request headers:
  /// ```dart
  /// AppUpdater.configure(
  ///   githubOwner: 'mycompany',
  ///   githubRepo: 'private-app',
  ///   githubHeaders: {
  ///     'Authorization': 'token ghp_xxxxxxxxxxxxx',
  ///     'Accept': 'application/vnd.github+json',
  ///   },
  /// );
  /// ```
  ///
  /// Note: If both [githubToken] and [githubHeaders] are provided,
  /// [githubHeaders] takes precedence for the `Authorization` header.
  final Map<String, String>? githubHeaders;

  // === TestFlight Support (iOS) ===

  /// Enable TestFlight beta update checking
  final bool testFlightEnabled;

  /// Custom TestFlight URL (optional)
  final String? testFlightUrl;

  // === Firebase Remote Config ===

  /// Enable Firebase Remote Config for version info
  final bool firebaseRemoteConfigEnabled;

  /// Firebase Remote Config keys configuration
  final FirebaseRemoteConfigSettings? firebaseSettings;

  /// Callback to fetch values from Firebase Remote Config
  /// Must be provided if firebaseRemoteConfigEnabled is true
  final Future<Map<String, dynamic>> Function()? firebaseConfigFetcher;

  // === Update Frequency Control ===

  /// How often to check for updates (null = always check)
  final Duration? checkFrequency;

  // === Minimum Version / Force Update ===

  /// Minimum required version - forces update if current version is below this
  final String? minimumVersion;

  // === Analytics ===

  /// Callback for analytics events
  final void Function(UpdateAnalyticsEvent event)? onAnalyticsEvent;

  // === Localization ===

  /// Localized strings for dialogs
  final UpdateStrings strings;

  /// Creates an AppUpdater configuration with the specified options.
  const AppUpdaterConfig({
    this.iosAppId,
    this.macAppId,
    this.androidPackageName,
    this.microsoftProductId,
    this.snapName,
    this.flathubAppId,
    this.customXmlUrl,
    this.customJsonUrl,
    this.linuxStoreType = LinuxStoreType.snap,
    this.githubOwner,
    this.githubRepo,
    this.githubIncludePrereleases = false,
    this.githubToken,
    this.githubHeaders,
    this.testFlightEnabled = false,
    this.testFlightUrl,
    this.firebaseRemoteConfigEnabled = false,
    this.firebaseSettings,
    this.firebaseConfigFetcher,
    this.checkFrequency,
    this.minimumVersion,
    this.onAnalyticsEvent,
    this.strings = const UpdateStrings(),
  });

  /// Creates a copy of this config with the given fields replaced.
  AppUpdaterConfig copyWith({
    String? iosAppId,
    String? macAppId,
    String? androidPackageName,
    String? microsoftProductId,
    String? snapName,
    String? flathubAppId,
    String? customXmlUrl,
    String? customJsonUrl,
    LinuxStoreType? linuxStoreType,
    String? githubOwner,
    String? githubRepo,
    bool? githubIncludePrereleases,
    String? githubToken,
    Map<String, String>? githubHeaders,
    bool? testFlightEnabled,
    String? testFlightUrl,
    bool? firebaseRemoteConfigEnabled,
    FirebaseRemoteConfigSettings? firebaseSettings,
    Future<Map<String, dynamic>> Function()? firebaseConfigFetcher,
    Duration? checkFrequency,
    String? minimumVersion,
    void Function(UpdateAnalyticsEvent event)? onAnalyticsEvent,
    UpdateStrings? strings,
  }) {
    return AppUpdaterConfig(
      iosAppId: iosAppId ?? this.iosAppId,
      macAppId: macAppId ?? this.macAppId,
      androidPackageName: androidPackageName ?? this.androidPackageName,
      microsoftProductId: microsoftProductId ?? this.microsoftProductId,
      snapName: snapName ?? this.snapName,
      flathubAppId: flathubAppId ?? this.flathubAppId,
      customXmlUrl: customXmlUrl ?? this.customXmlUrl,
      customJsonUrl: customJsonUrl ?? this.customJsonUrl,
      linuxStoreType: linuxStoreType ?? this.linuxStoreType,
      githubOwner: githubOwner ?? this.githubOwner,
      githubRepo: githubRepo ?? this.githubRepo,
      githubIncludePrereleases:
          githubIncludePrereleases ?? this.githubIncludePrereleases,
      githubToken: githubToken ?? this.githubToken,
      githubHeaders: githubHeaders ?? this.githubHeaders,
      testFlightEnabled: testFlightEnabled ?? this.testFlightEnabled,
      testFlightUrl: testFlightUrl ?? this.testFlightUrl,
      firebaseRemoteConfigEnabled:
          firebaseRemoteConfigEnabled ?? this.firebaseRemoteConfigEnabled,
      firebaseSettings: firebaseSettings ?? this.firebaseSettings,
      firebaseConfigFetcher: firebaseConfigFetcher ?? this.firebaseConfigFetcher,
      checkFrequency: checkFrequency ?? this.checkFrequency,
      minimumVersion: minimumVersion ?? this.minimumVersion,
      onAnalyticsEvent: onAnalyticsEvent ?? this.onAnalyticsEvent,
      strings: strings ?? this.strings,
    );
  }
}

// =============================================================================
// MAIN APP UPDATER CLASS
// =============================================================================

/// Main class for checking and managing app updates across all platforms.
///
/// AppUpdater provides a comprehensive solution for checking app updates
/// from various sources and displaying platform-native update dialogs.
///
/// ## Basic Usage
/// ```dart
/// final appUpdater = AppUpdater.configure(
///   iosAppId: '123456789',
///   androidPackageName: 'com.example.app',
/// );
///
/// // Check and show dialog if update available
/// await appUpdater.checkAndShowUpdateDialog(context);
/// ```
///
/// ## With GitHub Releases
/// ```dart
/// final appUpdater = AppUpdater.configure(
///   githubOwner: 'mycompany',
///   githubRepo: 'myapp',
/// );
/// ```
///
/// ## With Update Frequency Control
/// ```dart
/// final appUpdater = AppUpdater.configure(
///   iosAppId: '123456789',
///   checkFrequency: Duration(days: 1), // Only check once per day
/// );
/// ```
///
/// ## With Analytics
/// ```dart
/// final appUpdater = AppUpdater.configure(
///   iosAppId: '123456789',
///   onAnalyticsEvent: (event) {
///     analytics.logEvent(event.eventName, event.toMap());
///   },
/// );
/// ```
class AppUpdater {
  /// The configuration for this AppUpdater instance
  final AppUpdaterConfig config;

  static PackageInfo? _cachedPackageInfo;

  /// Timer for background update checking
  Timer? _backgroundCheckTimer;

  /// Stream controller for background update notifications
  final StreamController<UpdateInfo> _updateStreamController =
      StreamController<UpdateInfo>.broadcast();

  /// Stream of update notifications from background checks.
  ///
  /// Listen to this stream to receive notifications when updates are found:
  /// ```dart
  /// appUpdater.updateStream.listen((updateInfo) {
  ///   if (updateInfo.updateAvailable) {
  ///     // Show notification or dialog
  ///   }
  /// });
  /// ```
  Stream<UpdateInfo> get updateStream => _updateStreamController.stream;

  /// Create an AppUpdater instance with the given configuration.
  AppUpdater(this.config);

  /// Create an AppUpdater with individual parameters (convenience constructor).
  ///
  /// This factory constructor provides a more convenient way to create an
  /// AppUpdater without explicitly creating an AppUpdaterConfig:
  /// ```dart
  /// final appUpdater = AppUpdater.configure(
  ///   iosAppId: '123456789',
  ///   androidPackageName: 'com.example.app',
  ///   checkFrequency: Duration(days: 1),
  /// );
  /// ```
  factory AppUpdater.configure({
    String? iosAppId,
    String? macAppId,
    String? androidPackageName,
    String? microsoftProductId,
    String? snapName,
    String? flathubAppId,
    String? customXmlUrl,
    String? customJsonUrl,
    LinuxStoreType linuxStoreType = LinuxStoreType.snap,
    String? githubOwner,
    String? githubRepo,
    bool githubIncludePrereleases = false,
    String? githubToken,
    Map<String, String>? githubHeaders,
    bool testFlightEnabled = false,
    String? testFlightUrl,
    bool firebaseRemoteConfigEnabled = false,
    FirebaseRemoteConfigSettings? firebaseSettings,
    Future<Map<String, dynamic>> Function()? firebaseConfigFetcher,
    Duration? checkFrequency,
    String? minimumVersion,
    void Function(UpdateAnalyticsEvent event)? onAnalyticsEvent,
    UpdateStrings strings = const UpdateStrings(),
  }) {
    return AppUpdater(AppUpdaterConfig(
      iosAppId: iosAppId,
      macAppId: macAppId,
      androidPackageName: androidPackageName,
      microsoftProductId: microsoftProductId,
      snapName: snapName,
      flathubAppId: flathubAppId,
      customXmlUrl: customXmlUrl,
      customJsonUrl: customJsonUrl,
      linuxStoreType: linuxStoreType,
      githubOwner: githubOwner,
      githubRepo: githubRepo,
      githubIncludePrereleases: githubIncludePrereleases,
      githubToken: githubToken,
      githubHeaders: githubHeaders,
      testFlightEnabled: testFlightEnabled,
      testFlightUrl: testFlightUrl,
      firebaseRemoteConfigEnabled: firebaseRemoteConfigEnabled,
      firebaseSettings: firebaseSettings,
      firebaseConfigFetcher: firebaseConfigFetcher,
      checkFrequency: checkFrequency,
      minimumVersion: minimumVersion,
      onAnalyticsEvent: onAnalyticsEvent,
      strings: strings,
    ));
  }

  /// Dispose of resources used by this AppUpdater.
  ///
  /// Call this when you're done using the AppUpdater to clean up resources:
  /// ```dart
  /// @override
  /// void dispose() {
  ///   appUpdater.dispose();
  ///   super.dispose();
  /// }
  /// ```
  void dispose() {
    stopBackgroundChecking();
    _updateStreamController.close();
  }

  // ===========================================================================
  // PRIVATE HELPER METHODS
  // ===========================================================================

  static Future<PackageInfo> _getPackageInfo() async {
    _cachedPackageInfo ??= await PackageInfo.fromPlatform();
    return _cachedPackageInfo!;
  }

  static Future<String> _getCurrentVersion() async {
    final packageInfo = await _getPackageInfo();
    return packageInfo.version;
  }

  static Future<String> _getPackageName() async {
    final packageInfo = await _getPackageInfo();
    return packageInfo.packageName;
  }

  /// Get the current platform name for analytics
  String _getPlatformName() {
    if (kIsWeb) return 'web';
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isWindows) return 'windows';
    if (Platform.isLinux) return 'linux';
    return 'unknown';
  }

  /// Track an analytics event
  void _trackEvent(String eventName,
      {String? latestVersion, UpdateUrgency? urgency}) async {
    if (config.onAnalyticsEvent == null) return;

    final currentVersion = await _getCurrentVersion();
    config.onAnalyticsEvent!(UpdateAnalyticsEvent(
      eventName: eventName,
      currentVersion: currentVersion,
      latestVersion: latestVersion,
      urgency: urgency,
      platform: _getPlatformName(),
    ));
  }

  // ===========================================================================
  // VERSION FETCHING METHODS
  // ===========================================================================

  /// Fetch latest version from iOS App Store
  static Future<Map<String, dynamic>> _getAppStoreInfo(String appId) async {
    try {
      final url = 'https://itunes.apple.com/lookup?id=$appId';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['resultCount'] > 0) {
          final result = json['results'][0];
          return {
            'version': result['version'],
            'releaseNotes': result['releaseNotes'],
            'releaseDate': result['currentVersionReleaseDate'],
            'fileSizeBytes': result['fileSizeBytes'],
          };
        }
      }
    } catch (e) {
      debugPrint('Error fetching App Store version: $e');
    }
    return {};
  }

  /// Fetch latest version from macOS App Store
  static Future<Map<String, dynamic>> _getMacAppStoreInfo(String appId) async {
    return _getAppStoreInfo(appId); // Same API endpoint
  }

  /// Fetch latest version from Google Play Store
  static Future<String?> _getLatestVersionFromPlayStore(
      String packageName) async {
    try {
      final url =
          'https://play.google.com/store/apps/details?id=$packageName&hl=en';
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.5',
        },
      );
      if (response.statusCode == 200) {
        final body = response.body;

        // Pattern 1: Version after triple closing brackets (current Play Store format)
        final pattern1 = RegExp(r'\]\]\],"(\d+\.\d+\.\d+(?:\.\d+)?)",null');

        // Pattern 2: Version in array followed by null values
        final pattern2 = RegExp(r',"(\d+\.\d+\.\d+(?:\.\d+)?)",null,null');

        // Pattern 3: Version after array end with specific structure
        final pattern3 = RegExp(r'"\]\]\],"(\d+\.\d+\.\d+(?:\.\d+)?)"');

        // Pattern 4: Look for version in nested arrays
        final pattern4 = RegExp(r'\[\["(\d+\.\d+\.\d+(?:\.\d+)?)"\]\]');

        // Pattern 5: Version followed by null array pattern
        final pattern5 = RegExp(r'"(\d+\.\d+\.\d+(?:\.\d+)?)",\[null,null');

        // Try each pattern in order of reliability
        for (final pattern
            in [pattern1, pattern2, pattern3, pattern5, pattern4]) {
          final match = pattern.firstMatch(body);
          if (match != null) {
            final version = match.group(1);
            if (version != null && _isValidVersion(version)) {
              return version;
            }
          }
        }

        // Fallback: Find all version-like strings and return the most likely one
        final allVersions =
            RegExp(r'"(\d+\.\d+\.\d+(?:\.\d+)?)"').allMatches(body);
        final versionCounts = <String, int>{};
        for (final match in allVersions) {
          final version = match.group(1);
          if (version != null && _isValidVersion(version)) {
            versionCounts[version] = (versionCounts[version] ?? 0) + 1;
          }
        }

        if (versionCounts.isNotEmpty) {
          final sortedVersions = versionCounts.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          return sortedVersions.first.key;
        }
      }
    } catch (e) {
      debugPrint('Error fetching Play Store version: $e');
    }
    return null;
  }

  /// Validate that a string looks like a valid version number
  static bool _isValidVersion(String version) {
    final parts = version.split('.');
    if (parts.isEmpty || parts.length > 4) return false;

    for (final part in parts) {
      final num = int.tryParse(part);
      if (num == null || num < 0 || num > 9999) return false;
    }

    final firstPart = int.tryParse(parts.first);
    if (firstPart != null && firstPart > 999) return false;

    return true;
  }

  /// Fetch latest version from Microsoft Store
  static Future<String?> _getLatestVersionFromMicrosoftStore(
      String productId) async {
    try {
      final url =
          'https://storeedgefd.dsx.mp.microsoft.com/v9.0/products/$productId?market=US&locale=en-US';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['Payload'] != null && json['Payload']['Skus'] != null) {
          final skus = json['Payload']['Skus'] as List;
          if (skus.isNotEmpty) {
            return skus[0]['Version'];
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching Microsoft Store version: $e');
    }
    return null;
  }

  /// Fetch latest version from Snapcraft Store
  static Future<String?> _getLatestVersionFromSnapStore(String snapName) async {
    try {
      final url = 'https://api.snapcraft.io/v2/snaps/info/$snapName';
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Snap-Device-Series': '16',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['channel-map'] != null) {
          final channelMap = json['channel-map'] as List;
          for (var channel in channelMap) {
            if (channel['channel']?['name'] == 'stable') {
              return channel['version'];
            }
          }
          if (channelMap.isNotEmpty) {
            return channelMap[0]['version'];
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching Snap Store version: $e');
    }
    return null;
  }

  /// Fetch latest version from Flathub
  static Future<Map<String, dynamic>> _getFlathubInfo(String appId) async {
    try {
      final url = 'https://flathub.org/api/v2/appstream/$appId';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['releases'] != null) {
          final releases = json['releases'] as List;
          if (releases.isNotEmpty) {
            final latest = releases[0];
            return {
              'version': latest['version'],
              'releaseNotes': latest['description'],
              'releaseDate': latest['timestamp']?.toString(),
            };
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching Flathub version: $e');
    }
    return {};
  }

  /// Fetch latest version from custom XML endpoint
  static Future<Map<String, String?>> _getLatestVersionFromXML(
      String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final document = xml.XmlDocument.parse(response.body);
        final versionElements = document.findAllElements('version');
        final urlElements = document.findAllElements('url');
        final releaseNotesElements = document.findAllElements('releaseNotes');
        final minimumVersionElements =
            document.findAllElements('minimumVersion');
        final urgencyElements = document.findAllElements('urgency');
        final mandatoryElements = document.findAllElements('mandatory');

        return {
          'version':
              versionElements.isNotEmpty ? versionElements.first.innerText : null,
          'url': urlElements.isNotEmpty ? urlElements.first.innerText : null,
          'releaseNotes': releaseNotesElements.isNotEmpty
              ? releaseNotesElements.first.innerText
              : null,
          'minimumVersion': minimumVersionElements.isNotEmpty
              ? minimumVersionElements.first.innerText
              : null,
          'urgency':
              urgencyElements.isNotEmpty ? urgencyElements.first.innerText : null,
          'mandatory': mandatoryElements.isNotEmpty
              ? mandatoryElements.first.innerText
              : null,
        };
      }
    } catch (e) {
      debugPrint('Error fetching XML version: $e');
    }
    return {};
  }

  /// Fetch latest version from custom JSON endpoint
  static Future<Map<String, dynamic>> _getLatestVersionFromJSON(
      String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return {
          'version': json['version']?.toString(),
          'url': json['url']?.toString(),
          'releaseNotes': json['releaseNotes']?.toString() ??
              json['release_notes']?.toString() ??
              json['changelog']?.toString(),
          'minimumVersion': json['minimumVersion']?.toString() ??
              json['minimum_version']?.toString(),
          'urgency': json['urgency']?.toString(),
          'mandatory': json['mandatory'] ?? json['force_update'] ?? false,
        };
      }
    } catch (e) {
      debugPrint('Error fetching JSON version: $e');
    }
    return {};
  }

  /// Build merged headers for GitHub API requests.
  ///
  /// Priority: githubHeaders > githubToken > defaults.
  Map<String, String> _buildGitHubHeaders() {
    final headers = <String, String>{
      'Accept': 'application/vnd.github.v3+json',
    };

    // Apply token-based auth if provided
    if (config.githubToken != null) {
      headers['Authorization'] = 'token ${config.githubToken}';
    }

    // Apply custom headers (overrides token if both set)
    if (config.githubHeaders != null) {
      headers.addAll(config.githubHeaders!);
    }

    return headers;
  }

  /// Fetch latest release from GitHub Releases.
  ///
  /// Supports private repositories via [AppUpdaterConfig.githubToken]
  /// or [AppUpdaterConfig.githubHeaders].
  Future<GitHubRelease?> _getLatestGitHubRelease() async {
    if (config.githubOwner == null || config.githubRepo == null) return null;

    try {
      final url =
          'https://api.github.com/repos/${config.githubOwner}/${config.githubRepo}/releases';
      final response = await http.get(
        Uri.parse(url),
        headers: _buildGitHubHeaders(),
      );

      if (response.statusCode == 200) {
        final releases = jsonDecode(response.body) as List;
        for (final release in releases) {
          final githubRelease = GitHubRelease.fromJson(release);
          // Skip drafts
          if (githubRelease.draft) continue;
          // Skip prereleases unless configured to include them
          if (githubRelease.prerelease && !config.githubIncludePrereleases) {
            continue;
          }
          return githubRelease;
        }
      }
    } catch (e) {
      debugPrint('Error fetching GitHub releases: $e');
    }
    return null;
  }

  /// Get update info from Firebase Remote Config
  Future<Map<String, dynamic>> _getFirebaseRemoteConfigInfo() async {
    if (!config.firebaseRemoteConfigEnabled ||
        config.firebaseConfigFetcher == null) {
      return {};
    }

    try {
      final settings =
          config.firebaseSettings ?? const FirebaseRemoteConfigSettings();
      final remoteValues = await config.firebaseConfigFetcher!();

      return {
        'version': remoteValues[settings.latestVersionKey]?.toString(),
        'minimumVersion': remoteValues[settings.minimumVersionKey]?.toString(),
        'url': remoteValues[settings.updateUrlKey]?.toString(),
        'releaseNotes': remoteValues[settings.releaseNotesKey]?.toString(),
        'urgency': remoteValues[settings.urgencyKey]?.toString(),
        'mandatory': remoteValues[settings.mandatoryKey] ?? false,
      };
    } catch (e) {
      debugPrint('Error fetching Firebase Remote Config: $e');
    }
    return {};
  }

  /// Compare two version strings (returns true if latestVersion is newer)
  static bool _isNewerVersion(String currentVersion, String latestVersion) {
    try {
      final current = currentVersion.split('.').map(int.parse).toList();
      final latest = latestVersion.split('.').map(int.parse).toList();

      while (current.length < latest.length) {
        current.add(0);
      }
      while (latest.length < current.length) {
        latest.add(0);
      }

      for (var i = 0; i < current.length; i++) {
        if (latest[i] > current[i]) return true;
        if (latest[i] < current[i]) return false;
      }
      return false;
    } catch (e) {
      return currentVersion != latestVersion;
    }
  }

  /// Parse urgency string to enum
  UpdateUrgency _parseUrgency(String? urgency) {
    if (urgency == null) return UpdateUrgency.medium;
    switch (urgency.toLowerCase()) {
      case 'low':
        return UpdateUrgency.low;
      case 'high':
        return UpdateUrgency.high;
      case 'critical':
        return UpdateUrgency.critical;
      default:
        return UpdateUrgency.medium;
    }
  }

  // ===========================================================================
  // PUBLIC API
  // ===========================================================================

  /// Get the store URL for the current platform.
  ///
  /// Returns the appropriate store URL based on the current platform and
  /// configuration. Returns null if no URL is available.
  String? getStoreUrl() {
    if (kIsWeb) return null;

    if (Platform.isIOS && config.iosAppId != null) {
      return 'https://apps.apple.com/app/id${config.iosAppId}';
    } else if (Platform.isMacOS && config.macAppId != null) {
      return 'https://apps.apple.com/app/id${config.macAppId}';
    } else if (Platform.isAndroid && config.androidPackageName != null) {
      return 'https://play.google.com/store/apps/details?id=${config.androidPackageName}';
    } else if (Platform.isWindows && config.microsoftProductId != null) {
      return 'ms-windows-store://pdp/?productid=${config.microsoftProductId}';
    } else if (Platform.isLinux) {
      if (config.linuxStoreType == LinuxStoreType.snap &&
          config.snapName != null) {
        return 'https://snapcraft.io/${config.snapName}';
      } else if (config.linuxStoreType == LinuxStoreType.flathub &&
          config.flathubAppId != null) {
        return 'https://flathub.org/apps/${config.flathubAppId}';
      }
    }

    // GitHub releases fallback
    if (config.githubOwner != null && config.githubRepo != null) {
      return 'https://github.com/${config.githubOwner}/${config.githubRepo}/releases';
    }

    return null;
  }

  /// Get TestFlight URL for iOS beta testing.
  ///
  /// Returns the TestFlight URL if configured, otherwise a generic URL.
  String? getTestFlightUrl() {
    if (config.testFlightUrl != null) return config.testFlightUrl;
    if (config.iosAppId != null) {
      return 'https://testflight.apple.com/join/${config.iosAppId}';
    }
    return null;
  }

  /// Check for updates and return UpdateInfo.
  ///
  /// This method checks for updates from the configured sources and returns
  /// an [UpdateInfo] object with details about any available update.
  ///
  /// ```dart
  /// final updateInfo = await appUpdater.checkForUpdate();
  /// if (updateInfo.updateAvailable) {
  ///   print('Update available: ${updateInfo.latestVersion}');
  ///   print('Release notes: ${updateInfo.releaseNotes}');
  /// }
  /// ```
  ///
  /// If [respectFrequency] is true (default), the method will respect the
  /// configured check frequency and may return cached results.
  Future<UpdateInfo> checkForUpdate({bool respectFrequency = true}) async {
    // Check frequency control
    if (respectFrequency && config.checkFrequency != null) {
      final shouldCheck =
          await UpdatePreferences.shouldCheckForUpdate(config.checkFrequency!);
      if (!shouldCheck) {
        // Return a basic UpdateInfo indicating no check was performed
        final currentVersion = await _getCurrentVersion();
        return UpdateInfo(
          currentVersion: currentVersion,
          updateAvailable: false,
        );
      }
    }

    _trackEvent(UpdateAnalyticsEvent.updateCheckStarted);

    final currentVersion = await _getCurrentVersion();
    String? latestVersion;
    String? updateUrl;
    String? releaseNotes;
    String? minimumVersion = config.minimumVersion;
    UpdateUrgency urgency = UpdateUrgency.medium;
    bool isMandatory = false;
    DateTime? releaseDate;
    int? updateSizeBytes;

    try {
      // Check Firebase Remote Config first (highest priority)
      if (config.firebaseRemoteConfigEnabled) {
        final firebaseInfo = await _getFirebaseRemoteConfigInfo();
        if (firebaseInfo['version'] != null) {
          latestVersion = firebaseInfo['version'];
          updateUrl = firebaseInfo['url'] ?? getStoreUrl();
          releaseNotes = firebaseInfo['releaseNotes'];
          minimumVersion = firebaseInfo['minimumVersion'] ?? minimumVersion;
          urgency = _parseUrgency(firebaseInfo['urgency']);
          isMandatory = firebaseInfo['mandatory'] == true;
        }
      }

      // Check custom endpoints (second priority)
      if (latestVersion == null && config.customXmlUrl != null) {
        final result = await _getLatestVersionFromXML(config.customXmlUrl!);
        latestVersion = result['version'];
        updateUrl = result['url'];
        releaseNotes = result['releaseNotes'];
        minimumVersion = result['minimumVersion'] ?? minimumVersion;
        urgency = _parseUrgency(result['urgency']);
        isMandatory = result['mandatory'] == 'true';
      } else if (latestVersion == null && config.customJsonUrl != null) {
        final result = await _getLatestVersionFromJSON(config.customJsonUrl!);
        latestVersion = result['version'];
        updateUrl = result['url'];
        releaseNotes = result['releaseNotes'];
        minimumVersion = result['minimumVersion'] ?? minimumVersion;
        urgency = _parseUrgency(result['urgency']);
        isMandatory = result['mandatory'] == true;
      }

      // Check GitHub releases
      if (latestVersion == null &&
          config.githubOwner != null &&
          config.githubRepo != null) {
        final release = await _getLatestGitHubRelease();
        if (release != null) {
          latestVersion = release.version;
          updateUrl = release.downloadUrl ?? release.htmlUrl;
          releaseNotes = release.body;
          releaseDate = release.publishedAt;
        }
      }

      // Platform-specific store checks
      if (latestVersion == null && !kIsWeb) {
        if (Platform.isIOS && config.iosAppId != null) {
          final info = await _getAppStoreInfo(config.iosAppId!);
          latestVersion = info['version'];
          releaseNotes = info['releaseNotes'];
          if (info['releaseDate'] != null) {
            releaseDate = DateTime.tryParse(info['releaseDate']);
          }
          if (info['fileSizeBytes'] != null) {
            updateSizeBytes = int.tryParse(info['fileSizeBytes'].toString());
          }
          updateUrl = 'https://apps.apple.com/app/id${config.iosAppId}';
        } else if (Platform.isMacOS && config.macAppId != null) {
          final info = await _getMacAppStoreInfo(config.macAppId!);
          latestVersion = info['version'];
          releaseNotes = info['releaseNotes'];
          if (info['releaseDate'] != null) {
            releaseDate = DateTime.tryParse(info['releaseDate']);
          }
          updateUrl = 'https://apps.apple.com/app/id${config.macAppId}';
        } else if (Platform.isAndroid) {
          final packageName =
              config.androidPackageName ?? await _getPackageName();
          latestVersion = await _getLatestVersionFromPlayStore(packageName);
          updateUrl =
              'https://play.google.com/store/apps/details?id=$packageName';
        } else if (Platform.isWindows && config.microsoftProductId != null) {
          latestVersion = await _getLatestVersionFromMicrosoftStore(
              config.microsoftProductId!);
          updateUrl =
              'ms-windows-store://pdp/?productid=${config.microsoftProductId}';
        } else if (Platform.isLinux) {
          if (config.linuxStoreType == LinuxStoreType.snap &&
              config.snapName != null) {
            latestVersion =
                await _getLatestVersionFromSnapStore(config.snapName!);
            updateUrl = 'https://snapcraft.io/${config.snapName}';
          } else if (config.linuxStoreType == LinuxStoreType.flathub &&
              config.flathubAppId != null) {
            final info = await _getFlathubInfo(config.flathubAppId!);
            latestVersion = info['version'];
            releaseNotes = info['releaseNotes'];
            if (info['releaseDate'] != null) {
              releaseDate =
                  DateTime.fromMillisecondsSinceEpoch(info['releaseDate'] * 1000);
            }
            updateUrl = 'https://flathub.org/apps/${config.flathubAppId}';
          }
        }
      }

      // Update last check time
      await UpdatePreferences.setLastCheckTime(DateTime.now());

      final updateAvailable = latestVersion != null &&
          _isNewerVersion(currentVersion, latestVersion);

      // Check if mandatory due to minimum version
      if (minimumVersion != null &&
          _isNewerVersion(currentVersion, minimumVersion)) {
        isMandatory = true;
        urgency = UpdateUrgency.critical;
      }

      _trackEvent(
        UpdateAnalyticsEvent.updateCheckCompleted,
        latestVersion: latestVersion,
        urgency: urgency,
      );

      return UpdateInfo(
        currentVersion: currentVersion,
        latestVersion: latestVersion,
        updateUrl: updateUrl,
        updateAvailable: updateAvailable,
        releaseNotes: releaseNotes,
        urgency: urgency,
        minimumVersion: minimumVersion,
        isMandatory: isMandatory,
        releaseDate: releaseDate,
        updateSizeBytes: updateSizeBytes,
      );
    } catch (e) {
      debugPrint('Error checking for update: $e');
      _trackEvent(UpdateAnalyticsEvent.updateCheckFailed);

      return UpdateInfo(
        currentVersion: currentVersion,
        updateAvailable: false,
      );
    }
  }

  /// Launch URL helper
  static Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      throw Exception('Could not launch $url');
    }
  }

  /// Get the appropriate dialog style for the current platform
  static UpdateDialogStyle _getAdaptiveStyle(BuildContext context) {
    if (kIsWeb) return UpdateDialogStyle.material;

    final platform = Theme.of(context).platform;
    switch (platform) {
      case TargetPlatform.iOS:
        return UpdateDialogStyle.cupertino;
      case TargetPlatform.macOS:
        return UpdateDialogStyle.cupertino;
      case TargetPlatform.android:
        return UpdateDialogStyle.material;
      case TargetPlatform.windows:
        return UpdateDialogStyle.fluent;
      case TargetPlatform.linux:
        return UpdateDialogStyle.adwaita;
      case TargetPlatform.fuchsia:
        return UpdateDialogStyle.material;
    }
  }

  /// Get urgency color for UI
  static Color _getUrgencyColor(UpdateUrgency urgency, BuildContext context) {
    switch (urgency) {
      case UpdateUrgency.low:
        return Colors.grey;
      case UpdateUrgency.medium:
        return Theme.of(context).colorScheme.primary;
      case UpdateUrgency.high:
        return Colors.orange;
      case UpdateUrgency.critical:
        return Colors.red;
    }
  }

  /// Get urgency icon
  static IconData _getUrgencyIcon(UpdateUrgency urgency) {
    switch (urgency) {
      case UpdateUrgency.low:
        return Icons.info_outline;
      case UpdateUrgency.medium:
        return Icons.system_update;
      case UpdateUrgency.high:
        return Icons.warning_amber;
      case UpdateUrgency.critical:
        return Icons.error;
    }
  }

  // ===========================================================================
  // DIALOG BUILDERS
  // ===========================================================================

  /// Build Material Design dialog (Android style)
  Widget _buildMaterialDialog(
    BuildContext context, {
    required UpdateInfo updateInfo,
    required String title,
    required String message,
    required String cancelText,
    required String updateText,
    required bool showSkipVersion,
    required bool showDoNotAskAgain,
    required bool showReleaseNotes,
    required bool isPersistent,
    required VoidCallback? onCancel,
    required VoidCallback? onUpdate,
    required VoidCallback? onSkipVersion,
    required VoidCallback? onDoNotAskAgain,
  }) {
    final urgencyColor = _getUrgencyColor(updateInfo.urgency, context);
    final urgencyIcon = _getUrgencyIcon(updateInfo.urgency);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      icon: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: urgencyColor.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          urgencyIcon,
          size: 32,
          color: urgencyColor,
        ),
      ),
      title: Text(
        title,
        textAlign: TextAlign.center,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
            ),
            if (showReleaseNotes && updateInfo.releaseNotes != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      config.strings.releaseNotesTitle,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      updateInfo.releaseNotes!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
            if (updateInfo.formattedUpdateSize != null) ...[
              const SizedBox(height: 8),
              Text(
                'Size: ${updateInfo.formattedUpdateSize}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                    ),
              ),
            ],
            if (showSkipVersion || showDoNotAskAgain) ...[
              const SizedBox(height: 16),
              if (showSkipVersion)
                TextButton.icon(
                  onPressed: onSkipVersion,
                  icon: const Icon(Icons.skip_next, size: 18),
                  label: Text(config.strings.skipVersionButton),
                ),
              if (showDoNotAskAgain)
                TextButton.icon(
                  onPressed: onDoNotAskAgain,
                  icon: const Icon(Icons.notifications_off, size: 18),
                  label: Text(config.strings.doNotAskAgainButton),
                ),
            ],
          ],
        ),
      ),
      actions: [
        if (!isPersistent)
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onCancel?.call();
            },
            child: Text(cancelText),
          ),
        FilledButton.icon(
          onPressed: () async {
            Navigator.of(context).pop();
            if (onUpdate != null) {
              onUpdate();
            } else if (updateInfo.updateUrl != null) {
              await _launchUrl(updateInfo.updateUrl!);
            }
          },
          icon: const Icon(Icons.download, size: 18),
          label: Text(updateText),
        ),
      ],
      actionsAlignment: MainAxisAlignment.center,
    );
  }

  /// Build Cupertino dialog (iOS/macOS style)
  Widget _buildCupertinoDialog(
    BuildContext context, {
    required UpdateInfo updateInfo,
    required String title,
    required String message,
    required String cancelText,
    required String updateText,
    required bool showSkipVersion,
    required bool showDoNotAskAgain,
    required bool showReleaseNotes,
    required bool isPersistent,
    required VoidCallback? onCancel,
    required VoidCallback? onUpdate,
    required VoidCallback? onSkipVersion,
    required VoidCallback? onDoNotAskAgain,
  }) {
    final urgencyColor = updateInfo.urgency == UpdateUrgency.critical
        ? CupertinoColors.systemRed
        : CupertinoColors.systemBlue;

    return CupertinoAlertDialog(
      title: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: urgencyColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              updateInfo.urgency == UpdateUrgency.critical
                  ? CupertinoIcons.exclamationmark_circle_fill
                  : CupertinoIcons.arrow_down_circle_fill,
              size: 36,
              color: urgencyColor,
            ),
          ),
          Text(title),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Text(message),
          if (showReleaseNotes && updateInfo.releaseNotes != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey6,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    config.strings.releaseNotesTitle,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    updateInfo.releaseNotes!,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
          if (showSkipVersion || showDoNotAskAgain) ...[
            const SizedBox(height: 16),
            if (showSkipVersion)
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: onSkipVersion,
                child: Text(
                  config.strings.skipVersionButton,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            if (showDoNotAskAgain)
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: onDoNotAskAgain,
                child: Text(
                  config.strings.doNotAskAgainButton,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
          ],
        ],
      ),
      actions: [
        if (!isPersistent)
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              Navigator.of(context).pop();
              onCancel?.call();
            },
            child: Text(cancelText),
          ),
        CupertinoDialogAction(
          isDestructiveAction: false,
          onPressed: () async {
            Navigator.of(context).pop();
            if (onUpdate != null) {
              onUpdate();
            } else if (updateInfo.updateUrl != null) {
              await _launchUrl(updateInfo.updateUrl!);
            }
          },
          child: Text(updateText),
        ),
      ],
    );
  }

  /// Build Fluent Design dialog (Windows style)
  Widget _buildFluentDialog(
    BuildContext context, {
    required UpdateInfo updateInfo,
    required String title,
    required String message,
    required String cancelText,
    required String updateText,
    required bool showSkipVersion,
    required bool showDoNotAskAgain,
    required bool showReleaseNotes,
    required bool isPersistent,
    required VoidCallback? onCancel,
    required VoidCallback? onUpdate,
    required VoidCallback? onSkipVersion,
    required VoidCallback? onDoNotAskAgain,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final urgencyColor = _getUrgencyColor(updateInfo.urgency, context);
    final urgencyIcon = _getUrgencyIcon(updateInfo.urgency);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      elevation: 8,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 450, minWidth: 320),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: urgencyColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(
                    urgencyIcon,
                    color: urgencyColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.8),
                  ),
            ),
            if (showReleaseNotes && updateInfo.releaseNotes != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: colorScheme.outline.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      config.strings.releaseNotesTitle,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 150),
                      child: SingleChildScrollView(
                        child: Text(
                          updateInfo.releaseNotes!,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (showSkipVersion || showDoNotAskAgain) ...[
              const SizedBox(height: 16),
              if (showSkipVersion)
                InkWell(
                  onTap: onSkipVersion,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.skip_next,
                            size: 16, color: colorScheme.primary),
                        const SizedBox(width: 4),
                        Text(
                          config.strings.skipVersionButton,
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (showDoNotAskAgain)
                InkWell(
                  onTap: onDoNotAskAgain,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.notifications_off,
                            size: 16, color: colorScheme.primary),
                        const SizedBox(width: 4),
                        Text(
                          config.strings.doNotAskAgainButton,
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!isPersistent) ...[
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      onCancel?.call();
                    },
                    child: Text(cancelText),
                  ),
                  const SizedBox(width: 8),
                ],
                FilledButton(
                  style: FilledButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  onPressed: () async {
                    Navigator.of(context).pop();
                    if (onUpdate != null) {
                      onUpdate();
                    } else if (updateInfo.updateUrl != null) {
                      await _launchUrl(updateInfo.updateUrl!);
                    }
                  },
                  child: Text(updateText),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Build Adwaita dialog (Linux/GNOME style)
  Widget _buildAdwaitaDialog(
    BuildContext context, {
    required UpdateInfo updateInfo,
    required String title,
    required String message,
    required String cancelText,
    required String updateText,
    required bool showSkipVersion,
    required bool showDoNotAskAgain,
    required bool showReleaseNotes,
    required bool isPersistent,
    required VoidCallback? onCancel,
    required VoidCallback? onUpdate,
    required VoidCallback? onSkipVersion,
    required VoidCallback? onDoNotAskAgain,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final urgencyColor = _getUrgencyColor(updateInfo.urgency, context);
    final urgencyIcon = _getUrgencyIcon(updateInfo.urgency);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 450, minWidth: 320),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header bar (Adwaita style)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  if (!isPersistent)
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () {
                        Navigator.of(context).pop();
                        onCancel?.call();
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                    ),
                ],
              ),
            ),
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: urgencyColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        urgencyIcon,
                        size: 48,
                        color: urgencyColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    if (showReleaseNotes && updateInfo.releaseNotes != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              config.strings.releaseNotesTitle,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              updateInfo.releaseNotes!,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (showSkipVersion || showDoNotAskAgain) ...[
                      const SizedBox(height: 16),
                      if (showSkipVersion)
                        TextButton(
                          onPressed: onSkipVersion,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                          ),
                          child: Text(config.strings.skipVersionButton),
                        ),
                      if (showDoNotAskAgain)
                        TextButton(
                          onPressed: onDoNotAskAgain,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                          ),
                          child: Text(config.strings.doNotAskAgainButton),
                        ),
                    ],
                  ],
                ),
              ),
            ),
            // Action buttons (Adwaita style - full width at bottom)
            Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: colorScheme.outlineVariant,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  if (!isPersistent)
                    Expanded(
                      child: TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.only(
                              bottomLeft: Radius.circular(12),
                            ),
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                          onCancel?.call();
                        },
                        child: Text(cancelText),
                      ),
                    ),
                  if (!isPersistent)
                    Container(
                      width: 1,
                      height: 48,
                      color: colorScheme.outlineVariant,
                    ),
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        foregroundColor: colorScheme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.only(
                            bottomRight: const Radius.circular(12),
                            bottomLeft: isPersistent
                                ? const Radius.circular(12)
                                : Radius.zero,
                          ),
                        ),
                      ),
                      onPressed: () async {
                        Navigator.of(context).pop();
                        if (onUpdate != null) {
                          onUpdate();
                        } else if (updateInfo.updateUrl != null) {
                          await _launchUrl(updateInfo.updateUrl!);
                        }
                      },
                      child: Text(
                        updateText,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // DIALOG DISPLAY METHODS
  // ===========================================================================

  /// Show platform-appropriate update dialog.
  ///
  /// This method displays an update dialog with the specified options. If no
  /// [updateInfo] is provided, it will check for updates first.
  ///
  /// ```dart
  /// await appUpdater.showUpdateDialog(
  ///   context,
  ///   showSkipVersion: true,
  ///   showDoNotAskAgain: true,
  ///   showReleaseNotes: true,
  /// );
  /// ```
  Future<void> showUpdateDialog(
    BuildContext context, {
    UpdateInfo? updateInfo,
    String? title,
    String? message,
    String? cancelText,
    String? updateText,
    bool isDismissible = true,
    bool isPersistent = false,
    bool showSkipVersion = false,
    bool showDoNotAskAgain = false,
    bool showReleaseNotes = true,
    UpdateDialogStyle dialogStyle = UpdateDialogStyle.adaptive,
    Widget? customDialog,
    VoidCallback? onCancel,
    VoidCallback? onUpdate,
  }) async {
    // If no updateInfo provided, check for update first
    final info = updateInfo ?? await checkForUpdate();

    if (!info.updateAvailable) return;

    // Override persistence for mandatory updates
    final shouldBePersistent = isPersistent || info.isMandatory;

    // Check preferences if showSkipVersion or showDoNotAskAgain is enabled
    // But skip these checks for mandatory updates
    if (!info.isMandatory) {
      if (showSkipVersion && info.latestVersion != null) {
        final isSkipped =
            await UpdatePreferences.isVersionSkipped(info.latestVersion!);
        if (isSkipped) return;
      }

      if (showDoNotAskAgain) {
        final doNotAsk = await UpdatePreferences.isDoNotAskAgain();
        if (doNotAsk) return;
      }
    }

    // Check if context is still mounted
    if (!context.mounted) return;

    // Track analytics
    _trackEvent(
      UpdateAnalyticsEvent.dialogShown,
      latestVersion: info.latestVersion,
      urgency: info.urgency,
    );
    await UpdatePreferences.incrementUpdateImpressions();

    // Get localized strings
    final strings = config.strings;
    final defaultTitle = info.isMandatory
        ? strings.criticalUpdateTitle
        : strings.updateAvailableTitle;
    final defaultMessage = info.isMandatory
        ? strings.criticalUpdateMessage
        : strings.formatUpdateMessage(
            info.currentVersion, info.latestVersion ?? '');

    if (customDialog != null) {
      if (!context.mounted) return;
      await showDialog(
        context: context,
        barrierDismissible: isDismissible && !shouldBePersistent,
        builder: (dialogContext) => PopScope(
          canPop: isDismissible && !shouldBePersistent,
          child: customDialog,
        ),
      );
      return;
    }

    // Handle skip version callback
    void handleSkipVersion() {
      if (info.latestVersion != null) {
        UpdatePreferences.skipVersion(info.latestVersion!);
        _trackEvent(
          UpdateAnalyticsEvent.versionSkipped,
          latestVersion: info.latestVersion,
        );
      }
      Navigator.of(context).pop();
    }

    // Handle do not ask again callback
    void handleDoNotAskAgain() {
      UpdatePreferences.setDoNotAskAgain(true);
      _trackEvent(UpdateAnalyticsEvent.doNotAskAgain);
      Navigator.of(context).pop();
    }

    // Handle cancel callback
    void handleCancel() {
      UpdatePreferences.setLastDismissedTime(DateTime.now());
      UpdatePreferences.incrementUpdateDismissals();
      _trackEvent(
        UpdateAnalyticsEvent.updateDeclined,
        latestVersion: info.latestVersion,
      );
      onCancel?.call();
    }

    // Handle update callback
    void handleUpdate() {
      _trackEvent(
        UpdateAnalyticsEvent.updateAccepted,
        latestVersion: info.latestVersion,
      );
      _trackEvent(UpdateAnalyticsEvent.storeOpened);
      onUpdate?.call();
    }

    // Check mounted before building dialogs
    if (!context.mounted) return;

    // Determine which style to use
    final style = dialogStyle == UpdateDialogStyle.adaptive
        ? _getAdaptiveStyle(context)
        : dialogStyle;

    Widget dialog;
    switch (style) {
      case UpdateDialogStyle.cupertino:
        dialog = _buildCupertinoDialog(
          context,
          updateInfo: info,
          title: title ?? defaultTitle,
          message: message ?? defaultMessage,
          cancelText: cancelText ?? strings.laterButton,
          updateText: updateText ?? strings.updateButton,
          showSkipVersion: showSkipVersion && !info.isMandatory,
          showDoNotAskAgain: showDoNotAskAgain && !info.isMandatory,
          showReleaseNotes: showReleaseNotes,
          isPersistent: shouldBePersistent,
          onCancel: handleCancel,
          onUpdate: handleUpdate,
          onSkipVersion: handleSkipVersion,
          onDoNotAskAgain: handleDoNotAskAgain,
        );
        break;
      case UpdateDialogStyle.fluent:
        dialog = _buildFluentDialog(
          context,
          updateInfo: info,
          title: title ?? defaultTitle,
          message: message ?? defaultMessage,
          cancelText: cancelText ?? strings.laterButton,
          updateText: updateText ?? strings.updateButton,
          showSkipVersion: showSkipVersion && !info.isMandatory,
          showDoNotAskAgain: showDoNotAskAgain && !info.isMandatory,
          showReleaseNotes: showReleaseNotes,
          isPersistent: shouldBePersistent,
          onCancel: handleCancel,
          onUpdate: handleUpdate,
          onSkipVersion: handleSkipVersion,
          onDoNotAskAgain: handleDoNotAskAgain,
        );
        break;
      case UpdateDialogStyle.adwaita:
        dialog = _buildAdwaitaDialog(
          context,
          updateInfo: info,
          title: title ?? defaultTitle,
          message: message ?? defaultMessage,
          cancelText: cancelText ?? strings.laterButton,
          updateText: updateText ?? strings.updateButton,
          showSkipVersion: showSkipVersion && !info.isMandatory,
          showDoNotAskAgain: showDoNotAskAgain && !info.isMandatory,
          showReleaseNotes: showReleaseNotes,
          isPersistent: shouldBePersistent,
          onCancel: handleCancel,
          onUpdate: handleUpdate,
          onSkipVersion: handleSkipVersion,
          onDoNotAskAgain: handleDoNotAskAgain,
        );
        break;
      case UpdateDialogStyle.material:
      case UpdateDialogStyle.adaptive:
        dialog = _buildMaterialDialog(
          context,
          updateInfo: info,
          title: title ?? defaultTitle,
          message: message ?? defaultMessage,
          cancelText: cancelText ?? strings.laterButton,
          updateText: updateText ?? strings.updateButton,
          showSkipVersion: showSkipVersion && !info.isMandatory,
          showDoNotAskAgain: showDoNotAskAgain && !info.isMandatory,
          showReleaseNotes: showReleaseNotes,
          isPersistent: shouldBePersistent,
          onCancel: handleCancel,
          onUpdate: handleUpdate,
          onSkipVersion: handleSkipVersion,
          onDoNotAskAgain: handleDoNotAskAgain,
        );
        break;
    }

    // Wrap with PopScope for persistent dialogs
    if (shouldBePersistent) {
      dialog = PopScope(
        canPop: false,
        child: dialog,
      );
    }

    // Check mounted again before showing dialog
    if (!context.mounted) return;

    // Show dialog based on style
    if (style == UpdateDialogStyle.cupertino) {
      await showCupertinoDialog(
        context: context,
        barrierDismissible: isDismissible && !shouldBePersistent,
        builder: (context) => dialog,
      );
    } else {
      await showDialog(
        context: context,
        barrierDismissible: isDismissible && !shouldBePersistent,
        builder: (context) => dialog,
      );
    }
  }

  /// Check for update and show dialog if available.
  ///
  /// This is a convenience method that combines [checkForUpdate] and
  /// [showUpdateDialog]. Returns the [UpdateInfo] object.
  ///
  /// ```dart
  /// final updateInfo = await appUpdater.checkAndShowUpdateDialog(
  ///   context,
  ///   showSkipVersion: true,
  ///   showDoNotAskAgain: true,
  ///   onNoUpdate: () {
  ///     ScaffoldMessenger.of(context).showSnackBar(
  ///       const SnackBar(content: Text('App is up to date!')),
  ///     );
  ///   },
  /// );
  /// ```
  Future<UpdateInfo> checkAndShowUpdateDialog(
    BuildContext context, {
    String? title,
    String? message,
    String? cancelText,
    String? updateText,
    bool isDismissible = true,
    bool isPersistent = false,
    bool showSkipVersion = false,
    bool showDoNotAskAgain = false,
    bool showReleaseNotes = true,
    UpdateDialogStyle dialogStyle = UpdateDialogStyle.adaptive,
    Widget? customDialog,
    VoidCallback? onNoUpdate,
    VoidCallback? onCancel,
    VoidCallback? onUpdate,
  }) async {
    final updateInfo = await checkForUpdate();

    if (!updateInfo.updateAvailable) {
      onNoUpdate?.call();
      return updateInfo;
    }

    // Check preferences (but not for mandatory updates)
    if (!updateInfo.isMandatory) {
      if (showSkipVersion && updateInfo.latestVersion != null) {
        final isSkipped =
            await UpdatePreferences.isVersionSkipped(updateInfo.latestVersion!);
        if (isSkipped) {
          onNoUpdate?.call();
          return updateInfo;
        }
      }

      if (showDoNotAskAgain) {
        final doNotAsk = await UpdatePreferences.isDoNotAskAgain();
        if (doNotAsk) {
          onNoUpdate?.call();
          return updateInfo;
        }
      }
    }

    if (context.mounted) {
      await showUpdateDialog(
        context,
        updateInfo: updateInfo,
        title: title,
        message: message,
        cancelText: cancelText,
        updateText: updateText,
        isDismissible: isDismissible,
        isPersistent: isPersistent,
        showSkipVersion: showSkipVersion,
        showDoNotAskAgain: showDoNotAskAgain,
        showReleaseNotes: showReleaseNotes,
        dialogStyle: dialogStyle,
        customDialog: customDialog,
        onCancel: onCancel,
        onUpdate: onUpdate,
      );
    }

    return updateInfo;
  }

  // ===========================================================================
  // BACKGROUND CHECKING
  // ===========================================================================

  /// Start periodic background update checking.
  ///
  /// This method starts a timer that periodically checks for updates in the
  /// background. When an update is found, it will be emitted on [updateStream].
  ///
  /// ```dart
  /// // Start checking every hour
  /// appUpdater.startBackgroundChecking(Duration(hours: 1));
  ///
  /// // Listen for updates
  /// appUpdater.updateStream.listen((updateInfo) {
  ///   if (updateInfo.updateAvailable) {
  ///     // Show notification or update UI
  ///   }
  /// });
  /// ```
  void startBackgroundChecking(Duration interval) {
    stopBackgroundChecking(); // Cancel any existing timer

    _backgroundCheckTimer = Timer.periodic(interval, (_) async {
      final updateInfo = await checkForUpdate(respectFrequency: false);
      if (updateInfo.updateAvailable) {
        _updateStreamController.add(updateInfo);
      }
    });

    // Also perform an immediate check
    checkForUpdate(respectFrequency: false).then((updateInfo) {
      if (updateInfo.updateAvailable) {
        _updateStreamController.add(updateInfo);
      }
    });
  }

  /// Stop periodic background update checking.
  ///
  /// Call this to stop the background checking timer started by
  /// [startBackgroundChecking].
  void stopBackgroundChecking() {
    _backgroundCheckTimer?.cancel();
    _backgroundCheckTimer = null;
  }

  /// Perform a single background check and emit result on stream.
  ///
  /// Unlike [checkForUpdate], this method respects the check frequency
  /// and emits the result on [updateStream] instead of returning it.
  Future<void> performBackgroundCheck() async {
    final updateInfo = await checkForUpdate();
    if (updateInfo.updateAvailable) {
      _updateStreamController.add(updateInfo);
    }
  }

  // ===========================================================================
  // STORE OPERATIONS
  // ===========================================================================

  /// Open the app store for the current platform.
  ///
  /// Opens the appropriate store page based on platform and configuration:
  /// - iOS: App Store
  /// - Android: Play Store
  /// - macOS: Mac App Store
  /// - Windows: Microsoft Store
  /// - Linux: Snap Store or Flathub
  ///
  /// If GitHub releases are configured and no store URL is available,
  /// opens the GitHub releases page.
  Future<void> openStore() async {
    if (kIsWeb) {
      throw UnsupportedError('Cannot open store on web platform');
    }

    _trackEvent(UpdateAnalyticsEvent.storeOpened);

    final url = getStoreUrl();

    if (url != null) {
      await _launchUrl(url);
    } else {
      // Try to auto-detect Android package name
      if (Platform.isAndroid) {
        final packageName = await _getPackageName();
        await _launchUrl(
            'https://play.google.com/store/apps/details?id=$packageName');
      } else {
        throw UnsupportedError(
            'No store URL available for this platform or missing required ID');
      }
    }
  }

  /// Open TestFlight for iOS beta testing.
  ///
  /// Opens the TestFlight app or web page for the configured app.
  Future<void> openTestFlight() async {
    final url = getTestFlightUrl();
    if (url == null) {
      throw UnsupportedError('TestFlight not configured');
    }
    await _launchUrl(url);
  }
}

// =============================================================================
// BACKWARD COMPATIBILITY
// =============================================================================

/// Class to open app stores (for backward compatibility).
///
/// @deprecated Use [AppUpdater.openStore] instead.
class OpenStore {
  OpenStore._();
  static final OpenStore instance = OpenStore._();

  /// Opens the appropriate app store based on platform.
  Future<void> open({
    String? appName,
    String? appStoreId,
    String? androidAppBundleId,
    String? microsoftProductId,
    String? snapName,
    String? flathubAppId,
    LinuxStoreType linuxStoreType = LinuxStoreType.snap,
  }) async {
    final updater = AppUpdater.configure(
      iosAppId: appStoreId,
      macAppId: appStoreId,
      androidPackageName: androidAppBundleId,
      microsoftProductId: microsoftProductId,
      snapName: snapName,
      flathubAppId: flathubAppId,
      linuxStoreType: linuxStoreType,
    );
    await updater.openStore();
  }
}

/// Convenience function to open app store (for backward compatibility).
///
/// @deprecated Use [AppUpdater.openStore] instead.
Future<void> openAppStore({
  String? appName,
  String? iosAppId,
  String? appStoreId,
  String? androidAppBundleId,
  String? microsoftProductId,
  String? snapName,
  String? flathubAppId,
  LinuxStoreType linuxStoreType = LinuxStoreType.snap,
}) async {
  await OpenStore.instance.open(
    appName: appName,
    appStoreId: appStoreId ?? iosAppId,
    androidAppBundleId: androidAppBundleId,
    microsoftProductId: microsoftProductId,
    snapName: snapName,
    flathubAppId: flathubAppId,
    linuxStoreType: linuxStoreType,
  );
}
