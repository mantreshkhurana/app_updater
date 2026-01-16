# Changelog

All notable changes to this project will be documented in this file.

## 2.0.0

### New Features

- **Release Notes Display**: Automatically fetch and display release notes/changelogs in update dialogs
  - Fetches from App Store (iOS/macOS), Flathub (Linux), GitHub Releases, and custom endpoints
  - New `showReleaseNotes` parameter in `showUpdateDialog()` (enabled by default)
  - Release notes are displayed in a scrollable container within the dialog

- **Update Frequency Control**: Prevent checking for updates too frequently
  - New `checkFrequency` parameter in `AppUpdaterConfig` (e.g., `Duration(days: 1)`)
  - `checkForUpdate(respectFrequency: false)` to bypass frequency check
  - Automatically tracks last check time in preferences

- **Background/Silent Checking**: Check for updates without blocking the UI
  - New `startBackgroundChecking(Duration interval)` method for periodic checks
  - New `stopBackgroundChecking()` method to cancel background checks
  - New `updateStream` to listen for update notifications
  - New `performBackgroundCheck()` for single background check
  - New `dispose()` method to clean up resources

- **Force Update by Minimum Version**: Require users to update if below a version
  - New `minimumVersion` parameter in `AppUpdaterConfig`
  - Support for `minimumVersion` in custom JSON/XML endpoints
  - New `requiresForceUpdate` getter on `UpdateInfo`
  - Automatic `isPersistent: true` behavior when force update is required

- **Update Urgency Levels**: Communicate update importance to users
  - New `UpdateUrgency` enum: `low`, `medium`, `high`, `critical`
  - Dialog icon and color automatically change based on urgency
  - Support for `urgency` field in custom endpoints and Firebase Remote Config

- **Analytics & Callbacks**: Track user interactions with update dialogs
  - New `onAnalyticsEvent` callback in `AppUpdaterConfig`
  - New `UpdateAnalyticsEvent` class with `toMap()` for analytics services
  - Predefined event names: `dialogShown`, `updateAccepted`, `updateDeclined`, etc.
  - Track impressions and dismissals via `UpdatePreferences`

- **GitHub Releases Support**: Check for updates from GitHub releases
  - New `githubOwner` and `githubRepo` parameters in `AppUpdaterConfig`
  - New `githubIncludePrereleases` to include beta/prerelease versions
  - Automatically fetches version, release notes, and download URL
  - New `GitHubRelease` class for release metadata

- **TestFlight Support (iOS)**: Support beta updates via TestFlight
  - New `testFlightEnabled` parameter in `AppUpdaterConfig`
  - New `testFlightUrl` for custom TestFlight URLs
  - New `openTestFlight()` method to open TestFlight
  - New `getTestFlightUrl()` method

- **Firebase Remote Config Integration**: Dynamic version control via Firebase
  - New `firebaseRemoteConfigEnabled` parameter
  - New `FirebaseRemoteConfigSettings` class for key configuration
  - New `firebaseConfigFetcher` callback to fetch values
  - Support for all update parameters (version, minimumVersion, urgency, etc.)

- **Localization / i18n**: Built-in support for translations
  - New `UpdateStrings` class with all dialog text
  - New `strings` parameter in `AppUpdaterConfig`
  - Message placeholders: `{currentVersion}`, `{latestVersion}`
  - Includes all button text, titles, and error messages

- **Enhanced UpdateInfo**: More metadata about updates
  - New `releaseNotes` property for changelog text
  - New `urgency` property for update priority
  - New `minimumVersion` property
  - New `isMandatory` property
  - New `releaseDate` property
  - New `updateSizeBytes` and `formattedUpdateSize` properties
  - New `requiresForceUpdate` computed property
  - New `copyWith()` method

### Improvements

- **Enhanced UpdatePreferences**: New preference methods
  - `getLastCheckTime()` / `setLastCheckTime()` for frequency control
  - `shouldCheckForUpdate(Duration)` for frequency checking
  - `getUpdateImpressions()` / `incrementUpdateImpressions()` for analytics
  - `getUpdateDismissals()` / `incrementUpdateDismissals()` for analytics

- **Better Custom Endpoint Support**: Extended JSON/XML schema
  - Support for `releaseNotes` / `release_notes` / `changelog` fields
  - Support for `minimumVersion` / `minimum_version` fields
  - Support for `urgency` field (low, medium, high, critical)
  - Support for `mandatory` / `force_update` fields

- **Improved Dialog UI**: Visual enhancements
  - Urgency-based icon and color theming
  - Release notes section with scrollable content
  - Update size display when available
  - Better handling of long content

- **Code Quality**: Internal improvements
  - Comprehensive documentation comments on all public APIs
  - Better async/await handling with mounted checks
  - Proper resource cleanup with `dispose()` method

### Breaking Changes

- None - all existing APIs remain backward compatible

## 1.1.2

- Maintenance release with dependency updates.

## 1.1.1

- Fixed an issue where the "Do Not Ask Again" preference was not being saved correctly on some platforms.
- Improved version comparison logic to handle edge cases with pre-release versions.
- Updated dependencies to their latest versions for better compatibility and security.

## 1.1.0

