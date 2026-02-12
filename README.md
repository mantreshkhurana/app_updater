# App Updater

[![GitHub stars](https://img.shields.io/github/stars/mantreshkhurana/app_updater.svg?style=social)](https://github.com/mantreshkhurana/app_updater)
[![pub package](https://img.shields.io/pub/v/app_updater.svg)](https://pub.dartlang.org/packages/app_updater)

A comprehensive Flutter package to check for app updates and display platform-native dialogs. Supports iOS, Android, macOS, Windows, and Linux with adaptive UI for each platform.

| Platform | Dialog Style |
|----------|--------------|
| iOS | ![iOS Dialog](./screenshots/ios-screenshot.png) |
| Android | ![Android Dialog](./screenshots/android-screenshot.png) |
| macOS | ![macOS Dialog](./screenshots/macos-screenshot.png) |
| Windows | ![Windows Dialog](./screenshots/windows-screenshot.png) |
| Linux | ![Linux Dialog](./screenshots/linux-screenshot.png) |

## Features

### Core Features

- **Platform-Specific Dialogs**: Native UI for each platform (Material, Cupertino, Fluent, Adwaita)
- **Persistent Dialogs**: Force users to update with non-dismissible dialogs
- **Skip Version**: Let users skip specific versions
- **Do Not Ask Again**: Remember user's preference to not show update dialogs
- **Custom Endpoints**: Support for custom XML/JSON version endpoints

### New in v2.1.0

- **Private GitHub Repository Support**: Use `githubToken` or `githubHeaders` for private repos

### New in v2.0.0

- **Release Notes Display**: Show what's new in each update
- **Update Frequency Control**: Only check for updates every X days
- **Silent/Background Checking**: Check updates periodically without blocking UI
- **Force Update by Minimum Version**: Define minimum required version to force updates
- **Analytics/Callbacks**: Track update impressions, dismissals, and completions
- **TestFlight Support**: Support beta updates via TestFlight on iOS
- **GitHub Releases Support**: Check for updates from GitHub releases
- **Firebase Remote Config**: Integrate with Firebase for remote version control
- **Localization/i18n**: Built-in translations for dialog text
- **Update Urgency Levels**: Critical, high, medium, low update types
- **Changelog Fetching**: Auto-fetch and display changelogs from stores

### Supported Platforms

| Platform | Store | Dialog Style |
|----------|-------|--------------|
| iOS | App Store | Cupertino |
| Android | Play Store | Material Design 3 |
| macOS | Mac App Store | Cupertino |
| Windows | Microsoft Store | Fluent Design |
| Linux | Snap Store / Flathub | Adwaita (GNOME) |

## Installation

Add `app_updater` to your `pubspec.yaml`:

```yaml
dependencies:
  app_updater: ^2.1.0
```

## Quick Start

```dart
import 'package:app_updater/app_updater.dart';

// Create an AppUpdater instance
final appUpdater = AppUpdater.configure(
  iosAppId: '123456789',
  macAppId: '987654321',
  microsoftProductId: '9NBLGGH4NNS1',
  snapName: 'my-app',
  flathubAppId: 'com.example.myapp',
);

// Check for updates and show dialog
final updateInfo = await appUpdater.checkAndShowUpdateDialog(context);

if (updateInfo.updateAvailable) {
  print('New version available: ${updateInfo.latestVersion}');
  print('Release notes: ${updateInfo.releaseNotes}');
}
```

## Usage

### Basic Usage

```dart
// Create AppUpdater with configuration
final appUpdater = AppUpdater.configure(
  iosAppId: '123456789',
  // androidPackageName is auto-detected!
);

// Check and show dialog if update available
await appUpdater.checkAndShowUpdateDialog(context);
```

### All Platforms

```dart
final appUpdater = AppUpdater.configure(
  // Mobile
  iosAppId: '123456789',
  androidPackageName: 'com.example.app', // Optional - auto-detected
  // Desktop
  macAppId: '987654321',
  microsoftProductId: '9NBLGGH4NNS1',
  snapName: 'my-app',
  flathubAppId: 'com.example.myapp',
  linuxStoreType: LinuxStoreType.snap, // or LinuxStoreType.flathub
);
```

### Dialog Styles

The package provides 5 dialog styles that match each platform's design language:

```dart
await appUpdater.showUpdateDialog(
  context,
  dialogStyle: UpdateDialogStyle.adaptive, // Auto-selects based on platform
);

// Or force a specific style:
// UpdateDialogStyle.material   - Material Design 3 (Android)
// UpdateDialogStyle.cupertino  - iOS/macOS native
// UpdateDialogStyle.fluent     - Windows Fluent Design
// UpdateDialogStyle.adwaita    - Linux GNOME/Adwaita
```

### Persistent (Forced) Updates

For critical updates that users must install:

```dart
await appUpdater.checkAndShowUpdateDialog(
  context,
  isPersistent: true,  // Cannot be dismissed
  isDismissible: false,
  title: 'Critical Update Required',
  message: 'Please update to continue using the app.',
);
```

### Skip Version & Do Not Ask Again

Let users control update notifications:

```dart
await appUpdater.checkAndShowUpdateDialog(
  context,
  showSkipVersion: true,    // Shows "Skip this version" option
  showDoNotAskAgain: true,  // Shows "Don't remind me again" option
);
```

### Managing Preferences

```dart
// Check if user skipped a version
final isSkipped = await UpdatePreferences.isVersionSkipped('2.0.0');

// Check if user chose "do not ask again"
final doNotAsk = await UpdatePreferences.isDoNotAskAgain();

// Reset all preferences
await UpdatePreferences.clearAll();

// Reset only skipped version
await UpdatePreferences.clearSkippedVersion();

// Get analytics data
final impressions = await UpdatePreferences.getUpdateImpressions();
final dismissals = await UpdatePreferences.getUpdateDismissals();
```

---

## New Features

### Release Notes Display

Show what's new in the update dialog:

```dart
await appUpdater.checkAndShowUpdateDialog(
  context,
  showReleaseNotes: true, // Enabled by default
);

// Release notes are automatically fetched from:
// - App Store (iOS/macOS)
// - Flathub (Linux)
// - GitHub Releases
// - Custom JSON/XML endpoints
```

### Update Frequency Control

Prevent checking for updates too frequently:

```dart
final appUpdater = AppUpdater.configure(
  iosAppId: '123456789',
  checkFrequency: Duration(days: 1), // Only check once per day
);

// Manual check respecting frequency
final updateInfo = await appUpdater.checkForUpdate();

// Force check ignoring frequency
final updateInfo = await appUpdater.checkForUpdate(respectFrequency: false);
```

### Background/Silent Checking

Check for updates in the background without blocking the UI:

```dart
// Start periodic background checking
appUpdater.startBackgroundChecking(Duration(hours: 6));

// Listen for updates
appUpdater.updateStream.listen((updateInfo) {
  if (updateInfo.updateAvailable) {
    // Show notification or update badge
    showNotification('Update available: ${updateInfo.latestVersion}');
  }
});

// Stop background checking when done
appUpdater.stopBackgroundChecking();

// Don't forget to dispose
@override
void dispose() {
  appUpdater.dispose();
  super.dispose();
}
```

### Force Update by Minimum Version

Force updates when users are below a minimum version:

```dart
final appUpdater = AppUpdater.configure(
  iosAppId: '123456789',
  minimumVersion: '2.0.0', // Users below this MUST update
);

// Or via custom JSON endpoint:
// { "version": "2.5.0", "minimumVersion": "2.0.0" }

// Check if force update is required
final updateInfo = await appUpdater.checkForUpdate();
if (updateInfo.requiresForceUpdate) {
  // Show non-dismissible dialog
  await appUpdater.showUpdateDialog(context, isPersistent: true);
}
```

### Update Urgency Levels

Communicate update importance to users:

```dart
// Urgency levels: low, medium, high, critical
// Set via custom endpoints or Firebase Remote Config

// Custom JSON endpoint example:
// { "version": "2.5.0", "urgency": "critical" }

// The dialog icon and color change based on urgency
final updateInfo = await appUpdater.checkForUpdate();
print('Urgency: ${updateInfo.urgency}'); // UpdateUrgency.critical
```

### Analytics & Callbacks

Track user interactions with update dialogs:

```dart
final appUpdater = AppUpdater.configure(
  iosAppId: '123456789',
  onAnalyticsEvent: (event) {
    // Send to your analytics service
    analytics.logEvent(
      name: event.eventName,
      parameters: event.toMap(),
    );
  },
);

// Available events:
// - update_dialog_shown
// - update_accepted
// - update_declined
// - update_version_skipped
// - update_do_not_ask_again
// - update_check_started
// - update_check_completed
// - update_check_failed
// - update_store_opened
```

### GitHub Releases Support

Check for updates from GitHub releases:

```dart
final appUpdater = AppUpdater.configure(
  githubOwner: 'mycompany',
  githubRepo: 'myapp',
  githubIncludePrereleases: false, // Set to true for beta builds
);

// Automatically fetches:
// - Latest version from tag name
// - Release notes from body
// - Download URL from assets
```

### Private GitHub Repositories

For private repos, just pass your GitHub Personal Access Token:

```dart
final appUpdater = AppUpdater.configure(
  githubOwner: 'mycompany',
  githubRepo: 'private-app',
  githubToken: 'ghp_xxxxxxxxxxxxx', // That's it!
);
```

For GitHub Enterprise or advanced auth scenarios, use custom headers:

```dart
final appUpdater = AppUpdater.configure(
  githubOwner: 'mycompany',
  githubRepo: 'private-app',
  githubHeaders: {
    'Authorization': 'token ghp_xxxxxxxxxxxxx',
    'Accept': 'application/vnd.github+json',
    'X-GitHub-Api-Version': '2022-11-28',
  },
);
```

> **Note:** If both `githubToken` and `githubHeaders` are provided, values in `githubHeaders` take precedence for overlapping keys (e.g., `Authorization`).

### TestFlight Support (iOS)

Support beta updates via TestFlight:

```dart
final appUpdater = AppUpdater.configure(
  iosAppId: '123456789',
  testFlightEnabled: true,
  testFlightUrl: 'https://testflight.apple.com/join/ABC123', // Optional custom URL
);

// Open TestFlight for beta testing
await appUpdater.openTestFlight();
```

### Firebase Remote Config Integration

Use Firebase Remote Config for dynamic version control:

```dart
final appUpdater = AppUpdater.configure(
  firebaseRemoteConfigEnabled: true,
  firebaseSettings: FirebaseRemoteConfigSettings(
    minimumVersionKey: 'minimum_app_version',
    latestVersionKey: 'latest_app_version',
    updateUrlKey: 'app_update_url',
    releaseNotesKey: 'release_notes',
    urgencyKey: 'update_urgency',
    mandatoryKey: 'mandatory_update',
  ),
  firebaseConfigFetcher: () async {
    // Fetch from your Firebase Remote Config instance
    await FirebaseRemoteConfig.instance.fetchAndActivate();
    return {
      'minimum_app_version': FirebaseRemoteConfig.instance.getString('minimum_app_version'),
      'latest_app_version': FirebaseRemoteConfig.instance.getString('latest_app_version'),
      'app_update_url': FirebaseRemoteConfig.instance.getString('app_update_url'),
      'release_notes': FirebaseRemoteConfig.instance.getString('release_notes'),
      'update_urgency': FirebaseRemoteConfig.instance.getString('update_urgency'),
      'mandatory_update': FirebaseRemoteConfig.instance.getBool('mandatory_update'),
    };
  },
);
```

### Localization / i18n

Provide translations for all dialog text:

```dart
// Create localized strings
final frenchStrings = UpdateStrings(
  updateAvailableTitle: 'Mise à jour disponible',
  updateAvailableMessage: 'Une nouvelle version ({latestVersion}) est disponible. Vous avez actuellement la version {currentVersion}.',
  updateButton: 'Mettre à jour',
  laterButton: 'Plus tard',
  skipVersionButton: 'Ignorer cette version',
  doNotAskAgainButton: 'Ne plus me rappeler',
  criticalUpdateTitle: 'Mise à jour critique requise',
  criticalUpdateMessage: 'Cette mise à jour contient des correctifs importants.',
  releaseNotesTitle: 'Nouveautés',
  loadingText: 'Vérification des mises à jour...',
  errorText: 'Impossible de vérifier les mises à jour',
  upToDateText: 'Votre application est à jour !',
);

final appUpdater = AppUpdater.configure(
  iosAppId: '123456789',
  strings: frenchStrings,
);
```

---

## Custom Update Servers

### Custom JSON Endpoint

Host your own version endpoint:

```json
{
  "version": "2.0.0",
  "url": "https://example.com/download",
  "releaseNotes": "- New feature X\n- Bug fix Y",
  "minimumVersion": "1.5.0",
  "urgency": "high",
  "mandatory": false
}
```

```dart
final appUpdater = AppUpdater.configure(
  customJsonUrl: 'https://example.com/version.json',
);
```

### Custom XML Endpoint

```xml
<?xml version="1.0" encoding="UTF-8"?>
<app>
  <version>2.0.0</version>
  <url>https://example.com/download</url>
  <releaseNotes>New features and improvements</releaseNotes>
  <minimumVersion>1.5.0</minimumVersion>
  <urgency>high</urgency>
  <mandatory>false</mandatory>
</app>
```

```dart
final appUpdater = AppUpdater.configure(
  customXmlUrl: 'https://example.com/version.xml',
);
```

---

## Additional Methods

### Check Without Dialog

```dart
final updateInfo = await appUpdater.checkForUpdate();

print('Current: ${updateInfo.currentVersion}');
print('Latest: ${updateInfo.latestVersion}');
print('Update available: ${updateInfo.updateAvailable}');
print('Store URL: ${updateInfo.updateUrl}');
print('Release notes: ${updateInfo.releaseNotes}');
print('Urgency: ${updateInfo.urgency}');
print('Is mandatory: ${updateInfo.isMandatory}');
print('Requires force update: ${updateInfo.requiresForceUpdate}');
print('Update size: ${updateInfo.formattedUpdateSize}');
```

### Open Store

```dart
// Open the appropriate store for the current platform
await appUpdater.openStore();

// Or use the convenience function
await openAppStore(
  iosAppId: '123456789',
  microsoftProductId: '9NBLGGH4NNS1',
);
```

### Callbacks

```dart
await appUpdater.checkAndShowUpdateDialog(
  context,
  onNoUpdate: () {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('App is up to date!')),
    );
  },
  onUpdate: () {
    print('User chose to update');
  },
  onCancel: () {
    print('User cancelled');
  },
);
```

### Custom Dialog

```dart
await appUpdater.showUpdateDialog(
  context,
  customDialog: AlertDialog(
    title: const Text('Custom Update Dialog'),
    content: const Text('A new version is available!'),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Later'),
      ),
      FilledButton(
        onPressed: () {
          Navigator.pop(context);
          appUpdater.openStore();
        },
        child: const Text('Update'),
      ),
    ],
  ),
);
```

---

## API Reference

### AppUpdater

| Method | Description |
|--------|-------------|
| `AppUpdater.configure(...)` | Create instance with individual parameters |
| `AppUpdater(config)` | Create instance with `AppUpdaterConfig` |
| `checkForUpdate()` | Check for updates, returns `UpdateInfo` |
| `showUpdateDialog(context, ...)` | Show update dialog |
| `checkAndShowUpdateDialog(context, ...)` | Check and show dialog if update available |
| `openStore()` | Open the appropriate app store |
| `openTestFlight()` | Open TestFlight (iOS only) |
| `getStoreUrl()` | Get store URL for current platform |
| `getTestFlightUrl()` | Get TestFlight URL (iOS only) |
| `startBackgroundChecking(interval)` | Start periodic background checks |
| `stopBackgroundChecking()` | Stop background checks |
| `performBackgroundCheck()` | Perform single background check |
| `dispose()` | Clean up resources |

### AppUpdaterConfig

| Parameter | Type | Description |
|-----------|------|-------------|
| `iosAppId` | `String?` | iOS App Store app ID |
| `macAppId` | `String?` | macOS App Store app ID |
| `androidPackageName` | `String?` | Android package name (auto-detected) |
| `microsoftProductId` | `String?` | Microsoft Store product ID |
| `snapName` | `String?` | Snap Store package name |
| `flathubAppId` | `String?` | Flathub app ID |
| `customXmlUrl` | `String?` | Custom XML endpoint URL |
| `customJsonUrl` | `String?` | Custom JSON endpoint URL |
| `linuxStoreType` | `LinuxStoreType` | snap or flathub |
| `githubOwner` | `String?` | GitHub repository owner |
| `githubRepo` | `String?` | GitHub repository name |
| `githubIncludePrereleases` | `bool` | Include prereleases (default: false) |
| `githubToken` | `String?` | GitHub PAT for private repos |
| `githubHeaders` | `Map<String, String>?` | Custom HTTP headers for GitHub API |
| `testFlightEnabled` | `bool` | Enable TestFlight (default: false) |
| `testFlightUrl` | `String?` | Custom TestFlight URL |
| `firebaseRemoteConfigEnabled` | `bool` | Enable Firebase (default: false) |
| `firebaseSettings` | `FirebaseRemoteConfigSettings?` | Firebase config keys |
| `firebaseConfigFetcher` | `Function?` | Callback to fetch Firebase values |
| `checkFrequency` | `Duration?` | Minimum time between checks |
| `minimumVersion` | `String?` | Minimum required version |
| `onAnalyticsEvent` | `Function?` | Analytics callback |
| `strings` | `UpdateStrings` | Localized strings |

### UpdateDialogStyle

| Style | Platform | Description |
|-------|----------|-------------|
| `adaptive` | All | Auto-selects based on platform |
| `material` | Android | Material Design 3 |
| `cupertino` | iOS/macOS | Native Apple design |
| `fluent` | Windows | Microsoft Fluent Design |
| `adwaita` | Linux | GNOME/Adwaita style |

### UpdateUrgency

| Level | Description |
|-------|-------------|
| `low` | Minor improvements, can be skipped |
| `medium` | Regular updates with new features |
| `high` | Important updates, strongly recommended |
| `critical` | Security fixes or breaking changes |

### UpdateInfo

| Property | Type | Description |
|----------|------|-------------|
| `currentVersion` | `String` | Current app version |
| `latestVersion` | `String?` | Latest available version |
| `updateUrl` | `String?` | Store/download URL |
| `updateAvailable` | `bool` | Whether update is available |
| `releaseNotes` | `String?` | Release notes/changelog |
| `urgency` | `UpdateUrgency` | Update urgency level |
| `minimumVersion` | `String?` | Minimum required version |
| `isMandatory` | `bool` | Whether update is mandatory |
| `releaseDate` | `DateTime?` | Release date |
| `updateSizeBytes` | `int?` | Update size in bytes |
| `requiresForceUpdate` | `bool` | Whether force update is required |
| `formattedUpdateSize` | `String?` | Human-readable size (e.g., "15.2 MB") |

### UpdatePreferences

| Method | Description |
|--------|-------------|
| `isVersionSkipped(version)` | Check if version is skipped |
| `skipVersion(version)` | Skip a specific version |
| `isDoNotAskAgain()` | Check "do not ask again" preference |
| `setDoNotAskAgain(value)` | Set "do not ask again" preference |
| `getLastCheckTime()` | Get last update check time |
| `setLastCheckTime(time)` | Set last update check time |
| `shouldCheckForUpdate(frequency)` | Check if enough time has passed |
| `getUpdateImpressions()` | Get dialog impression count |
| `getUpdateDismissals()` | Get dismissal count |
| `clearAll()` | Clear all preferences |
| `clearSkippedVersion()` | Clear skipped version only |

### UpdateAnalyticsEvent

| Property | Type | Description |
|----------|------|-------------|
| `eventName` | `String` | Event name |
| `currentVersion` | `String` | Current app version |
| `latestVersion` | `String?` | Latest available version |
| `urgency` | `UpdateUrgency?` | Update urgency |
| `platform` | `String` | Platform name |
| `timestamp` | `DateTime` | Event timestamp |
| `toMap()` | `Map` | Convert to map for analytics |

### UpdateStrings

| Property | Type | Description |
|----------|------|-------------|
| `updateAvailableTitle` | `String` | Dialog title |
| `updateAvailableMessage` | `String` | Dialog message (supports placeholders) |
| `updateButton` | `String` | Update button text |
| `laterButton` | `String` | Later button text |
| `skipVersionButton` | `String` | Skip version button text |
| `doNotAskAgainButton` | `String` | Do not ask again button text |
| `criticalUpdateTitle` | `String` | Critical update title |
| `criticalUpdateMessage` | `String` | Critical update message |
| `releaseNotesTitle` | `String` | Release notes section title |
| `loadingText` | `String` | Loading text |
| `errorText` | `String` | Error text |
| `upToDateText` | `String` | Up to date text |

---

## Notes

- Update dialogs won't work on iOS Simulator (no App Store)
- Android package name is auto-detected if not provided
- Custom endpoints take priority over store checks
- Firebase Remote Config takes highest priority when enabled
- GitHub releases are checked before platform stores
- Private GitHub repos require `githubToken` or `githubHeaders` for authentication
- Release notes are automatically fetched from supported sources
- Background checking requires calling `dispose()` when done

## Credits

- [url_launcher](https://pub.dev/packages/url_launcher)
- [package_info_plus](https://pub.dev/packages/package_info_plus)
- [shared_preferences](https://pub.dev/packages/shared_preferences)

## Author

- [Mantresh Khurana](https://github.com/mantreshkhurana)
