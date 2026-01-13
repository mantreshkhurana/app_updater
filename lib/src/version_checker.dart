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

/// Enum to specify the Linux store type
enum LinuxStoreType {
  snap,
  flathub,
}

/// Enum to specify the update dialog style
enum UpdateDialogStyle {
  /// Adaptive style based on platform
  adaptive,

  /// Material Design style (Android-like)
  material,

  /// Cupertino style (iOS-like)
  cupertino,

  /// Fluent Design style (Windows-like)
  fluent,

  /// GNOME/Adwaita style (Linux-like)
  adwaita,
}

/// Result of version check containing version info and update URL
class UpdateInfo {
  final String currentVersion;
  final String? latestVersion;
  final String? updateUrl;
  final bool updateAvailable;

  UpdateInfo({
    required this.currentVersion,
    this.latestVersion,
    this.updateUrl,
    required this.updateAvailable,
  });

  @override
  String toString() {
    return 'UpdateInfo(currentVersion: $currentVersion, latestVersion: $latestVersion, updateUrl: $updateUrl, updateAvailable: $updateAvailable)';
  }
}

/// Preferences manager for update dialog settings
class UpdatePreferences {
  static const String _keySkippedVersion = 'app_updater_skipped_version';
  static const String _keyDoNotAskAgain = 'app_updater_do_not_ask_again';
  static const String _keyLastDismissedTime = 'app_updater_last_dismissed_time';

  /// Check if user has chosen to skip a specific version
  static Future<bool> isVersionSkipped(String version) async {
    final prefs = await SharedPreferences.getInstance();
    final skippedVersion = prefs.getString(_keySkippedVersion);
    return skippedVersion == version;
  }

  /// Skip a specific version (won't show dialog for this version again)
  static Future<void> skipVersion(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySkippedVersion, version);
  }

  /// Check if user has chosen "do not ask again"
  static Future<bool> isDoNotAskAgain() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyDoNotAskAgain) ?? false;
  }

  /// Set "do not ask again" preference
  static Future<void> setDoNotAskAgain(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDoNotAskAgain, value);
  }

  /// Get last dismissed time
  static Future<DateTime?> getLastDismissedTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt(_keyLastDismissedTime);
    return timestamp != null
        ? DateTime.fromMillisecondsSinceEpoch(timestamp)
        : null;
  }

  /// Set last dismissed time
  static Future<void> setLastDismissedTime(DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyLastDismissedTime, time.millisecondsSinceEpoch);
  }

  /// Clear all update preferences (reset)
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySkippedVersion);
    await prefs.remove(_keyDoNotAskAgain);
    await prefs.remove(_keyLastDismissedTime);
  }

  /// Clear skipped version only
  static Future<void> clearSkippedVersion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySkippedVersion);
  }
}

/// Configuration class for AppUpdater
class AppUpdaterConfig {
  /// iOS App Store app ID
  final String? iosAppId;

  /// macOS App Store app ID
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
  });
}

/// Main class for checking and managing app updates across all platforms
class AppUpdater {
  final AppUpdaterConfig config;

  static PackageInfo? _cachedPackageInfo;

  /// Create an AppUpdater instance with the given configuration
  AppUpdater(this.config);

