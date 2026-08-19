import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import '../../../app/theme.dart';

/// WhatsApp / Instagram style Circular Profile Photo Cropper & Resizer
class ProfileImageCropperDialog extends StatefulWidget {
  final File imageFile;

  const ProfileImageCropperDialog({
    super.key,
    required this.imageFile,
  });

  static Future<File?> show(BuildContext context, File imageFile) {
    return Navigator.push<File>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (ctx) => ProfileImageCropperDialog(imageFile: imageFile),
      ),
    );
  }

  @override
  State<ProfileImageCropperDialog> createState() => _ProfileImageCropperDialogState();
}

class _ProfileImageCropperDialogState extends State<ProfileImageCropperDialog> {
  final GlobalKey _cropKey = GlobalKey();
  final TransformationController _transformController = TransformationController();
  int _rotationQuarterTurns = 0;
  bool _isProcessing = false;

  void _rotateImage() {
    setState(() {
      _rotationQuarterTurns = (_rotationQuarterTurns + 1) % 4;
    });
  }

  void _resetZoom() {
    _transformController.value = Matrix4.identity();
    setState(() {
      _rotationQuarterTurns = 0;
    });
  }

  Future<void> _captureCroppedImage() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final boundary = _cropKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        Navigator.pop(context, widget.imageFile);
        return;
      }

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        if (mounted) Navigator.pop(context, widget.imageFile);
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final targetFile = File('${tempDir.path}/cropped_avatar_${DateTime.now().millisecondsSinceEpoch}.png');
      await targetFile.writeAsBytes(byteData.buffer.asUint8List());

      if (mounted) {
        Navigator.pop(context, targetFile);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context, widget.imageFile);
      }
    }
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final cropAreaSize = screenSize.width * 0.85;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    'Move and Scale',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.2,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.rotate_right_rounded, color: Colors.white, size: 26),
                    tooltip: 'Rotate 90°',
                    onPressed: _rotateImage,
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Interactive Viewport with Circular Mask & Guides
            Center(
              child: SizedBox(
                width: cropAreaSize,
                height: cropAreaSize,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // The RepaintBoundary capturing the exact circular crop
                    RepaintBoundary(
                      key: _cropKey,
                      child: ClipOval(
                        child: Container(
                          width: cropAreaSize,
                          height: cropAreaSize,
                          color: Colors.black,
                          child: InteractiveViewer(
                            transformationController: _transformController,
                            minScale: 0.8,
                            maxScale: 4.5,
                            boundaryMargin: const EdgeInsets.all(double.infinity),
                            clipBehavior: Clip.none,
                            child: Center(
                              child: RotatedBox(
                                quarterTurns: _rotationQuarterTurns,
                                child: Image.file(
                                  widget.imageFile,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // WhatsApp / Instagram style circular border guide
                    IgnorePointer(
                      child: Container(
                        width: cropAreaSize,
                        height: cropAreaSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppTheme.primaryGreen.withValues(alpha: 0.9),
                            width: 2.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryGreen.withValues(alpha: 0.3),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),
            const Text(
              'Pinch to zoom • Drag to reposition',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),

            const Spacer(),

            // Bottom Actions Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              color: const Color(0xFF121212),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: _resetZoom,
                    icon: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 20),
                    label: const Text(
                      'Reset',
                      style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: _isProcessing ? null : _captureCroppedImage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    child: _isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
                        )
                      : const Text(
                          'Choose Photo',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
