import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/api/app_version.dart';
import 'data/push/push_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppBuild.load();
  await PushService.initFirebase();
  await _startCrashReports();
  runApp(const ProviderScope(child: JolApp()));
}

/// Crash reports through Firebase Crashlytics, once Firebase is set up
/// (google-services.json / GoogleService-Info.plist). Only release builds
/// send reports, so testing on your own phone doesn't fill the dashboard.
Future<void> _startCrashReports() async {
  if (!PushService.firebaseReady) return;
  try {
    final crashlytics = FirebaseCrashlytics.instance;
    await crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode);
    await crashlytics.setCustomKey('app_version', '${AppBuild.version}+${AppBuild.build}');

    // Errors while building or drawing the screen.
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      crashlytics.recordFlutterFatalError(details);
    };
    // Errors in async code that nothing caught.
    PlatformDispatcher.instance.onError = (error, stack) {
      crashlytics.recordError(error, stack, fatal: true);
      return true;
    };
  } catch (error) {
    debugPrint('Crash reports disabled: $error');
  }
}
