import 'dart:async';

import 'package:app_updater/app_updater.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  // Create AppUpdater instance with all new features configured
  late final AppUpdater appUpdater;

  // Stream subscription for background updates
  StreamSubscription<UpdateInfo>? _updateSubscription;

  // Track if background checking is active
  bool _isBackgroundCheckingActive = false;

  @override
  void initState() {
    super.initState();

    // Initialize AppUpdater with new features
    appUpdater = AppUpdater.configure(
      // Mobile
      iosAppId: '123456789',
      // androidPackageName is auto-detected!

      // Desktop
      macAppId: '987654321',
      microsoftProductId: '9NBLGGH4NNS1',
      snapName: 'example-app',
      flathubAppId: 'com.example.app',
      linuxStoreType: LinuxStoreType.snap,

      // GitHub Releases support
      githubOwner: 'mantreshkhurana',
      githubRepo: 'app_updater',
      githubIncludePrereleases: false,

      // Update frequency control - only check once per day
      checkFrequency: const Duration(days: 1),

      // Force update if below this version
      minimumVersion: '1.0.0',

      // Analytics callback
      onAnalyticsEvent: (event) {
        debugPrint('Analytics Event: ${event.eventName}');
        debugPrint('  Platform: ${event.platform}');
        debugPrint('  Current Version: ${event.currentVersion}');
        if (event.latestVersion != null) {
          debugPrint('  Latest Version: ${event.latestVersion}');
        }
        if (event.urgency != null) {
          debugPrint('  Urgency: ${event.urgency}');
        }
      },

      // Localized strings (using default English)
      strings: const UpdateStrings(),
    );

    // Check for updates on app start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForUpdates();
    });
  }

  @override
  void dispose() {
    // Clean up resources
    _updateSubscription?.cancel();
    appUpdater.dispose();
    super.dispose();
  }

  // Mock UpdateInfo for demonstrations with release notes
  UpdateInfo _createMockUpdateInfo({
    UpdateUrgency urgency = UpdateUrgency.medium,
    bool isMandatory = false,
    String? releaseNotes,
  }) {
    return UpdateInfo(
      currentVersion: '1.0.0',
      latestVersion: '2.0.0',
      updateUrl: 'https://example.com',
      updateAvailable: true,
      urgency: urgency,
      isMandatory: isMandatory,
      releaseNotes: releaseNotes ??
          '• New dark mode support\n'
              '• Performance improvements\n'
              '• Bug fixes and stability improvements\n'
              '• Updated UI components',
      releaseDate: DateTime.now().subtract(const Duration(days: 2)),
      updateSizeBytes: 15728640, // 15 MB
    );
  }

  Future<void> _resetPreferences() async {
    await UpdatePreferences.clearAll();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Update preferences have been reset')),
    );
  }

  Future<void> _checkForUpdates() async {
    final updateInfo = await appUpdater.checkAndShowUpdateDialog(
      context,
      showSkipVersion: true,
      showDoNotAskAgain: true,
      showReleaseNotes: true,
      isDismissible: true,
      dialogStyle: UpdateDialogStyle.adaptive,
      onNoUpdate: () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('App is up to date!')),
          );
        }
      },
      onUpdate: () => debugPrint('User chose to update'),
      onCancel: () => debugPrint('User cancelled update'),
    );

    debugPrint('Current version: ${updateInfo.currentVersion}');
    debugPrint('Latest version: ${updateInfo.latestVersion}');
    debugPrint('Update available: ${updateInfo.updateAvailable}');
    debugPrint('Release notes: ${updateInfo.releaseNotes}');
    debugPrint('Urgency: ${updateInfo.urgency}');
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _toggleBackgroundChecking() {
    setState(() {
      if (_isBackgroundCheckingActive) {
        // Stop background checking
        appUpdater.stopBackgroundChecking();
        _updateSubscription?.cancel();
        _updateSubscription = null;
        _isBackgroundCheckingActive = false;
        _showSnackBar('Background checking stopped');
      } else {
        // Start background checking every 30 seconds (for demo purposes)
        appUpdater.startBackgroundChecking(const Duration(seconds: 30));

        // Listen for updates
        _updateSubscription = appUpdater.updateStream.listen((updateInfo) {
          if (updateInfo.updateAvailable && mounted) {
            _showSnackBar(
                'Background check: Update ${updateInfo.latestVersion} available!');
          }
        });

        _isBackgroundCheckingActive = true;
        _showSnackBar('Background checking started (every 30s)');
      }
    });
  }

  Future<void> _showAnalyticsStats() async {
    final impressions = await UpdatePreferences.getUpdateImpressions();
    final dismissals = await UpdatePreferences.getUpdateDismissals();
    final lastCheck = await UpdatePreferences.getLastCheckTime();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Analytics'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dialog Impressions: $impressions'),
            const SizedBox(height: 8),
            Text('Dialog Dismissals: $dismissals'),
            const SizedBox(height: 8),
            Text(
                'Last Check: ${lastCheck?.toString().split('.').first ?? 'Never'}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('App Updater Example'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics),
            tooltip: 'View analytics',
            onPressed: _showAnalyticsStats,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset update preferences',
            onPressed: _resetPreferences,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            const Icon(
              Icons.system_update,
              size: 64,
              color: Colors.blue,
            ),
            const SizedBox(height: 16),
            const Text(
              'App Updater v2.0 Demo',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap the buttons below to preview update dialogs and new features',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),

            // New Features Section
            _buildSection(
              title: 'New Features (v2.0)',
              subtitle: 'Explore the new capabilities',
              children: [
                _buildFeatureButton(
                  label: 'With Release Notes',
                  subtitle: 'Shows changelog in dialog',
                  icon: Icons.article,
                  onPressed: () => _showDialogWithReleaseNotes(),
                ),
                _buildFeatureButton(
                  label: 'Urgency: Critical',
                  subtitle: 'Red icon, security update',
                  icon: Icons.error,
                  color: Colors.red,
                  onPressed: () => _showDialogWithUrgency(UpdateUrgency.critical),
                ),
                _buildFeatureButton(
                  label: 'Urgency: High',
                  subtitle: 'Orange icon, important',
                  icon: Icons.warning_amber,
                  color: Colors.orange,
                  onPressed: () => _showDialogWithUrgency(UpdateUrgency.high),
                ),
                _buildFeatureButton(
                  label: 'Urgency: Low',
                  subtitle: 'Grey icon, minor update',
                  icon: Icons.info_outline,
                  color: Colors.grey,
                  onPressed: () => _showDialogWithUrgency(UpdateUrgency.low),
                ),
                _buildFeatureButton(
                  label: 'Mandatory Update',
                  subtitle: 'Cannot skip or dismiss',
                  icon: Icons.lock,
                  color: Colors.red,
                  onPressed: () => _showMandatoryUpdate(),
                ),
                _buildFeatureButton(
                  label: 'Background Checking',
                  subtitle: _isBackgroundCheckingActive ? 'Active' : 'Inactive',
                  icon: _isBackgroundCheckingActive
                      ? Icons.sync
                      : Icons.sync_disabled,
                  color:
                      _isBackgroundCheckingActive ? Colors.green : Colors.grey,
                  onPressed: _toggleBackgroundChecking,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Platform-Specific Dialogs Section
            _buildSection(
              title: 'Platform Dialogs',
              subtitle: 'See how dialogs appear on each platform',
              children: [
                _buildPlatformButton(
                  label: 'iOS',
                  subtitle: 'Cupertino style',
                  icon: Icons.phone_iphone,
                  color: Colors.grey.shade800,
                  onPressed: () => _showDialogWithStyle(
                    UpdateDialogStyle.cupertino,
                    title: 'Update Available',
                    message:
                        'A new version of the app is available on the App Store.',
                  ),
                ),
                _buildPlatformButton(
                  label: 'Android',
                  subtitle: 'Material style',
                  icon: Icons.android,
                  color: Colors.green,
                  onPressed: () => _showDialogWithStyle(
                    UpdateDialogStyle.material,
                    title: 'Update Available',
                    message:
                        'A new version is available on the Google Play Store.',
                  ),
                ),
                _buildPlatformButton(
                  label: 'macOS',
                  subtitle: 'Cupertino style',
                  icon: Icons.apple,
                  color: Colors.grey.shade700,
                  onPressed: () => _showDialogWithStyle(
                    UpdateDialogStyle.cupertino,
                    title: 'Update Available',
                    message: 'A new version is available on the Mac App Store.',
                  ),
                ),
                _buildPlatformButton(
                  label: 'Windows',
                  subtitle: 'Fluent style',
                  icon: Icons.window,
                  color: Colors.blue,
                  onPressed: () => _showDialogWithStyle(
                    UpdateDialogStyle.fluent,
                    title: 'Update Available',
                    message:
                        'A new version is available on the Microsoft Store.',
                  ),
                ),
                _buildPlatformButton(
                  label: 'Linux',
                  subtitle: 'GNOME style',
                  icon: Icons.desktop_windows,
                  color: Colors.orange,
                  onPressed: () => _showDialogWithStyle(
                    UpdateDialogStyle.adwaita,
                    title: 'Update Available',
                    message:
                        'A new version is available. Update to get the latest features.',
                  ),
                ),
                _buildPlatformButton(
                  label: 'Adaptive',
                  subtitle: 'Auto-detect',
                  icon: Icons.auto_awesome,
                  color: Colors.purple,
                  onPressed: () => _showDialogWithStyle(
                    UpdateDialogStyle.adaptive,
                    title: 'Update Available',
                    message: 'Version 2.0.0 is now available (you have 1.0.0).',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Dialog Features Section
            _buildSection(
              title: 'Dialog Features',
              subtitle: 'Test different dialog options and behaviors',
              children: [
                _buildFeatureButton(
                  label: 'With Skip Version',
                  subtitle: 'User can skip this version',
                  icon: Icons.skip_next,
                  onPressed: () => _showDialogWithOptions(
                    showSkipVersion: true,
                    showDoNotAskAgain: false,
                  ),
                ),
                _buildFeatureButton(
                  label: 'With "Don\'t Ask Again"',
                  subtitle: 'User can disable future prompts',
                  icon: Icons.notifications_off,
                  onPressed: () => _showDialogWithOptions(
                    showSkipVersion: false,
                    showDoNotAskAgain: true,
                  ),
                ),
                _buildFeatureButton(
                  label: 'All Options',
                  subtitle: 'Skip version + Don\'t ask again',
                  icon: Icons.checklist,
                  onPressed: () => _showDialogWithOptions(
                    showSkipVersion: true,
                    showDoNotAskAgain: true,
                  ),
                ),
                _buildFeatureButton(
                  label: 'Minimal Dialog',
                  subtitle: 'No skip options, just Update/Cancel',
                  icon: Icons.remove_circle_outline,
                  onPressed: () => _showDialogWithOptions(
                    showSkipVersion: false,
                    showDoNotAskAgain: false,
                  ),
                ),
                _buildFeatureButton(
                  label: 'Non-Dismissible',
                  subtitle: 'Cannot tap outside to close',
                  icon: Icons.block,
                  onPressed: () => _showNonDismissibleDialog(),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Localization Section
            _buildSection(
              title: 'Localization',
              subtitle: 'Dialog text in different languages',
              children: [
                _buildFeatureButton(
                  label: 'French',
                  subtitle: 'Mise à jour disponible',
                  icon: Icons.language,
                  onPressed: () => _showLocalizedDialog('fr'),
                ),
                _buildFeatureButton(
                  label: 'Spanish',
                  subtitle: 'Actualización disponible',
                  icon: Icons.language,
                  onPressed: () => _showLocalizedDialog('es'),
                ),
                _buildFeatureButton(
                  label: 'German',
                  subtitle: 'Update verfügbar',
                  icon: Icons.language,
                  onPressed: () => _showLocalizedDialog('de'),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Custom Dialog Section
            _buildSection(
              title: 'Custom Dialogs',
              subtitle: 'Customized text and appearance',
              children: [
                _buildFeatureButton(
                  label: 'Custom Messages',
                  subtitle: 'Custom title, message, and buttons',
                  icon: Icons.edit_note,
                  onPressed: () => _showCustomMessageDialog(),
                ),
                _buildFeatureButton(
                  label: 'Custom Widget Dialog',
                  subtitle: 'Completely custom dialog UI',
                  icon: Icons.widgets,
                  onPressed: () => _showCustomWidgetDialog(),
                ),
              ],
            ),
            const SizedBox(height: 100), // Bottom padding for FAB
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _checkForUpdates,
        tooltip: 'Check for Updates',
        icon: const Icon(Icons.update),
        label: const Text('Check Updates'),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: children,
        ),
      ],
    );
  }

  Widget _buildPlatformButton({
    required String label,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: 160,
      child: Card(
        elevation: 2,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Icon(icon, size: 32, color: color),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureButton({
    required String label,
    required String subtitle,
    required IconData icon,
    Color? color,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: 200,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: color != null ? BorderSide(color: color) : null,
        ),
        child: Row(
          children: [
            Icon(icon, size: 24, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: color?.withAlpha(179) ?? Colors.grey.shade600,
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

  Future<void> _showDialogWithStyle(
    UpdateDialogStyle style, {
    String? title,
    String? message,
  }) async {
    await appUpdater.showUpdateDialog(
      context,
      updateInfo: _createMockUpdateInfo(),
      dialogStyle: style,
      showSkipVersion: true,
      showDoNotAskAgain: true,
      showReleaseNotes: true,
      title: title,
      message: message,
      onUpdate: () {
        _showSnackBar('Update button pressed!');
      },
      onCancel: () {
        _showSnackBar('Cancel button pressed');
      },
    );
  }

  Future<void> _showDialogWithOptions({
    required bool showSkipVersion,
    required bool showDoNotAskAgain,
  }) async {
    await appUpdater.showUpdateDialog(
      context,
      updateInfo: _createMockUpdateInfo(),
      dialogStyle: UpdateDialogStyle.adaptive,
      showSkipVersion: showSkipVersion,
      showDoNotAskAgain: showDoNotAskAgain,
      showReleaseNotes: true,
      onUpdate: () {
        _showSnackBar('Update button pressed!');
      },
      onCancel: () {
        _showSnackBar('Cancel button pressed');
      },
    );
  }

  Future<void> _showNonDismissibleDialog() async {
    await appUpdater.showUpdateDialog(
      context,
      updateInfo: _createMockUpdateInfo(),
      dialogStyle: UpdateDialogStyle.adaptive,
      isDismissible: false,
      showSkipVersion: true,
      showDoNotAskAgain: true,
      showReleaseNotes: true,
      onUpdate: () {
        _showSnackBar('Update button pressed!');
      },
      onCancel: () {
        _showSnackBar('Cancel button pressed');
      },
    );
  }

  Future<void> _showDialogWithReleaseNotes() async {
    await appUpdater.showUpdateDialog(
      context,
      updateInfo: _createMockUpdateInfo(
        releaseNotes: '## What\'s New in v2.0.0\n\n'
            '### Features\n'
            '• Dark mode support with automatic switching\n'
            '• New dashboard with analytics\n'
            '• Improved search with filters\n\n'
            '### Improvements\n'
            '• 50% faster app startup\n'
            '• Reduced memory usage\n'
            '• Better battery efficiency\n\n'
            '### Bug Fixes\n'
            '• Fixed crash on login\n'
            '• Fixed sync issues\n'
            '• Various UI improvements',
      ),
      dialogStyle: UpdateDialogStyle.adaptive,
      showReleaseNotes: true,
      onUpdate: () {
        _showSnackBar('Update button pressed!');
      },
      onCancel: () {
        _showSnackBar('Cancel button pressed');
      },
    );
  }

  Future<void> _showDialogWithUrgency(UpdateUrgency urgency) async {
    String message;
    switch (urgency) {
      case UpdateUrgency.critical:
        message =
            'This update contains critical security fixes. Please update immediately.';
        break;
      case UpdateUrgency.high:
        message =
            'This update contains important improvements. We strongly recommend updating.';
        break;
      case UpdateUrgency.low:
        message =
            'A minor update is available with small improvements and bug fixes.';
        break;
      default:
        message = 'A new version is available with new features and improvements.';
    }

    await appUpdater.showUpdateDialog(
      context,
      updateInfo: _createMockUpdateInfo(urgency: urgency),
      dialogStyle: UpdateDialogStyle.adaptive,
      message: message,
      showReleaseNotes: true,
      onUpdate: () {
        _showSnackBar('Update button pressed!');
      },
      onCancel: () {
        _showSnackBar('Cancel button pressed');
      },
    );
  }

  Future<void> _showMandatoryUpdate() async {
    await appUpdater.showUpdateDialog(
      context,
      updateInfo: _createMockUpdateInfo(
        urgency: UpdateUrgency.critical,
        isMandatory: true,
        releaseNotes: 'This update is required to continue using the app.\n\n'
            '• Critical security vulnerability fixed\n'
            '• API compatibility updates\n'
            '• Required server-side changes',
      ),
      dialogStyle: UpdateDialogStyle.adaptive,
      isPersistent: true,
      isDismissible: false,
      showReleaseNotes: true,
      title: 'Mandatory Update Required',
      message:
          'Your app version is no longer supported. Please update to continue.',
      onUpdate: () {
        _showSnackBar('Redirecting to store...');
      },
    );
  }

  Future<void> _showLocalizedDialog(String languageCode) async {
    UpdateStrings strings;

    switch (languageCode) {
      case 'fr':
        strings = const UpdateStrings(
          updateAvailableTitle: 'Mise à jour disponible',
          updateAvailableMessage:
              'Une nouvelle version ({latestVersion}) est disponible. Vous avez actuellement la version {currentVersion}.',
          updateButton: 'Mettre à jour',
          laterButton: 'Plus tard',
          skipVersionButton: 'Ignorer cette version',
          doNotAskAgainButton: 'Ne plus me rappeler',
          releaseNotesTitle: 'Nouveautés',
        );
        break;
      case 'es':
        strings = const UpdateStrings(
          updateAvailableTitle: 'Actualización disponible',
          updateAvailableMessage:
              'Una nueva versión ({latestVersion}) está disponible. Actualmente tienes la versión {currentVersion}.',
          updateButton: 'Actualizar ahora',
          laterButton: 'Más tarde',
          skipVersionButton: 'Omitir esta versión',
          doNotAskAgainButton: 'No volver a preguntar',
          releaseNotesTitle: 'Novedades',
        );
        break;
      case 'de':
        strings = const UpdateStrings(
          updateAvailableTitle: 'Update verfügbar',
          updateAvailableMessage:
              'Eine neue Version ({latestVersion}) ist verfügbar. Sie haben derzeit Version {currentVersion}.',
          updateButton: 'Jetzt aktualisieren',
          laterButton: 'Später',
          skipVersionButton: 'Diese Version überspringen',
          doNotAskAgainButton: 'Nicht mehr erinnern',
          releaseNotesTitle: 'Neuigkeiten',
        );
        break;
      default:
        strings = const UpdateStrings();
    }

    // Create a temporary updater with localized strings
    final localizedUpdater = AppUpdater.configure(
      iosAppId: '123456789',
      strings: strings,
    );

    final mockInfo = _createMockUpdateInfo();
    final message = strings.formatUpdateMessage(
      mockInfo.currentVersion,
      mockInfo.latestVersion!,
    );

    await localizedUpdater.showUpdateDialog(
      context,
      updateInfo: mockInfo,
      dialogStyle: UpdateDialogStyle.adaptive,
      title: strings.updateAvailableTitle,
      message: message,
      updateText: strings.updateButton,
      cancelText: strings.laterButton,
      showSkipVersion: true,
      showDoNotAskAgain: true,
      showReleaseNotes: true,
      onUpdate: () {
        _showSnackBar('Update button pressed!');
      },
      onCancel: () {
        _showSnackBar('Cancel button pressed');
      },
    );
  }

  Future<void> _showCustomMessageDialog() async {
    await appUpdater.showUpdateDialog(
      context,
      updateInfo: _createMockUpdateInfo(),
      dialogStyle: UpdateDialogStyle.material,
      title: 'New Version Available!',
      message: 'We\'ve been working hard on exciting new features!\n\n'
          'What\'s new in v2.0.0:\n'
          '• Dark mode support\n'
          '• Performance improvements\n'
          '• Bug fixes',
      updateText: 'Get It Now',
      cancelText: 'Maybe Later',
      showSkipVersion: true,
      showReleaseNotes: false, // Using custom message instead
      onUpdate: () {
        _showSnackBar('Opening store...');
      },
      onCancel: () {
        _showSnackBar('Reminder set for later');
      },
    );
  }

  Future<void> _showCustomWidgetDialog() async {
    await appUpdater.showUpdateDialog(
      context,
      updateInfo: _createMockUpdateInfo(),
      customDialog: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.blue, Colors.purple],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.rocket_launch,
                  size: 48,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Exciting Update!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Version 2.0.0 is here with amazing new features!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('✨ New dark mode',
                        style: TextStyle(fontSize: 14)),
                    Text('🚀 50% faster performance',
                        style: TextStyle(fontSize: 14)),
                    Text('🐛 Bug fixes',
                        style: TextStyle(fontSize: 14)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _showSnackBar('Skipped for now');
                      },
                      child: const Text('Not Now'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _showSnackBar('Opening store...');
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.purple,
                      ),
                      child: const Text('Update'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
