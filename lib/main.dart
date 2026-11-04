import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app/app.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set system UI navigation and status bar style for Cosmic dark theme
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0F1524),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Initialize Firebase using DefaultFirebaseOptions
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize FCM and local notifications on mobile platforms
  if (!kIsWeb) {
    try {
      await NotificationService().initialize();
    } catch (e) {
      debugPrint('NotificationService initialization notice: $e');
    }
  }

  runApp(const CosmicApp());
}
