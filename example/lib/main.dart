import 'package:app_updater/app_updater.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height,
              color: Colors.black,
              child: const Center(
                child: Text(
                  'Check for updates',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Note: This is just an example it won't trigger an update or any sort of dialog you need to use your own app id's and bundle id's
          // This won't work on iOS simulators as they don't have the App Store installed.
          checkAppUpdate(
            context,
            appName: 'Example App',
            iosAppId: '123456789',
            androidAppBundleId: 'com.example.app',
            isDismissible: false,
            customDialog: true,
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
                    OpenStore.instance.open(
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
                    OpenStore.instance.open(
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
        },
        tooltip: 'Check for Updates',
        child: const Icon(Icons.update),
      ),
    );
  }
}
