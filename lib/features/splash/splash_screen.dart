import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../shared/providers/library_provider.dart';
import '../../shared/providers/service_providers.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_bootstrap());
    });
  }

  Future<void> _bootstrap() async {
    // Start loading in the background so the splash never blocks app launch.
    unawaited(ref.read(libraryProvider.notifier).initialize());
    unawaited(
      ref
          .read(aiServiceProvider)
          .preloadGeneral()
          .timeout(const Duration(seconds: 20))
          .catchError((Object _) {}),
    );
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (mounted) {
      context.go('/home');
    }
  }

  Widget _fadeSlide({
    required int delayMs,
    required Widget child,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 500 + delayMs),
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, double value, Widget? child) {
        final double t = ((value * (500 + delayMs) - delayMs) / 500)
            .clamp(0.0, 1.0)
            .toDouble();
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - t)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  Widget _blob(double size, double alpha) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: alpha),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.hero),
        child: Stack(
          children: <Widget>[
            Positioned(top: -70, right: -60, child: _blob(240, 0.07)),
            Positioned(top: 140, left: -80, child: _blob(180, 0.05)),
            Positioned(bottom: -90, left: -40, child: _blob(260, 0.06)),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  children: <Widget>[
                    const Spacer(flex: 5),
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0.6, end: 1),
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.elasticOut,
                      builder:
                          (BuildContext context, double value, Widget? child) {
                        return Transform.scale(scale: value, child: child);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(36),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.28),
                              blurRadius: 50,
                              spreadRadius: 4,
                            ),
                            const BoxShadow(
                              color: Color(0x40000000),
                              blurRadius: 30,
                              offset: Offset(0, 16),
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/images/app_logo.png',
                          width: 92,
                          height: 92,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    _fadeSlide(
                      delayMs: 250,
                      child: Text(
                        'J-Pix',
                        textAlign: TextAlign.center,
                        style:
                            Theme.of(context).textTheme.displaySmall?.copyWith(
                                  color: Colors.white,
                                  fontSize: 42,
                                  letterSpacing: -1.2,
                                ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _fadeSlide(
                      delayMs: 450,
                      child: Text(
                        'Organize. Find. Discover.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Colors.white.withValues(alpha: 0.82),
                              letterSpacing: 0.4,
                            ),
                      ),
                    ),
                    const Spacer(flex: 4),
                    _fadeSlide(
                      delayMs: 600,
                      child: SizedBox(
                        width: 120,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            minHeight: 4,
                            color: Colors.white,
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.22),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    _fadeSlide(
                      delayMs: 750,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              Icons.shield_outlined,
                              size: 15,
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'On-device AI · Your photos stay private',
                              style:
                                  Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color:
                                            Colors.white.withValues(alpha: 0.85),
                                      ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
