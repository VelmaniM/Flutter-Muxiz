import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../app/theme.dart';

class ShimmerBox extends StatelessWidget {
  final double? width;
  final double? height;
  final double borderRadius;
  final BoxShape shape;

  const ShimmerBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 8.0,
    this.shape = BoxShape.rectangle,
  });

  const ShimmerBox.circle({
    super.key,
    required double size,
  })  : width = size,
        height = size,
        borderRadius = 0,
        shape = BoxShape.circle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF222222),
        shape: shape,
        borderRadius: shape == BoxShape.rectangle
            ? BorderRadius.circular(borderRadius)
            : null,
      ),
    );
  }
}

/// High-Performance Cached Image with Instant Shimmer Skeleton Loading
class MuxizImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final double borderRadius;
  final BoxFit fit;
  final BoxShape shape;
  final Widget? errorWidget;

  const MuxizImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.borderRadius = 8.0,
    this.fit = BoxFit.cover,
    this.shape = BoxShape.rectangle,
    this.errorWidget,
  });

  const MuxizImage.circle({
    super.key,
    required this.imageUrl,
    required double size,
    this.fit = BoxFit.cover,
    this.errorWidget,
  })  : width = size,
        height = size,
        borderRadius = 0,
        shape = BoxShape.circle;

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return _buildFallback();
    }

    final int safeMemWidth = (width != null && width!.isFinite && width! > 0)
        ? (width! * 2).toInt().clamp(64, 600)
        : 400;
    final int safeMemHeight = (height != null && height!.isFinite && height! > 0)
        ? (height! * 2).toInt().clamp(64, 600)
        : 400;

    final imageWidget = CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      fadeInDuration: const Duration(milliseconds: 200),
      fadeOutDuration: const Duration(milliseconds: 100),
      memCacheWidth: safeMemWidth,
      memCacheHeight: safeMemHeight,
      maxWidthDiskCache: 600,
      maxHeightDiskCache: 600,
      httpHeaders: const {
        'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15',
      },
      placeholder: (context, url) => ShimmerBox(
        width: width,
        height: height,
        borderRadius: borderRadius,
        shape: shape,
      ),
      errorWidget: (context, url, error) => _buildFallback(),
    );

    if (shape == BoxShape.circle) {
      return ClipOval(child: imageWidget);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: imageWidget,
    );
  }

  Widget _buildFallback() {
    final double? safeWidth = (width != null && width!.isFinite) ? width : null;
    final double? safeHeight = (height != null && height!.isFinite) ? height : null;

    return Container(
      width: safeWidth,
      height: safeHeight,
      decoration: BoxDecoration(
        shape: shape,
        borderRadius: shape == BoxShape.rectangle ? BorderRadius.circular(borderRadius) : null,
        gradient: LinearGradient(
          colors: [
            const Color(0xFF282828),
            AppTheme.primaryGreen.withValues(alpha: 0.2),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.music_note_rounded,
          color: AppTheme.primaryGreen.withValues(alpha: 0.8),
          size: (safeWidth != null && safeWidth > 0) ? (safeWidth * 0.45).clamp(16.0, 48.0) : 24.0,
        ),
      ),
    );
  }
}
