import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/services/ai_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utilities/formatters.dart';
import '../../core/utilities/slug_utils.dart';
import '../../shared/models/ai_models.dart';
import '../../shared/models/app_category.dart';
import '../../shared/providers/library_provider.dart';
import '../../shared/providers/service_providers.dart';
import '../../shared/providers/settings_provider.dart';

class AiIdentificationScreen extends ConsumerStatefulWidget {
  const AiIdentificationScreen({super.key});

  @override
  ConsumerState<AiIdentificationScreen> createState() =>
      _AiIdentificationScreenState();
}

class _AiIdentificationScreenState
    extends ConsumerState<AiIdentificationScreen> {
  final ImagePicker _picker = ImagePicker();
  Uint8List? _bytes;
  String? _fileName;
  String? _mimeType;
  String? _path;
  AiIdentification? _result;
  String? _error;
  bool _busy = false;
  bool _saved = false;

  Future<void> _pick(ImageSource source) async {
    if (_busy) {
      return;
    }
    setState(() {
      _error = null;
    });
    try {
      if (source == ImageSource.camera) {
        final PermissionStatus status = await Permission.camera.request();
        if (!status.isGranted) {
          if (mounted) {
            setState(() {
              _error =
                  'Camera access is needed to take a photo. You can still choose an existing photo.';
            });
          }
          return;
        }
      }
      final XFile? file = await _picker.pickImage(
        source: source,
        imageQuality: 95,
        maxWidth: 2400,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (file == null) {
        return;
      }
      final Uint8List bytes = await file.readAsBytes();
      if (!mounted) {
        return;
      }
      setState(() {
        _bytes = bytes;
        _fileName = file.name;
        _mimeType = file.mimeType;
        _path = file.path;
        _result = null;
        _saved = false;
        _error = null;
      });
    } on PlatformException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message ?? 'Could not open the camera or gallery.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Could not read that image. Try another photo.';
        });
      }
    }
  }

  Future<void> _identify() async {
    final Uint8List? bytes = _bytes;
    if (bytes == null || _busy) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
      _saved = false;
    });
    try {
      final double threshold =
          ref.read(settingsProvider).valueOrNull?.confidenceThreshold ??
              0.35;
      final AiIdentification result =
          await ref.read(aiServiceProvider).classifyBytes(
                bytes,
                confidenceThreshold: threshold,
                thorough: true,
                extension: normalizedExtension(
                  _fileName ?? 'photo.jpg',
                  _mimeType,
                ),
              );
      if (!mounted) {
        return;
      }
      setState(() {
        _result = result;
        _busy = false;
      });
      try {
        await ref.read(libraryProvider.notifier).saveAiResult(
              identification: result,
              filePath: _path,
            );
        if (mounted) {
          setState(() {
            _saved = true;
          });
        }
      } catch (_) {
        // The result is still useful even if persistence fails.
      }
    } on AiException catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = error.message;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error =
              'The on-device AI could not analyze this image. Try a JPG, PNG or WEBP photo.';
        });
      }
    }
  }

  void _reset() {
    setState(() {
      _bytes = null;
      _fileName = null;
      _mimeType = null;
      _path = null;
      _result = null;
      _error = null;
      _saved = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Identification'),
        actions: <Widget>[
          IconButton(
            onPressed: () => _showPrivacy(context),
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: 'How this works',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (_bytes == null) ...<Widget>[
              Text(
                'Identify anything, privately',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Choose a photo or use the camera. Real offline AI models run '
                'entirely on this phone.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 22),
              _PickerPlaceholder(
                onGallery: () => _pick(ImageSource.gallery),
                onCamera: () => _pick(ImageSource.camera),
              ),
            ] else ...<Widget>[
              _SelectedImage(
                bytes: _bytes!,
                busy: _busy,
                onReplace: () => _pick(ImageSource.gallery),
                onRemove: _reset,
              ),
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy
                          ? null
                          : () => _pick(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined, size: 18),
                      label: const Text('Change'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(46),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy
                          ? null
                          : () => _pick(ImageSource.camera),
                      icon: const Icon(Icons.photo_camera_outlined, size: 18),
                      label: const Text('Retake'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(46),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _busy ? null : _identify,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.white,
                        ),
                      )
                    : const Icon(Icons.auto_awesome_rounded, size: 20),
                label: Text(_busy ? 'Analyzing on device…' : 'Identify with AI'),
              ),
            ],
            if (_error != null) ...<Widget>[
              const SizedBox(height: 16),
              _ErrorCard(message: _error!),
            ],
            if (_result != null) ...<Widget>[
              const SizedBox(height: 22),
              _ResultCard(
                result: _result!,
                saved: _saved,
                onCopyFilename: () {
                  Clipboard.setData(
                    ClipboardData(text: _result!.suggestedFilename),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Filename copied')),
                  );
                },
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _reset,
                icon: const Icon(Icons.add_photo_alternate_outlined, size: 19),
                label: const Text('Identify another photo'),
              ),
            ],
            const SizedBox(height: 28),
            Row(
              children: <Widget>[
                const Icon(
                  Icons.shield_outlined,
                  size: 15,
                  color: AppColors.textTertiary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'No network permission. No uploads. Results stay in this app.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showPrivacy(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Private on-device AI',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(
                'Photo Organizer bundles a general image classifier and '
                'specialist plant and bird classifiers. They run locally with '
                'TensorFlow Lite. Your photo is resized in memory, analyzed, '
                'and never uploaded.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              const _PrivacyPoint(
                icon: Icons.wifi_off_rounded,
                text: 'The app has no internet permission.',
              ),
              const _PrivacyPoint(
                icon: Icons.memory_rounded,
                text: 'Models and labels are stored inside the app.',
              ),
              const _PrivacyPoint(
                icon: Icons.auto_awesome_rounded,
                text: 'Confidence can be low. Verify unusual results.',
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PickerPlaceholder extends StatelessWidget {
  const _PickerPlaceholder({
    required this.onGallery,
    required this.onCamera,
  });

  final Future<void> Function() onGallery;
  final Future<void> Function() onCamera;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 34, 24, 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[AppColors.primaryFaint, AppColors.card],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primarySoft),
      ),
      child: Column(
        children: <Widget>[
          Container(
            width: 78,
            height: 78,
            decoration: const BoxDecoration(
              color: AppColors.white,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Stack(
              alignment: Alignment.center,
              children: <Widget>[
                Icon(
                  Icons.add_photo_alternate_outlined,
                  size: 34,
                  color: AppColors.primary,
                ),
                Positioned(
                  right: 0,
                  top: 2,
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    size: 17,
                    color: AppColors.secondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Choose a photo',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            'Objects, animals, plants, food and more.',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => onGallery(),
              icon: const Icon(Icons.photo_library_outlined, size: 19),
              label: const Text('Choose from gallery'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => onCamera(),
              icon: const Icon(Icons.photo_camera_outlined, size: 19),
              label: const Text('Take a photo'),
              style: OutlinedButton.styleFrom(
                backgroundColor: AppColors.white,
                minimumSize: const Size.fromHeight(52),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedImage extends StatelessWidget {
  const _SelectedImage({
    required this.bytes,
    required this.busy,
    required this.onReplace,
    required this.onRemove,
  });

  final Uint8List bytes;
  final bool busy;
  final VoidCallback onReplace;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Image.memory(
              bytes,
              fit: BoxFit.cover,
              gaplessPlayback: true,
            ),
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.48),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      Icons.memory_rounded,
                      size: 13,
                      color: Colors.white,
                    ),
                    SizedBox(width: 5),
                    Text(
                      'On-device',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 8,
              left: 8,
              child: Material(
                color: Colors.black.withOpacity(0.4),
                shape: const CircleBorder(),
                child: IconButton(
                  onPressed: busy ? null : onRemove,
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                  tooltip: 'Remove photo',
                  constraints: const BoxConstraints.tightFor(
                    width: 34,
                    height: 34,
                  ),
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
            if (busy) const Positioned.fill(child: _ScanningOverlay()),
            if (!busy)
              Positioned(
                bottom: 10,
                right: 10,
                child: Material(
                  color: Colors.black.withOpacity(0.42),
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    onTap: onReplace,
                    borderRadius: BorderRadius.circular(20),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            Icons.swap_horiz_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Change',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 10,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ScanningOverlay extends StatefulWidget {
  const _ScanningOverlay();

  @override
  State<_ScanningOverlay> createState() => _ScanningOverlayState();
}

class _ScanningOverlayState extends State<_ScanningOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.34),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (BuildContext context, Widget? child) {
            return Stack(
              children: <Widget>[
                Align(
                  alignment: Alignment(0, _controller.value * 2 - 1),
                  child: Container(
                    height: 2,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: <Color>[
                          Colors.transparent,
                          AppColors.secondary,
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                const Align(
                  alignment: Alignment(0, 0.55),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Analyzing on device…',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.result,
    required this.saved,
    required this.onCopyFilename,
  });

  final AiIdentification result;
  final bool saved;
  final VoidCallback onCopyFilename;

  @override
  Widget build(BuildContext context) {
    final Color tint = result.category.tint;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.primaryFaint,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  size: 17,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'AI result',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              if (saved)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 13,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Saved',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.primary,
                            fontSize: 10,
                          ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            result.primaryLabel,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: <Widget>[
              _Pill(
                icon: result.category.icon,
                label: result.category.label,
                tint: tint,
              ),
              _Pill(
                icon: Icons.sell_outlined,
                label: result.subcategory,
                tint: AppColors.textSecondary,
              ),
              _Pill(
                icon: Icons.bolt_rounded,
                label: '${result.inferenceMs} ms',
                tint: AppColors.textSecondary,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Text(
                'Confidence',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const Spacer(),
              Text(
                formatPercent(result.confidence),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: tint,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: result.confidence.clamp(0, 1).toDouble(),
              minHeight: 6,
              backgroundColor: AppColors.card,
              valueColor: AlwaysStoppedAnimation<Color>(tint),
            ),
          ),
          if (result.uncertain) ...<Widget>[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warningSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'The model is not fully sure. Use this as a suggestion.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textPrimary,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          Text(
            result.description,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (result.labels.length > 1) ...<Widget>[
            const SizedBox(height: 18),
            Text(
              'Possible matches',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 10),
            for (final LabelScore label in result.labels.take(5))
              _LabelRow(label: label, tint: tint),
          ],
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.edit_document,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    result.suggestedFilename,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: AppColors.textPrimary,
                          fontFamily: 'monospace',
                          fontSize: 11,
                        ),
                  ),
                ),
                IconButton(
                  onPressed: onCopyFilename,
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  tooltip: 'Copy filename',
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label, required this.tint});

  final IconData icon;
  final String label;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: tint.withOpacity(0.09),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 12, color: tint),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontSize: 10.5,
                  color: tint,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }
}

class _LabelRow extends StatelessWidget {
  const _LabelRow({required this.label, required this.tint});

  final LabelScore label;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 126,
            child: Text(
              humanizeLabel(label.label),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textPrimary,
                  ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: label.confidence.clamp(0, 1).toDouble(),
                minHeight: 4,
                backgroundColor: AppColors.card,
                valueColor: AlwaysStoppedAnimation<Color>(
                  tint.withOpacity(0.65),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 34,
            child: Text(
              formatPercent(label.confidence),
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                    color: AppColors.textTertiary,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.dangerSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: AppColors.danger,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textPrimary,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivacyPoint extends StatelessWidget {
  const _PrivacyPoint({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
