import 'dart:io' show Platform;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:store_version_checker/store_version_checker.dart';
import '../open_store/open_store.dart';

/// Check for app update using [StoreVersionChecker] package
final checker = StoreVersionChecker();

/// Check for app update and show dialog using [AppUpdater] package
void checkAppUpdate(
  BuildContext context, {
  required String appName,
  required String iosAppId,
  required String androidAppBundleId,
  bool customDialog = false,
  Widget? customAndroidDialog,
  Widget? customIOSDialog,
}) async {
  checker.checkUpdate().then(
    (value) {
      if (value.canUpdate) {
        updateNow(
          context,
          appName,
          iosAppId,
          androidAppBundleId,
          customDialog,
          customAndroidDialog,
          customIOSDialog,
        );
      } else {
        debugPrint('No update available');
      }
    },
  );
}

/// Show update dialog depending on platform or a custom dialog
Future<void> updateNow(
  BuildContext context,
  String appName,
  String iosAppId,
  String androidAppId,
  bool customDialog,
  Widget? customAndroidDialog,
  Widget? customIOSDialog,
) async {
  customDialog == true && Platform.isAndroid && customAndroidDialog != null
      ? showDialog(
          context: context,
          builder: (context) => customAndroidDialog,
        )
      : customDialog == true && Platform.isIOS && customIOSDialog != null
          ? showCupertinoDialog(
              context: context,
              builder: (context) => customIOSDialog,
            )
          : Platform.isAndroid
              ? showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('Update $appName'),
                    content: const Text('New version is available'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Later'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          OpenStore.instance.open(
                            androidAppBundleId: androidAppId,
                          );
                        },
                        child: const Text('Update'),
                      ),
                    ],
                  ),
                )
              : Platform.isIOS
                  ? showCupertinoDialog(
                      context: context,
                      builder: (context) => CupertinoAlertDialog(
                        title: Text('Update $appName'),
                        content: const Text('New version is available'),
                        actions: [
                          CupertinoDialogAction(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Later'),
                          ),
                          CupertinoDialogAction(
                            onPressed: () {
                              Navigator.pop(context);
                              OpenStore.instance.open(
                                appName: appName,
                                appStoreId: iosAppId,
                              );
                            },
                            child: const Text('Update'),
                          ),
                        ],
                      ),
                    )
                  : showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text('Update $appName'),
                        content: const Text('New version is available'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Later'),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              OpenStore.instance.open(
                                androidAppBundleId: androidAppId,
                              );
                            },
                            child: const Text('Update'),
                          ),
                        ],
                      ),
                    );
}
