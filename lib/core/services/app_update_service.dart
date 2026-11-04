import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppUpdateInfo {
  final bool isUpdateAvailable;
  final bool isForceUpdate;
  final String latestVersion;
  final double latestBuildNumber;
  final double currentBuildNumber;
  final String storeUrl;
  final String updateMessage;

  AppUpdateInfo({
    required this.isUpdateAvailable,
    required this.isForceUpdate,
    required this.latestVersion,
    required this.latestBuildNumber,
    required this.currentBuildNumber,
    required this.storeUrl,
    required this.updateMessage,
  });
}

class AppUpdateService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Listens to remote app update configurations in real time.
  static Stream<AppUpdateInfo> getUpdateStream() async* {
    final packageInfo = await PackageInfo.fromPlatform();
    final double currentBuild = double.tryParse(packageInfo.buildNumber) ?? 0.0;
    final String currentVersion = packageInfo.version;

    yield* _firestore
        .collection('app_config')
        .doc('app_update')
        .snapshots()
        .map((doc) => _parseUpdateDoc(doc, currentBuild, currentVersion));
  }

  /// One-time check for app update availability.
  static Future<AppUpdateInfo?> checkForUpdate() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final double currentBuild = double.tryParse(packageInfo.buildNumber) ?? 0.0;
      final String currentVersion = packageInfo.version;

      final doc = await _firestore.collection('app_config').doc('app_update').get();
      return _parseUpdateDoc(doc, currentBuild, currentVersion);
    } catch (e) {
      debugPrint("AppUpdateService check failed: $e");
      return null;
    }
  }

  static AppUpdateInfo _parseUpdateDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
    double currentBuild,
    String currentVersion,
  ) {
    if (!doc.exists || doc.data() == null) {
      return AppUpdateInfo(
        isUpdateAvailable: false,
        isForceUpdate: false,
        latestVersion: currentVersion,
        latestBuildNumber: currentBuild,
        currentBuildNumber: currentBuild,
        storeUrl: '',
        updateMessage: '',
      );
    }

    final data = doc.data()!;
    final bool isAndroid = Platform.isAndroid;

    final double latestBuild = isAndroid
        ? ((data['latestAndroidBuild'] as num?)?.toDouble() ?? 0.0)
        : ((data['latestIosBuild'] as num?)?.toDouble() ?? 0.0);

    final String latestVersion = isAndroid
        ? (data['latestAndroidVersion'] ?? currentVersion)
        : (data['latestIosVersion'] ?? currentVersion);

    final bool isForceUpdate = data['isForceUpdate'] ?? false;
    final String storeUrl = isAndroid
        ? (data['playStoreUrl'] ?? '')
        : (data['appStoreUrl'] ?? '');
    final String updateMessage = data['updateMessage'] ?? '';

    // Compare build numbers as doubles to match Firestore schema
    final bool isUpdateAvailable = latestBuild > currentBuild;

    return AppUpdateInfo(
      isUpdateAvailable: isUpdateAvailable,
      isForceUpdate: isForceUpdate,
      latestVersion: latestVersion,
      latestBuildNumber: latestBuild,
      currentBuildNumber: currentBuild,
      storeUrl: storeUrl,
      updateMessage: updateMessage,
    );
  }
}
