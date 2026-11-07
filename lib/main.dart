import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/router/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(isOptional: true);
  } catch (_) {
    // No .env bundled: the app simply stays offline-only.
  }
  runApp(
    ProviderScope(
      child: PhotoOrganizerApp(router: appRouter),
    ),
  );
}
