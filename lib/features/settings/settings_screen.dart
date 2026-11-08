import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/settings_service.dart';
import '../../core/utilities/formatters.dart';
import '../../shared/providers/library_provider.dart';
import '../../core/services/ai_service.dart';
import '../../shared/providers/service_providers.dart';
import '../../shared/providers/settings_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  double? _thresholdDraft;

  Future<void> _rescan() async {
    final LibraryController controller = ref.read(libraryProvider.notifier);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Checking gallery and starting AI scan')),
    );
    await controller.refresh();
    if (!mounted) {
      return;
    }
    unawaited(controller.analyzePending(force: true));
  }

  Future<void> _confirmClearAi() async {
    final bool confirmed = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Clear AI results?'),
              content: const Text(
                'Categories, labels and confidence scores will be removed from '
                'the local database. Your photos are not changed. You can '
                'organize them again at any time.',
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Clear'),
                ),
              ],
            );
          },
        ) ??
        false;
    if (!confirmed) {
      return;
    }
    await ref.read(libraryProvider.notifier).clearAiResults();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI results cleared')),
      );
    }
  }

  Future<void> _confirmClearDuplicates() async {
    final bool confirmed = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Clear duplicate scan?'),
              content: const Text(
                'The last saved duplicate groups will be removed from the '
                'local database. Your photos are not changed.',
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Clear'),
                ),
              ],
            );
          },
        ) ??
        false;
    if (!confirmed) {
      return;
    }
    await ref.read(libraryProvider.notifier).clearDuplicateGroups();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved duplicate scan cleared')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<AppSettings> settingsAsync =
        ref.watch(settingsProvider);
    final LibraryState library = ref.watch(libraryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stack) => Center(
          child: Text(
            'Settings could not be loaded.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        data: (AppSettings settings) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 36),
            children: <Widget>[
              const _SectionTitle(
                title: 'AI & organization',
                subtitle: 'Scan your photos only when you choose to.',
              ),
              _SettingsGroup(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            const _TileIcon(icon: Icons.tune_rounded),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                'Confidence threshold',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                            ),
                            Text(
                              formatPercent(_effectiveThreshold(settings)),
                              style:
                                  Theme.of(context).textTheme.labelMedium?.copyWith(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                            ),
                          ],
                        ),
                        Slider(
                          value: _effectiveThreshold(settings),
                          min: 0.2,
                          max: 0.8,
                          divisions: 12,
                          label: formatPercent(_effectiveThreshold(settings)),
                          onChanged: (double value) {
                            setState(() {
                              _thresholdDraft = value;
                            });
                          },
                          onChangeEnd: (double value) {
                            unawaited(
                              ref
                                  .read(settingsProvider.notifier)
                                  .setConfidenceThreshold(value),
                            );
                            setState(() {
                              _thresholdDraft = null;
                            });
                          },
                        ),
                        Text(
                          'Higher values are stricter and show more uncertain results.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const _TileIcon(icon: Icons.batch_prediction_outlined),
                    title: const Text('Photos per scan session'),
                    subtitle: const Text(
                      'Limits battery use when organizing large libraries.',
                    ),
                    trailing: DropdownButton<int>(
                      value: _sessionOptions(settings).contains(
                        settings.sessionLimit,
                      )
                          ? settings.sessionLimit
                          : _sessionOptions(settings).first,
                      underline: const SizedBox.shrink(),
                      borderRadius: BorderRadius.circular(12),
                      items: _sessionOptions(settings)
                          .map(
                            (int value) => DropdownMenuItem<int>(
                              value: value,
                              child: Text('$value'),
                            ),
                          )
                          .toList(),
                      onChanged: (int? value) {
                        if (value == null) {
                          return;
                        }
                        unawaited(
                          ref
                              .read(settingsProvider.notifier)
                              .setSessionLimit(value),
                        );
                      },
                    ),
                  ),
                  if (library.isAnalyzing || library.pendingCount > 0) ...<Widget>[
                    const Divider(),
                    ListTile(
                      leading: const _TileIcon(
                        icon: Icons.pause_circle_outline_rounded,
                      ),
                      title: Text(
                        library.isAnalyzing ? 'Pause AI scan' : 'Resume AI scan',
                      ),
                      subtitle: Text(
                        library.pendingCount > 0
                            ? '${formatCount(library.pendingCount)} photos are waiting.'
                            : 'A session is currently running.',
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        if (library.isAnalyzing) {
                          ref.read(libraryProvider.notifier).pauseAnalysis();
                        } else {
                          unawaited(
                            ref
                                .read(libraryProvider.notifier)
                                .analyzePending(force: true),
                          );
                        }
                      },
                    ),
                  ],
                ],
              ),
              const _SectionTitle(
                title: 'Online AI (Gemini)',
                subtitle: 'More accurate photo detection. Needs internet.',
              ),
              const _SettingsGroup(
                children: <Widget>[
                  _OnlineAiTile(),
                ],
              ),
              const _SectionTitle(
                title: 'Gallery appearance',
                subtitle: 'Make the photo grid comfortable for you.',
              ),
              _SettingsGroup(
                children: <Widget>[
                  ListTile(
                    leading: const _TileIcon(icon: Icons.grid_view_rounded),
                    title: const Text('Grid columns'),
                    subtitle: const Text('Choose how densely photos are shown.'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <int>[2, 3, 4].map((int value) {
                        final bool selected = settings.galleryColumns == value;
                        return Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: GestureDetector(
                            onTap: () {
                              unawaited(
                                ref
                                    .read(settingsProvider.notifier)
                                    .setGalleryColumns(value),
                              );
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: selected
                                    ? AppColors.primary
                                    : AppColors.card,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '$value',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelMedium
                                    ?.copyWith(
                                      color: selected
                                          ? AppColors.white
                                          : AppColors.textSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const Divider(),
                  SwitchListTile.adaptive(
                    value: settings.newestFirst,
                    onChanged: (bool value) {
                      unawaited(
                        ref
                            .read(settingsProvider.notifier)
                            .setNewestFirst(value),
                      );
                    },
                    secondary: const _TileIcon(
                      icon: Icons.sort_rounded,
                    ),
                    title: const Text('Newest photos first'),
                    subtitle: const Text(
                      'You can still flip the order from the Gallery screen.',
                    ),
                  ),
                ],
              ),
              const _SectionTitle(
                title: 'Privacy & metadata',
                subtitle: 'You stay in control of local information.',
              ),
              _SettingsGroup(
                children: <Widget>[
                  const ListTile(
                    leading: _TileIcon(icon: Icons.shield_outlined),
                    title: Text('On-device by default'),
                    subtitle: Text(
                      'Photos stay on this phone unless online AI is turned on. '
                      'With a key, a small copy of each photo is sent to '
                      'Google Gemini to identify it.',
                    ),
                  ),
                  const Divider(),
                  SwitchListTile.adaptive(
                    value: settings.allowMetadata,
                    onChanged: (bool value) {
                      unawaited(
                        ref
                            .read(settingsProvider.notifier)
                            .setAllowMetadata(value),
                      );
                    },
                    secondary: const _TileIcon(
                      icon: Icons.camera_outlined,
                    ),
                    title: const Text('Read camera details'),
                    subtitle: const Text(
                      'Use local EXIF data for camera filters and photo details.',
                    ),
                  ),
                  const Divider(),
                  const ListTile(
                    leading: _TileIcon(icon: Icons.memory_rounded),
                    title: Text('Offline AI models'),
                    subtitle: Text(
                      'MobileNetV1 · AIY Plants · AIY Birds · bundled in the app',
                    ),
                  ),
                ],
              ),
              const _SectionTitle(
                title: 'Library data',
                subtitle: 'Manage the local index without changing photos.',
              ),
              _SettingsGroup(
                children: <Widget>[
                  ListTile(
                    leading: const _TileIcon(icon: Icons.sync_rounded),
                    title: const Text('Rescan library'),
                    subtitle: Text(
                      'Last checked ${formatRelative(library.lastScanAt)}.',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: _rescan,
                  ),
                  const Divider(),
                  ListTile(
                    leading: const _TileIcon(
                      icon: Icons.auto_delete_outlined,
                    ),
                    title: const Text('Clear AI results'),
                    subtitle: Text(
                      '${formatCount(library.analyzedCount)} photos currently have labels.',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: _confirmClearAi,
                  ),
                  const Divider(),
                  ListTile(
                    leading: const _TileIcon(
                      icon: Icons.content_copy_rounded,
                    ),
                    title: const Text('Clear saved duplicate scan'),
                    subtitle: const Text(
                      'Removes only the saved scan result from this app.',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: _confirmClearDuplicates,
                  ),
                  const Divider(),
                  ListTile(
                    leading: const _TileIcon(icon: Icons.cleaning_services_outlined),
                    title: const Text('Clear thumbnail cache'),
                    subtitle: const Text(
                      'Frees memory used by recently viewed thumbnails.',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () async {
                      final ScaffoldMessengerState messenger =
                          ScaffoldMessenger.of(context);
                      await ref.read(libraryProvider.notifier).runMemoryCleanup();
                      if (mounted) {
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Thumbnail cache cleared')),
                        );
                      }
                    },
                  ),
                ],
              ),
              const _SectionTitle(title: 'About'),
              const _SettingsGroup(
                children: <Widget>[
                  ListTile(
                    leading: _TileIcon(icon: Icons.info_outline_rounded),
                    title: Text('Photo Organizer'),
                    subtitle: Text(
                      'Version ${AppConstants.appVersion} · ${AppConstants.appTagline}',
                    ),
                  ),
                  Divider(),
                  ListTile(
                    leading: _TileIcon(icon: Icons.lock_outline_rounded),
                    title: Text('No account. No cloud. No tracking.'),
                    subtitle: Text(
                      'Photos, labels, favorites and duplicate scans stay in the app database on this phone.',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Center(
                child: Text(
                  'Built for private, offline photo organization.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textTertiary,
                      ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  double _effectiveThreshold(AppSettings settings) =>
      _thresholdDraft ?? settings.confidenceThreshold;

  List<int> _sessionOptions(AppSettings settings) {
    final List<int> options = <int>[40, 80, 120, 200, 300];
    if (!options.contains(settings.sessionLimit)) {
      options.add(settings.sessionLimit);
      options.sort();
    }
    return options;
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title.toUpperCase(),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.textTertiary,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
          ),
          if (subtitle != null) ...<Widget>[
            const SizedBox(height: 3),
            Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _TileIcon extends StatelessWidget {
  const _TileIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.primaryFaint,
        borderRadius: BorderRadius.circular(11),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 18, color: AppColors.primary),
    );
  }
}



class _OnlineAiTile extends ConsumerStatefulWidget {
  const _OnlineAiTile();

  @override
  ConsumerState<_OnlineAiTile> createState() => _OnlineAiTileState();
}

class _OnlineAiTileState extends ConsumerState<_OnlineAiTile> {
  bool _busy = false;
  String? _result;

  Future<void> _test() async {
    final AiService ai = ref.read(aiServiceProvider);
    setState(() {
      _busy = true;
      _result = null;
    });
    final String? error = await ai.testOnlineKey(ai.onlineApiKey ?? '');
    if (!mounted) {
      return;
    }
    setState(() {
      _busy = false;
      _result = error == null
          ? 'Online AI works. Gemini will identify the photos you add.'
          : 'Online AI failed: $error';
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool enabled = ref.watch(aiServiceProvider).onlineEnabled;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const _TileIcon(icon: Icons.cloud_outlined),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  enabled ? 'Online AI is on' : 'Online AI is off',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            enabled
                ? 'Photos are identified with Gemini first, with the offline '
                    'models as backup.'
                : 'No key was found in this build. Using offline AI only.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (enabled) ...<Widget>[
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy ? null : _test,
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Test online AI'),
            ),
          ],
          if (_result != null) ...<Widget>[
            const SizedBox(height: 10),
            Text(_result!, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}