  /// Create an AppUpdater with individual parameters (convenience constructor)
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
    ));
  }

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

  /// Fetch latest version from iOS App Store
  static Future<String?> _getLatestVersionFromAppStore(String appId) async {
    try {
      final url = 'https://itunes.apple.com/lookup?id=$appId';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['resultCount'] > 0) {
          return json['results'][0]['version'];
        }
      }
    } catch (e) {
      debugPrint('Error fetching App Store version: $e');
    }
    return null;
  }

  /// Fetch latest version from macOS App Store
  static Future<String?> _getLatestVersionFromMacAppStore(String appId) async {
    try {
      final url = 'https://itunes.apple.com/lookup?id=$appId';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['resultCount'] > 0) {
          return json['results'][0]['version'];
        }
      }
    } catch (e) {
      debugPrint('Error fetching Mac App Store version: $e');
    }
    return null;
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
        // Matches: ]]],"2.25.37.76",null or ]]],"1.0.29",null
        final pattern1 = RegExp(r'\]\]\],"(\d+\.\d+\.\d+(?:\.\d+)?)",null');

        // Pattern 2: Version in array followed by null values
        // Matches: ,"1.2.3",null,null,null
        final pattern2 = RegExp(r',"(\d+\.\d+\.\d+(?:\.\d+)?)",null,null');

        // Pattern 3: Version after array end with specific structure
        // Matches: "]]],"1.2.3"
        final pattern3 = RegExp(r'"\]\]\],"(\d+\.\d+\.\d+(?:\.\d+)?)"');

        // Pattern 4: Look for version in nested arrays
        final pattern4 = RegExp(r'\[\["(\d+\.\d+\.\d+(?:\.\d+)?)"\]\]');

        // Pattern 5: Version followed by null array pattern
        final pattern5 = RegExp(r'"(\d+\.\d+\.\d+(?:\.\d+)?)",\[null,null');

        // Try each pattern in order of reliability
        for (final pattern in [pattern1, pattern2, pattern3, pattern5, pattern4]) {
          final match = pattern.firstMatch(body);
          if (match != null) {
            final version = match.group(1);
            if (version != null && _isValidVersion(version)) {
              return version;
            }
          }
        }

        // Fallback: Find all version-like strings and return the most likely one
        // Look for versions with 3 or 4 parts (e.g., 1.2.3 or 1.2.3.4)
        final allVersions =
            RegExp(r'"(\d+\.\d+\.\d+(?:\.\d+)?)"').allMatches(body);
        final versionCounts = <String, int>{};
        for (final match in allVersions) {
          final version = match.group(1);
          if (version != null && _isValidVersion(version)) {
            versionCounts[version] = (versionCounts[version] ?? 0) + 1;
          }
        }

        // Return the version that appears most frequently (likely the app version)
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

    // Check that each part is a reasonable number (not too large)
    for (final part in parts) {
      final num = int.tryParse(part);
      if (num == null || num < 0 || num > 9999) return false;
    }

    // Filter out versions that are likely timestamps or other numbers
    // (e.g., years like 2024, or very large numbers)
    final firstPart = int.tryParse(parts.first);
    if (firstPart != null && firstPart > 999) return false;

    return true;
  }

  /// Fetch latest version from Microsoft Store
  static Future<String?> _getLatestVersionFromMicrosoftStore(
      String productId) async {
    try {
      // Microsoft Store API endpoint
      final url =
          'https://storeedgefd.dsx.mp.microsoft.com/v9.0/products/$productId?market=US&locale=en-US';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        // Navigate through the response to find version
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
          // Find the stable channel
          for (var channel in channelMap) {
            if (channel['channel']?['name'] == 'stable') {
              return channel['version'];
            }
          }
          // If no stable, return first available
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
  static Future<String?> _getLatestVersionFromFlathub(String appId) async {
    try {
      final url = 'https://flathub.org/api/v2/appstream/$appId';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        // Flathub returns releases array
        if (json['releases'] != null) {
          final releases = json['releases'] as List;
          if (releases.isNotEmpty) {
            return releases[0]['version'];
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching Flathub version: $e');
    }
    return null;
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
        final versionElement =
            versionElements.isNotEmpty ? versionElements.first : null;
        final urlElement = urlElements.isNotEmpty ? urlElements.first : null;
        return {
          'version': versionElement?.innerText,
          'url': urlElement?.innerText,
        };
      }
    } catch (e) {
      debugPrint('Error fetching XML version: $e');
    }
    return {'version': null, 'url': null};
  }

  /// Fetch latest version from custom JSON endpoint
  static Future<Map<String, String?>> _getLatestVersionFromJSON(
      String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return {
          'version': json['version']?.toString(),
          'url': json['url']?.toString(),
        };
      }
    } catch (e) {
      debugPrint('Error fetching JSON version: $e');
    }
    return {'version': null, 'url': null};
  }

  /// Compare two version strings (returns true if latestVersion is newer)
  static bool _isNewerVersion(String currentVersion, String latestVersion) {
    try {
      final current = currentVersion.split('.').map(int.parse).toList();
      final latest = latestVersion.split('.').map(int.parse).toList();

      // Pad shorter version with zeros
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
      // Fallback to string comparison if parsing fails
      return currentVersion != latestVersion;
    }
  }

  /// Get the store URL for the current platform
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
    return null;
  }

  /// Check for updates and return UpdateInfo
  Future<UpdateInfo> checkForUpdate() async {
    final currentVersion = await _getCurrentVersion();
    String? latestVersion;
    String? updateUrl;

    // Check custom endpoints first (they take priority)
    if (config.customXmlUrl != null) {
      final result = await _getLatestVersionFromXML(config.customXmlUrl!);
      latestVersion = result['version'];
      updateUrl = result['url'];
    } else if (config.customJsonUrl != null) {
      final result = await _getLatestVersionFromJSON(config.customJsonUrl!);
      latestVersion = result['version'];
      updateUrl = result['url'];
    } else if (!kIsWeb) {
      // Platform-specific store checks
      if (Platform.isIOS && config.iosAppId != null) {
        latestVersion = await _getLatestVersionFromAppStore(config.iosAppId!);
        updateUrl = 'https://apps.apple.com/app/id${config.iosAppId}';
      } else if (Platform.isMacOS && config.macAppId != null) {
        latestVersion =
            await _getLatestVersionFromMacAppStore(config.macAppId!);
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
          latestVersion =
              await _getLatestVersionFromFlathub(config.flathubAppId!);
          updateUrl = 'https://flathub.org/apps/${config.flathubAppId}';
        }
      }
    }

    final updateAvailable = latestVersion != null &&
        _isNewerVersion(currentVersion, latestVersion);

    return UpdateInfo(
      currentVersion: currentVersion,
      latestVersion: latestVersion,
      updateUrl: updateUrl,
      updateAvailable: updateAvailable,
    );
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

  /// Build Material Design dialog (Android style)
  static Widget _buildMaterialDialog(
    BuildContext context, {
    required UpdateInfo updateInfo,
    required String title,
    required String message,
    required String cancelText,
    required String updateText,
    required bool showSkipVersion,
    required bool showDoNotAskAgain,
    required bool isPersistent,
    required VoidCallback? onCancel,
    required VoidCallback? onUpdate,
    required VoidCallback? onSkipVersion,
    required VoidCallback? onDoNotAskAgain,
  }) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      icon: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.system_update,
          size: 32,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
      title: Text(
        title,
        textAlign: TextAlign.center,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
          ),
          if (showSkipVersion || showDoNotAskAgain) ...[
            const SizedBox(height: 16),
            if (showSkipVersion)
              TextButton.icon(
                onPressed: onSkipVersion,
                icon: const Icon(Icons.skip_next, size: 18),
                label: const Text('Skip this version'),
              ),
            if (showDoNotAskAgain)
              TextButton.icon(
                onPressed: onDoNotAskAgain,
                icon: const Icon(Icons.notifications_off, size: 18),
                label: const Text('Don\'t remind me again'),
              ),
          ],
        ],
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
  static Widget _buildCupertinoDialog(
    BuildContext context, {
    required UpdateInfo updateInfo,
    required String title,
    required String message,
    required String cancelText,
    required String updateText,
    required bool showSkipVersion,
    required bool showDoNotAskAgain,
    required bool isPersistent,
    required VoidCallback? onCancel,
    required VoidCallback? onUpdate,
    required VoidCallback? onSkipVersion,
    required VoidCallback? onDoNotAskAgain,
  }) {
    return CupertinoAlertDialog(
      title: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: CupertinoColors.systemBlue.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              CupertinoIcons.arrow_down_circle_fill,
              size: 36,
              color: CupertinoColors.systemBlue,
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
          if (showSkipVersion || showDoNotAskAgain) ...[
            const SizedBox(height: 16),
            if (showSkipVersion)
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: onSkipVersion,
                child: const Text(
                  'Skip this version',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            if (showDoNotAskAgain)
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: onDoNotAskAgain,
                child: const Text(
                  'Don\'t remind me again',
                  style: TextStyle(fontSize: 13),
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
  static Widget _buildFluentDialog(
    BuildContext context, {
    required UpdateInfo updateInfo,
    required String title,
    required String message,
    required String cancelText,
    required String updateText,
    required bool showSkipVersion,
    required bool showDoNotAskAgain,
    required bool isPersistent,
    required VoidCallback? onCancel,
    required VoidCallback? onUpdate,
    required VoidCallback? onSkipVersion,
    required VoidCallback? onDoNotAskAgain,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      elevation: 8,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400, minWidth: 320),
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
                    color: colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(
                    Icons.system_update_alt,
                    color: colorScheme.primary,
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
                          'Skip this version',
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
                          'Don\'t remind me again',
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
  static Widget _buildAdwaitaDialog(
    BuildContext context, {
    required UpdateInfo updateInfo,
    required String title,
    required String message,
    required String cancelText,
    required String updateText,
    required bool showSkipVersion,
    required bool showDoNotAskAgain,
    required bool isPersistent,
    required VoidCallback? onCancel,
    required VoidCallback? onUpdate,
    required VoidCallback? onSkipVersion,
    required VoidCallback? onDoNotAskAgain,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400, minWidth: 320),
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
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.system_update,
                      size: 48,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  if (showSkipVersion || showDoNotAskAgain) ...[
                    const SizedBox(height: 16),
                    if (showSkipVersion)
                      TextButton(
                        onPressed: onSkipVersion,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                        ),
                        child: const Text('Skip this version'),
                      ),
                    if (showDoNotAskAgain)
                      TextButton(
                        onPressed: onDoNotAskAgain,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                        ),
                        child: const Text('Don\'t remind me again'),
                      ),
                  ],
                ],
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

  /// Show platform-appropriate update dialog
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
    UpdateDialogStyle dialogStyle = UpdateDialogStyle.adaptive,
    Widget? customDialog,
    VoidCallback? onCancel,
    VoidCallback? onUpdate,
  }) async {
    // If no updateInfo provided, check for update first
    final info = updateInfo ?? await checkForUpdate();

    if (!info.updateAvailable) return;

    // Check preferences if showSkipVersion or showDoNotAskAgain is enabled
    if (showSkipVersion && info.latestVersion != null) {
      final isSkipped =
          await UpdatePreferences.isVersionSkipped(info.latestVersion!);
      if (isSkipped) return;
    }

    if (showDoNotAskAgain) {
      final doNotAsk = await UpdatePreferences.isDoNotAskAgain();
      if (doNotAsk) return;
    }

    // Check if context is still mounted
    if (!context.mounted) return;

    const defaultTitle = 'Update Available';
    final defaultMessage =
        'A new version (${info.latestVersion}) is available. You are currently on version ${info.currentVersion}.';
    const defaultCancelText = 'Later';
    const defaultUpdateText = 'Update Now';

    if (customDialog != null) {
      await showDialog(
        context: context,
        barrierDismissible: isDismissible && !isPersistent,
        builder: (context) => PopScope(
          canPop: isDismissible && !isPersistent,
          child: customDialog,
        ),
      );
      return;
    }

    // Handle skip version callback
    void handleSkipVersion() {
      if (info.latestVersion != null) {
        UpdatePreferences.skipVersion(info.latestVersion!);
      }
      Navigator.of(context).pop();
    }

    // Handle do not ask again callback
    void handleDoNotAskAgain() {
      UpdatePreferences.setDoNotAskAgain(true);
      Navigator.of(context).pop();
    }

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
          cancelText: cancelText ?? defaultCancelText,
          updateText: updateText ?? defaultUpdateText,
          showSkipVersion: showSkipVersion,
          showDoNotAskAgain: showDoNotAskAgain,
          isPersistent: isPersistent,
          onCancel: onCancel,
          onUpdate: onUpdate,
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
          cancelText: cancelText ?? defaultCancelText,
          updateText: updateText ?? defaultUpdateText,
          showSkipVersion: showSkipVersion,
          showDoNotAskAgain: showDoNotAskAgain,
          isPersistent: isPersistent,
          onCancel: onCancel,
          onUpdate: onUpdate,
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
          cancelText: cancelText ?? defaultCancelText,
          updateText: updateText ?? defaultUpdateText,
          showSkipVersion: showSkipVersion,
          showDoNotAskAgain: showDoNotAskAgain,
          isPersistent: isPersistent,
          onCancel: onCancel,
          onUpdate: onUpdate,
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
          cancelText: cancelText ?? defaultCancelText,
          updateText: updateText ?? defaultUpdateText,
          showSkipVersion: showSkipVersion,
          showDoNotAskAgain: showDoNotAskAgain,
          isPersistent: isPersistent,
          onCancel: onCancel,
          onUpdate: onUpdate,
          onSkipVersion: handleSkipVersion,
          onDoNotAskAgain: handleDoNotAskAgain,
        );
        break;
    }

    // Wrap with PopScope for persistent dialogs
    if (isPersistent) {
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
        barrierDismissible: isDismissible && !isPersistent,
        builder: (context) => dialog,
      );
    } else {
      await showDialog(
        context: context,
        barrierDismissible: isDismissible && !isPersistent,
        builder: (context) => dialog,
      );
    }
  }

  /// Check for update and show dialog if available
  /// Returns the UpdateInfo object
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

    // Check preferences
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
        dialogStyle: dialogStyle,
        customDialog: customDialog,
        onCancel: onCancel,
        onUpdate: onUpdate,
      );
    }

    return updateInfo;
  }

  /// Open the app store for the current platform
  Future<void> openStore() async {
    if (kIsWeb) {
      throw UnsupportedError('Cannot open store on web platform');
    }

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
}

/// Class to open app stores (for backward compatibility)
class OpenStore {
  OpenStore._();
  static final OpenStore instance = OpenStore._();

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

/// Convenience function to open app store (for backward compatibility)
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
