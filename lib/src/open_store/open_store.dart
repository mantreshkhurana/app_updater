import 'dart:developer';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'src.dart';

class OpenStore {
  OpenStore._();

  static final OpenStore _instance = OpenStore._();

  /// Returns an instance using the default [OpenStore].
  static OpenStore get instance => _instance;

  static const playMarketUrl = 'https://play.google.com/store/apps/details?id=';
  static const appStoreUrlIOS = 'https://apps.apple.com/app';
  static const appStoreUrlMacOS =
      'https://apps.apple.com/ru/app/g-app-launcher/id';
  static const microsoftStoreUrl = 'https://apps.microsoft.com/store/detail/';

  final platformNotSupportedException = Exception('Platform not supported');

  /// Main method of this package
  /// Allows to open your app's page in store by platform
  ///
  /// Enabled for Android & iOS
  /// [PlatformException] will throw if you try using this package in other OS
  ///
  /// [CantLaunchPageException] will throw if you don't specify
  /// app id on Platform that you useing right now
  Future<void> open({
    String? appName,
    String? androidAppBundleId,
    String? appStoreId,
    String? appStoreIdMacOS,
    String? windowsProductId,
  }) async {
    assert(
      appStoreId != null ||
          androidAppBundleId != null ||
          windowsProductId != null ||
          appStoreIdMacOS != null,
      "You must pass one of this parameters",
    );

    try {
      await _open(
        appName,
        appStoreId,
        appStoreIdMacOS,
        androidAppBundleId,
        windowsProductId,
      );
    } on Exception catch (e, st) {
      log([e, st].toString());
      rethrow;
    }
  }

  Future<void> _open(
      String? appName,
      String? appStoreId,
      String? appStoreIdMacOS,
      String? androidAppBundleId,
      String? windowsProductId) async {
    if (kIsWeb) {
      throw Exception('Platform not supported');
    }

    if (Platform.isIOS) {
      await openIOS(appName, appStoreId);
      return;
    }
    if (Platform.isMacOS) {
      await openMacOS(appStoreId, appStoreIdMacOS);
      return;
    }
    if (Platform.isAndroid) {
      await openAndroid(androidAppBundleId);
      return;
    }
    if (Platform.isWindows) {
      await openWindows(windowsProductId);
      return;
    }

    throw platformNotSupportedException;
  }

  Future openAndroid(String? androidAppBundleId) async {
    if (androidAppBundleId != null) {
      await openUrl('$playMarketUrl$androidAppBundleId');
      return;
    }
    throw CantLaunchPageException("androidAppBundleId is not passed");
  }

  Future openIOS(String? appName, String? appStoreId) async {
    if (appStoreId != null) {
      await openUrl('$appStoreUrlIOS/$appName/id$appStoreId');
      return;
    }
    throw CantLaunchPageException("appStoreId is not passed");
  }

  Future openMacOS(String? appStoreId, String? appStoreIdMacOS) async {
    if (appStoreId != null || appStoreIdMacOS != null) {
      await openUrl('$appStoreUrlMacOS${appStoreIdMacOS ?? appStoreId}');
      return;
    }
    throw CantLaunchPageException(
      "appStoreId and appStoreIdMacOS is not passed",
    );
  }

  Future openWindows(String? windowsProductId) async {
    if (windowsProductId != null) {
      await openUrl('$microsoftStoreUrl$windowsProductId');
      return;
    }
    throw CantLaunchPageException("windowsProductId is not passed");
  }

  Future<void> openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      return;
    }
    throw CantLaunchPageException('Could not launch $url');
  }
}