- Removed outdated migration section from README.
- Documentation cleanup.

## 1.0.9

- Fixed App Store & Play Store version scraping to handle recent changes in store layouts.
- Improved compatibility with latest Flutter stable release.
- Minor performance optimizations in version checking logic.

## 1.0.8

- Fixed a bug where the "Do Not Ask Again" preference was not being respected on some platforms.
- Improved error handling when fetching version info from custom endpoints.
- Updated documentation with examples for new features introduced in 1.0.7.

## 1.0.7

### Breaking Changes

- Replaced `checkAppUpdate()` function with `AppUpdater` class for better architecture.
- New class-based API: Create an `AppUpdater` instance and call methods on it.
- Converted to pure Dart package (removed unnecessary native code).

### New Features

- **Full Desktop Support**:
  - macOS App Store version checking and store opening.
  - Microsoft Store version checking and store opening.
  - Linux Snap Store version checking and store opening.
  - Linux Flathub version checking and store opening.

- **Platform-Specific Dialog Styles**:
  - `UpdateDialogStyle.adaptive` - Automatically selects the best style for the current platform.
  - `UpdateDialogStyle.material` - Material Design 3 style (Android).
  - `UpdateDialogStyle.cupertino` - Native iOS/macOS style with SF Symbols.
  - `UpdateDialogStyle.fluent` - Fluent Design style (Windows).
  - `UpdateDialogStyle.adwaita` - GNOME/Adwaita style (Linux).

- **Persistent Dialogs**:
  - `isPersistent: true` - Creates a non-dismissible dialog for critical/forced updates.
  - User cannot dismiss with back button or tap outside.

- **"Do Not Ask Again" Feature**:
  - `showDoNotAskAgain: true` - Shows option to never show update dialog again.
  - Uses `SharedPreferences` to remember user's choice.
  - `UpdatePreferences.clearAll()` - Reset all stored preferences.

- **Skip Version Feature**:
  - `showSkipVersion: true` - Shows option to skip the current version.
  - Won't show dialog again for the skipped version.
  - `UpdatePreferences.clearSkippedVersion()` - Clear skipped version.

- **Custom Update Endpoints**:
  - `customXmlUrl` - Fetch version info from custom XML endpoint.
  - `customJsonUrl` - Fetch version info from custom JSON endpoint.

- **New `AppUpdater` Class**:
  - `AppUpdater.configure()` - Factory constructor with individual parameters.
  - `AppUpdater(config)` - Constructor with `AppUpdaterConfig` object.
  - `checkForUpdate()` - Check for updates without showing dialog.
  - `showUpdateDialog()` - Show update dialog with custom options.
  - `checkAndShowUpdateDialog()` - Combined check and show dialog.
  - `openStore()` - Open the appropriate app store.
  - `getStoreUrl()` - Get the store URL for the current platform.

- **New `UpdatePreferences` Class**:
  - `isVersionSkipped(version)` - Check if a version is skipped.
  - `skipVersion(version)` - Skip a specific version.
  - `isDoNotAskAgain()` - Check "do not ask again" preference.
  - `setDoNotAskAgain(value)` - Set "do not ask again" preference.
  - `clearAll()` - Clear all update preferences.
  - `clearSkippedVersion()` - Clear only the skipped version.

- **New `AppUpdaterConfig` Class**:
  - Configuration object for `AppUpdater` with all platform IDs.
  - `iosAppId` - iOS App Store app ID.
  - `macAppId` - macOS App Store app ID.
  - `androidPackageName` - Android package name (auto-detected if not provided).
  - `microsoftProductId` - Microsoft Store product ID.
  - `snapName` - Snap Store package name.
  - `flathubAppId` - Flathub app ID.
  - `linuxStoreType` - Choose between `LinuxStoreType.snap` or `LinuxStoreType.flathub`.

- **UpdateInfo Class**: Returns detailed update information including `currentVersion`, `latestVersion`, `updateUrl`, and `updateAvailable`.

### Improvements

- Improved dialog UI with icons and better styling for each platform.
- Better `mounted` checks to prevent BuildContext issues.
- Added `toString()` method to `UpdateInfo` for easier debugging.
- Proper semantic version comparison instead of simple string comparison.
- Platform-appropriate dialogs (Cupertino for iOS/macOS, Material for others).
- Cached `PackageInfo` for better performance.
- Better error handling with debug logging.
- Added pub.dev topics for better discoverability.

### Dependencies

- Updated to latest dependency versions:
  - `package_info_plus: ^9.0.0`
  - `flutter_lints: ^6.0.0`
  - `url_launcher: ^6.3.1`
  - `shared_preferences: ^2.3.4`
- Updated minimum SDK requirement to Dart 3.5.0 and Flutter 3.22.0.

## 1.0.6

- Bug fixes & improvements.

## 1.0.5

- Dependencies update.

## 1.0.4

- isDismissible parameter added.
- noUpdateCallback parameter added.

## 1.0.3

- Documentation update.

## 1.0.2

- Documentation update.

## 1.0.1

- Documentation update.

## 1.0.0

- Initial release.
- Prebuilt adaptive dialogs.
- Customizable adaptive dialogs.
