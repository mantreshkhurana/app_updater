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
  // Create AppUpdater instance with configuration
  final appUpdater = AppUpdater.configure(
    // Mobile
    iosAppId: '123456789',
    // androidPackageName is auto-detected!
    // Desktop
    macAppId: '987654321',
    microsoftProductId: '9NBLGGH4NNS1',
    snapName: 'example-app',
    flathubAppId: 'com.example.app',
    linuxStoreType: LinuxStoreType.snap,
  );

  // Mock UpdateInfo for demonstrations
  UpdateInfo get _mockUpdateInfo => UpdateInfo(
        currentVersion: '1.0.0',
        latestVersion: '2.0.0',
        updateUrl: 'https://example.com',
        updateAvailable: true,
      );

  @override
  void initState() {
    super.initState();
    // Check for updates on app start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForUpdates();
    });
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
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
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
              'App Updater Demo',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap the buttons below to preview update dialogs',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),

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
                _buildPlatformButton(
                  label: 'Custom',
                  subtitle: 'Your own UI',
                  icon: Icons.widgets,
                  color: Colors.teal,
                  onPressed: () => _showCustomWidgetDialog(),
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

            // Mandatory Update Section
            _buildSection(
              title: 'Mandatory Updates',
              subtitle: 'Force users to update (no cancel option)',
              children: [
                _buildFeatureButton(
                  label: 'Critical Update',
                  subtitle: 'Persistent dialog - must update',
                  icon: Icons.warning_amber,
                  color: Colors.red,
                  onPressed: () => _showPersistentDialog(
                    title: 'Critical Update Required',
                    message:
                        'This update contains important security fixes. Please update to continue using the app.',
                  ),
                ),
                _buildFeatureButton(
                  label: 'Mandatory Feature Update',
                  subtitle: 'Required for app functionality',
                  icon: Icons.new_releases,
                  color: Colors.orange,
                  onPressed: () => _showPersistentDialog(
                    title: 'Update Required',
                    message:
                        'This version is no longer supported. Please update to access new features and improvements.',
                  ),
                ),
                _buildFeatureButton(
                  label: 'Breaking Change Update',
                  subtitle: 'API compatibility update',
                  icon: Icons.api,
                  color: Colors.deepOrange,
                  onPressed: () => _showPersistentDialog(
                    title: 'Important Update',
                    message:
                        'The current version is incompatible with our servers. Please update to continue.',
                  ),
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
      updateInfo: _mockUpdateInfo,
      dialogStyle: style,
      showSkipVersion: true,
      showDoNotAskAgain: true,
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
      updateInfo: _mockUpdateInfo,
      dialogStyle: UpdateDialogStyle.adaptive,
      showSkipVersion: showSkipVersion,
      showDoNotAskAgain: showDoNotAskAgain,
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
      updateInfo: _mockUpdateInfo,
      dialogStyle: UpdateDialogStyle.adaptive,
      isDismissible: false,
      showSkipVersion: true,
      showDoNotAskAgain: true,
      onUpdate: () {
        _showSnackBar('Update button pressed!');
      },
      onCancel: () {
        _showSnackBar('Cancel button pressed');
      },
    );
  }

  Future<void> _showPersistentDialog({
    required String title,
    required String message,
  }) async {
    await appUpdater.showUpdateDialog(
      context,
      updateInfo: _mockUpdateInfo,
      isPersistent: true,
      isDismissible: false,
      title: title,
      message: message,
      updateText: 'Update Now',
      onUpdate: () {
        _showSnackBar('Redirecting to store...');
      },
    );
  }

  Future<void> _showCustomMessageDialog() async {
    await appUpdater.showUpdateDialog(
      context,
      updateInfo: _mockUpdateInfo,
      dialogStyle: UpdateDialogStyle.material,
      title: 'New Version Available!',
      message: 'We\'ve been working hard on exciting new features!\n\n'
          'What\'s new in v2.0.0:\n'
          '- Dark mode support\n'
          '- Performance improvements\n'
          '- Bug fixes',
      updateText: 'Get It Now',
      cancelText: 'Maybe Later',
      showSkipVersion: true,
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
      updateInfo: _mockUpdateInfo,
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
