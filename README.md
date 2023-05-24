# App Updater

[![GitHub stars](https://img.shields.io/github/stars/mantreshkhurana/app_updater.svg?style=social)](https://github.com/mantreshkhurana/app_updater)
[![pub package](https://img.shields.io/pub/v/app_updater.svg)](https://pub.dartlang.org/packages/app_updater)

Check for app updates and show a dialog to update the app, open App Store/Play Store/Windows Store/macOS App Store/Linux App Store from your app.

![Screenshot](https://raw.githubusercontent.com/mantreshkhurana/app_updater/stable/screenshots/screenshot-1.png)

## Installation

Add `app_updater: ^1.0.6` in your project's pubspec.yaml:

```yaml
dependencies:
  app_updater: ^1.0.6
```

## Usage

Import `app_updater` in your dart file:

```dart
import 'package:app_updater/app_updater.dart';
```

Then use `checkAppUpdate` in your code:

> checkAppUpdate function won't show any dialog in iOS Simulator. [Source](https://stackoverflow.com/questions/13645554/itunes-app-link-cannot-open-page-in-safari-in-simulator-and-also-idevices)

### Default Usage

```dart
checkAppUpdate(
    context,
    appName: 'Example App',
    iosAppId: '123456789',
    androidAppBundleId: 'com.example.app',
);
```

### Custom Usage

```dart
checkAppUpdate(
    context,
    appName: 'Example App',
    iosAppId: '123456789',
    androidAppBundleId: 'com.example.app',
    isDismissible: true,
    customAndroidDialog: AlertDialog(
        title: const Text('Update Available'),
        content: const Text('Please update the app to continue'),
        actions: [
        TextButton(
            onPressed: () {
            Navigator.pop(context);
            },
            child: const Text('Cancel'),
        ),
        TextButton(
            onPressed: () {
            openAppStore(
                androidAppBundleId: 'com.example.app',
            );
            Navigator.pop(context);
            },
            child: const Text('Update'),
        ),
        ],
    ),
    customIOSDialog: CupertinoAlertDialog(
        title: const Text('Update Available'),
        content: const Text('Please update the app to continue'),
        actions: [
        CupertinoDialogAction(
            onPressed: () {
            Navigator.pop(context);
            },
            child: const Text('Cancel'),
        ),
        CupertinoDialogAction(
            onPressed: () {
            openAppStore(
                appName: 'Example App',
                appStoreId: '123456789',
            );
            Navigator.pop(context);
            },
            child: const Text('Update'),
        ),
        ],
    ),
);
```

## Open App/Play Store

This function is inspired from [open_store](https://pub.dev/packages/open_store), but it had some issues with iOS, so I created a [pull request](https://github.com/Frezyx/open_store/pull/10) to fix it but it's not merged yet.

```dart
onTap(){
    openAppStore(
        appName: 'Example App',
        iosAppId: '123456789',
        androidAppBundleId: 'com.example.app',
        // macos, windows, linux TBD
    );
}
```

## Credits

- [url_launcher](https://pub.dev/packages/url_launcher)
- [package_info_plus](https://pub.dev/packages/package_info_plus)

## Author

- [Mantresh Khurana](https://github.com/mantreshkhurana)
