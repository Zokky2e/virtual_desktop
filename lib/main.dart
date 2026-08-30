import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:virtual_desktop/app/app.dart';
import 'package:virtual_desktop/core/di/injector.dart';
import 'package:virtual_desktop/shared/utils/env.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    await BrowserContextMenu.disableContextMenu();
  }
  FlutterError.onError = (details) {
    if (details.exception.toString().contains(
      'data[\$_get] is not a function',
    )) {
      return;
    }

    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint("PlatformDispatcher caught: $error");
    if (error.toString().contains('data[\$_get] is not a function')) {
      return true; // mark as handled, do not print
    }

    return false; // allow normal errors
  };
  await dotenv.load(fileName: ".env");
  if (kIsWeb) {
    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: requireEnv('FIREBASE_API_KEY'),
        appId: requireEnv('FIREBASE_APP_ID'),
        messagingSenderId: requireEnv('FIREBASE_MESSAGING_SENDER_ID'),
        projectId: requireEnv('FIREBASE_PROJECT_ID'),
        authDomain: optionalEnv('FIREBASE_AUTH_DOMAIN'),
        storageBucket: optionalEnv('FIREBASE_STORAGE_BUCKET'),
        measurementId: optionalEnv('FIREBASE_MEASUREMENT_ID'),
      ),
    );
  }
  setupDependencies();
  runApp(const App());
}
