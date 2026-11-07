import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
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
    await Future<void>.delayed(const Duration(milliseconds: 1800));
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

  Widget _blob(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }

  Widget _logo() {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.6, end: 1),
      duration: const Duration(milliseconds: 800),
      curve: Curves.elasticOut,
      builder: (BuildContext context, double value, Widget? child) {
        return Transform.scale(scale: value, child: child);
      },
      child: Container(
        width: 128,
        height: 128,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(36),
          border: Border.all(color: AppColors.primarySoft, width: 1.5),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.22),
              blurRadius: 40,
              spreadRadius: 2,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Image.asset(
          'assets/images/app_logo.png',
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primarySoft),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.white,
      body: SizedBox.expand(
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                AppColors.primaryFaint,
                AppColors.white,
                AppColors.primaryFaint,
              ],
              stops: <double>[0, 0.55, 1],
            ),
          ),
          child: Stack(
            children: <Widget>[
              // Soft decorative blobs
              Positioned(
                top: -80,
                right: -70,
                child: _blob(
                  240,
                  AppColors.primarySoft.withValues(alpha: 0.55),
                ),
              ),
              Positioned(
                bottom: -90,
                left: -80,
                child: _blob(
                  260,
                  AppColors.primarySoft.withValues(alpha: 0.45),
                ),
              ),
              // Content, centered both ways
              Positioned.fill(
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 28,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        const Spacer(),
                        _logo(),
                        const SizedBox(height: 36),
                        _fadeSlide(
                          delayMs: 250,
                          child: Text(
                            AppConstants.appName,
                            textAlign: TextAlign.center,
                            style: textTheme.displaySmall?.copyWith(
                              color: AppColors.textPrimary,
                              fontSize: 42,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -1.4,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _fadeSlide(
                          delayMs: 450,
                          child: Text(
                            AppConstants.appTagline,
                            textAlign: TextAlign.center,
                            style: textTheme.bodyLarge?.copyWith(
                              color: AppColors.textSecondary,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        _fadeSlide(
                          delayMs: 600,
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            children: <Widget>[
                              _chip(Icons.auto_awesome_rounded, 'AI tagging'),
                              _chip(Icons.copy_all_rounded, 'Duplicates'),
                              _chip(Icons.search_rounded, 'Smart search'),
                            ],
                          ),
                        ),
                        const Spacer(),
                        _fadeSlide(
                          delayMs: 750,
                          child: SizedBox(
                            width: 140,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: const LinearProgressIndicator(
                                minHeight: 4,
                                color: AppColors.primary,
                                backgroundColor: AppColors.primarySoft,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        _fadeSlide(
                          delayMs: 900,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              const Icon(
                                Icons.shield_outlined,
                                size: 15,
                                color: AppColors.textTertiary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'On-device AI · Your photos stay private',
                                style: textTheme.bodySmall?.copyWith(
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'v${AppConstants.appVersion}',
                          style: textTheme.labelSmall?.copyWith(
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
