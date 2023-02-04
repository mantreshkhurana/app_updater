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

  static const _playMarketUrl =
      'https://play.google.com/store/apps/details?id=';
  static const _appStoreUrlIOS = 'https://apps.apple.com/app';
  static const _appStoreUrlMacOS =
      'https://apps.apple.com/ru/app/g-app-launcher/id';
  static const _microsoftStoreUrl = 'https://apps.microsoft.com/store/detail/';

  final _platformNotSupportedException = Exception('Platform not supported');

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
      await _openIOS(appName, appStoreId);
      return;
    }
    if (Platform.isMacOS) {
      await _openMacOS(appStoreId, appStoreIdMacOS);
      return;
    }
    if (Platform.isAndroid) {
      await _openAndroid(androidAppBundleId);
      return;
    }
    if (Platform.isWindows) {
      await _opnWindows(windowsProductId);
      return;
    }

    throw _platformNotSupportedException;
  }

  Future _openAndroid(String? androidAppBundleId) async {
    if (androidAppBundleId != null) {
      await _openUrl('$_playMarketUrl$androidAppBundleId');
      return;
    }
    throw CantLaunchPageException("androidAppBundleId is not passed");
  }

  Future _openIOS(String? appName, String? appStoreId) async {
    if (appStoreId != null) {
      await _openUrl('$_appStoreUrlIOS/$appName/id$appStoreId');
      return;
    }
    throw CantLaunchPageException("appStoreId is not passed");
  }

  Future _openMacOS(String? appStoreId, String? appStoreIdMacOS) async {
    if (appStoreId != null || appStoreIdMacOS != null) {
      await _openUrl('$_appStoreUrlMacOS${appStoreIdMacOS ?? appStoreId}');
      return;
    }
    throw CantLaunchPageException(
      "appStoreId and appStoreIdMacOS is not passed",
    );
  }

  Future _opnWindows(String? windowsProductId) async {
    if (windowsProductId != null) {
      await _openUrl('$_microsoftStoreUrl$windowsProductId');
      return;
    }
    throw CantLaunchPageException("windowsProductId is not passed");
  }

  Future<void> _openUrl(String url) async {
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
