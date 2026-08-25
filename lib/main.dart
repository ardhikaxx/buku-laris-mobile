import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/utils/formatters.dart';
import 'firebase_options.dart';
import 'services/connectivity_service.dart';
import 'services/logger.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.white,
    ),
  );
  await initLocale();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    ConnectivityService.instance.start();
  } catch (e) {
    Logger.e('Firebase init failed', e);
  }
  runApp(const ProviderScope(child: BukuLarisApp()));
}
