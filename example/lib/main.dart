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
    // Note: This is just an example - it won't trigger an update or any dialog
    // You need to use your own app IDs and bundle IDs
    // This won't work on iOS simulators as they don't have the App Store installed

    final updateInfo = await appUpdater.checkAndShowUpdateDialog(
      context,
      // Dialog options
      showSkipVersion: true,
      showDoNotAskAgain: true,
      isDismissible: true,
      // Use adaptive dialog style (auto-selects based on platform)
      dialogStyle: UpdateDialogStyle.adaptive,
      // Callbacks
      onNoUpdate: () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('App is up to date!')),
          );
        }
      },
      onUpdate: () {
        debugPrint('User chose to update');
      },
      onCancel: () {
        debugPrint('User cancelled update');
      },
    );

    // You can also check the updateInfo object
    debugPrint('Current version: ${updateInfo.currentVersion}');
    debugPrint('Latest version: ${updateInfo.latestVersion}');
    debugPrint('Update available: ${updateInfo.updateAvailable}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('App Updater Example'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          // Reset preferences button
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset update preferences',
            onPressed: _resetPreferences,
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.system_update,
                size: 80,
                color: Colors.blue,
              ),
              const SizedBox(height: 24),
              const Text(
                'App Updater Demo',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Tap the buttons below to test different dialog styles',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 32),

              // Test different dialog styles
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  _buildStyleButton(
                    'Adaptive',
                    UpdateDialogStyle.adaptive,
                    Icons.auto_awesome,
                  ),
                  _buildStyleButton(
                    'Material',
                    UpdateDialogStyle.material,
                    Icons.android,
                  ),
                  _buildStyleButton(
                    'Cupertino',
                    UpdateDialogStyle.cupertino,
                    Icons.apple,
                  ),
                  _buildStyleButton(
                    'Fluent',
                    UpdateDialogStyle.fluent,
                    Icons.window,
                  ),
                  _buildStyleButton(
                    'Adwaita',
                    UpdateDialogStyle.adwaita,
                    Icons.desktop_windows,
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Persistent dialog example
              FilledButton.icon(
                onPressed: () => _showPersistentDialog(),
                icon: const Icon(Icons.lock),
                label: const Text('Show Persistent Dialog'),
              ),
            ],
          ),
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

  Widget _buildStyleButton(
      String label, UpdateDialogStyle style, IconData icon) {
    return OutlinedButton.icon(
      onPressed: () => _showDialogWithStyle(style),
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }

  Future<void> _showDialogWithStyle(UpdateDialogStyle style) async {
    // Create a mock UpdateInfo for demonstration
    final mockUpdateInfo = UpdateInfo(
      currentVersion: '1.0.0',
      latestVersion: '2.0.0',
      updateUrl: 'https://example.com',
      updateAvailable: true,
    );

    await appUpdater.showUpdateDialog(
      context,
      updateInfo: mockUpdateInfo,
      dialogStyle: style,
      showSkipVersion: true,
      showDoNotAskAgain: true,
      onUpdate: () => appUpdater.openStore(),
    );
  }

  Future<void> _showPersistentDialog() async {
    // Create a mock UpdateInfo for demonstration
    final mockUpdateInfo = UpdateInfo(
      currentVersion: '1.0.0',
      latestVersion: '2.0.0',
      updateUrl: 'https://example.com',
      updateAvailable: true,
    );

    await appUpdater.showUpdateDialog(
      context,
      updateInfo: mockUpdateInfo,
      isPersistent: true, // User cannot dismiss this dialog
      isDismissible: false,
      title: 'Critical Update Required',
      message:
          'This update is required to continue using the app. Please update now.',
      updateText: 'Update Now',
    );
  }
}
