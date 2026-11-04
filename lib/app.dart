import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';
import 'shared/providers/library_provider.dart';

class PhotoOrganizerApp extends ConsumerStatefulWidget {
  const PhotoOrganizerApp({super.key, required this.router});

  final GoRouter router;

  @override
  ConsumerState<PhotoOrganizerApp> createState() => _PhotoOrganizerAppState();
}

class _PhotoOrganizerAppState extends ConsumerState<PhotoOrganizerApp> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () {
        ref.read(libraryProvider.notifier).onAppResumed();
      },
      onPause: () {
        ref.read(libraryProvider.notifier).onAppPaused();
      },
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'J-Pix',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: widget.router,
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: MediaQuery.textScalerOf(context)
                .clamp(minScaleFactor: 0.9, maxScaleFactor: 1.2),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
