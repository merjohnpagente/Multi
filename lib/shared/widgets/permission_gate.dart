import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../core/theme/app_colors.dart';
import '../providers/library_provider.dart';

class PermissionGate extends ConsumerWidget {
  const PermissionGate({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final LibraryState library = ref.watch(libraryProvider);
    final LibraryController controller = ref.read(libraryProvider.notifier);

    if (library.isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (library.error != null && !library.hasAccess) {
      return _PermissionBody(
        icon: Icons.error_outline_rounded,
        title: 'Gallery unavailable',
        message: library.error!,
        primaryLabel: 'Try again',
        onPrimary: controller.retry,
        secondaryLabel: 'Open settings',
        onSecondary: controller.openSystemSettings,
        compact: compact,
      );
    }

    if (library.permission == PermissionState.notDetermined) {
      return _PermissionBody(
        icon: Icons.photo_library_outlined,
        title: 'Your photos, organized',
        message:
            'Photo Organizer needs access to your gallery to sort photos on '
            'this device. Nothing is uploaded.',
        primaryLabel: 'Allow access',
        onPrimary: controller.grantAccess,
        compact: compact,
      );
    }

    if (library.permission == PermissionState.limited) {
      return _PermissionBody(
        icon: Icons.photo_library_outlined,
        title: 'More photos to organize',
        message:
            'You have allowed access to selected photos. Add more photos to '
            'let the organizer work with your full library.',
        primaryLabel: 'Choose more photos',
        onPrimary: controller.manageLimitedAccess,
        secondaryLabel: 'Open settings',
        onSecondary: controller.openSystemSettings,
        compact: compact,
      );
    }

    return _PermissionBody(
      icon: Icons.lock_outline_rounded,
      title: 'Gallery access is off',
      message:
          'Allow photo access in Android settings so Photo Organizer can sort '
          'and identify your photos offline.',
      primaryLabel: 'Try again',
      onPrimary: controller.grantAccess,
      secondaryLabel: 'Open settings',
      onSecondary: controller.openSystemSettings,
      compact: compact,
    );
  }
}

class _PermissionBody extends StatelessWidget {
  const _PermissionBody({
    required this.icon,
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    required this.compact,
  });

  final IconData icon;
  final String title;
  final String message;
  final String primaryLabel;
  final Future<void> Function() onPrimary;
  final String? secondaryLabel;
  final Future<void> Function()? onSecondary;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(compact ? 24 : 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: compact ? 72 : 92,
              height: compact ? 72 : 92,
              decoration: const BoxDecoration(
                color: AppColors.primaryFaint,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                size: compact ? 32 : 40,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => onPrimary(),
                child: Text(primaryLabel),
              ),
            ),
            if (secondaryLabel != null && onSecondary != null) ...<Widget>[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => onSecondary!(),
                  child: Text(secondaryLabel!),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Icon(
                  Icons.shield_outlined,
                  size: 14,
                  color: AppColors.textTertiary,
                ),
                const SizedBox(width: 6),
                Text(
                  '100% on-device · no network access',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
