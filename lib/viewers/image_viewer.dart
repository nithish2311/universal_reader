import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class ImageViewer extends StatefulWidget {
  final String filePath;
  final VoidCallback? onTap;

  const ImageViewer({
    super.key,
    required this.filePath,
    this.onTap,
  });

  @override
  State<ImageViewer> createState() => ImageViewerState();
}

class ImageViewerState extends State<ImageViewer> with SingleTickerProviderStateMixin {
  late TransformationController _transformController;
  int _rotationQuarterTurns = 0;
  bool _flipHorizontal = false;
  ui.Image? _decodedImage;
  int _fileSizeBytes = 0;

  @override
  void initState() {
    super.initState();
    _transformController = TransformationController();
    _loadImageMetadata();
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  Future<void> _loadImageMetadata() async {
    try {
      final file = File(widget.filePath);
      if (await file.exists()) {
        final stat = await file.stat();
        final bytes = await file.readAsBytes();
        final codec = await ui.instantiateImageCodec(bytes);
        final frameInfo = await codec.getNextFrame();
        if (mounted) {
          setState(() {
            _fileSizeBytes = stat.size;
            _decodedImage = frameInfo.image;
          });
        }
      }
    } catch (_) {}
  }

  void rotateClockwise() {
    setState(() {
      _rotationQuarterTurns = (_rotationQuarterTurns + 1) % 4;
    });
  }

  void flipHorizontal() {
    setState(() {
      _flipHorizontal = !_flipHorizontal;
    });
  }

  void resetZoom() {
    setState(() {
      _transformController.value = Matrix4.identity();
      _rotationQuarterTurns = 0;
      _flipHorizontal = false;
    });
  }

  void handleDoubleTap(TapDownDetails details) {
    if (_transformController.value != Matrix4.identity()) {
      _transformController.value = Matrix4.identity();
    } else {
      final position = details.localPosition;
      final zoomed = Matrix4.identity()
        ..translateByDouble(-position.dx * 1.5, -position.dy * 1.5, 0.0, 1.0)
        ..scaleByDouble(2.5, 2.5, 1.0, 1.0);
      _transformController.value = zoomed;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDark ? const Color(0xFF090D16) : const Color(0xFF0F172A),
      child: Stack(
        children: [
          GestureDetector(
            onTap: widget.onTap,
            onDoubleTapDown: handleDoubleTap,
            child: Center(
              child: InteractiveViewer(
                transformationController: _transformController,
                minScale: 0.5,
                maxScale: 8.0,
                child: RotatedBox(
                  quarterTurns: _rotationQuarterTurns,
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.diagonal3Values(_flipHorizontal ? -1.0 : 1.0, 1.0, 1.0),
                    child: Image.file(
                      File(widget.filePath),
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.broken_image_rounded, size: 64, color: Colors.white54),
                              const SizedBox(height: 12),
                              Text(
                                "Unable to render image: $error",
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Floating Quick Badges (top right corner)
          if (_decodedImage != null)
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.aspect_ratio_rounded, size: 14, color: Colors.white70),
                    const SizedBox(width: 6),
                    Text(
                      '${_decodedImage!.width} × ${_decodedImage!.height} • ${_formatSize(_fileSizeBytes)}',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
