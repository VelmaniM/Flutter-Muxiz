import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Synchronized Animated Shimmer Wave Effect Provider
class ShimmerLoading extends StatefulWidget {
  final Widget child;
  const ShimmerLoading({super.key, required this.child});

  static ShimmerLoadingScope? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ShimmerLoadingScope>();
  }

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController.unbounded(vsync: this)
      ..repeat(min: -0.5, max: 1.5, period: const Duration(milliseconds: 1400));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ShimmerLoadingScope(
      animation: _controller,
      child: widget.child,
    );
  }
}

class ShimmerLoadingScope extends InheritedWidget {
  final Animation<double> animation;
  const ShimmerLoadingScope({
    super.key,
    required this.animation,
    required super.child,
  });

  @override
  bool updateShouldNotify(ShimmerLoadingScope oldWidget) => true;
}

/// Smooth Animated Shimmer Box Element
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
    final parentScope = ShimmerLoading.of(context);

    if (parentScope != null) {
      return AnimatedBuilder(
        animation: parentScope.animation,
        builder: (context, child) {
          final double value = parentScope.animation.value;
          return Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              shape: shape,
              borderRadius: shape == BoxShape.rectangle
                  ? BorderRadius.circular(borderRadius)
                  : null,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: [
                  (value - 0.3).clamp(0.0, 1.0),
                  value.clamp(0.0, 1.0),
                  (value + 0.3).clamp(0.0, 1.0),
                ],
                colors: const [
                  Color(0xFF18181F),
                  Color(0xFF282832),
                  Color(0xFF18181F),
                ],
              ),
            ),
          );
        },
      );
    }

    // Lightweight high-performance static placeholder container (Zero Ticker overhead)
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A22),
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

    // Standardize memory cache dimensions into discrete buckets (prevents re-decode flicker)
    final int safeMemWidth = (width != null && width! <= 64)
        ? 128
        : ((width != null && width! <= 180) ? 360 : 600);
    final int safeMemHeight = (height != null && height! <= 64)
        ? 128
        : ((height != null && height! <= 180) ? 360 : 600);

    final String cleanUrl = imageUrl
        .replaceAll('/1400x1400bb.jpg', '/600x600bb.jpg')
        .replaceAll('/100x100bb', '/600x600bb');

    Widget imageWidget;
    if (cleanUrl.startsWith('data:image')) {
      try {
        final commaIdx = cleanUrl.indexOf(',');
        final base64Str = commaIdx != -1 ? cleanUrl.substring(commaIdx + 1) : cleanUrl;
        final Uint8List bytes = base64Decode(base64Str);
        imageWidget = Image.memory(
          bytes,
          key: ValueKey(cleanUrl),
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (context, error, stackTrace) => _buildFallback(),
        );
      } catch (_) {
        imageWidget = _buildFallback();
      }
    } else {
      imageWidget = CachedNetworkImage(
        key: ValueKey(cleanUrl),
        cacheKey: cleanUrl,
        imageUrl: cleanUrl,
        width: width,
        height: height,
        fit: fit,
        fadeInDuration: const Duration(milliseconds: 150),
        fadeOutDuration: const Duration(milliseconds: 150),
        memCacheWidth: safeMemWidth,
        memCacheHeight: safeMemHeight,
        maxWidthDiskCache: 600,
        maxHeightDiskCache: 600,
        placeholder: (context, url) => ShimmerBox(
          width: width,
          height: height,
          borderRadius: borderRadius,
          shape: shape,
        ),
        errorWidget: (context, url, error) => _buildFallback(),
      );
    }

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
    final bool isCircle = shape == BoxShape.circle;

    return Container(
      width: safeWidth,
      height: safeHeight,
      decoration: BoxDecoration(
        shape: shape,
        borderRadius: isCircle ? null : BorderRadius.circular(borderRadius),
        color: const Color(0xFF141414),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Center(
        child: Icon(
          isCircle ? Icons.person_rounded : Icons.music_note_rounded,
          color: Colors.white38,
          size: (safeWidth != null && safeWidth > 0) ? (safeWidth * 0.45).clamp(16.0, 48.0) : 24.0,
        ),
      ),
    );
  }
}

/// Full-Page Spotify-Style Shimmer & Skeleton Screen for Home Feed
class HomeSkeletonView extends StatelessWidget {
  final String statusText;
  const HomeSkeletonView({
    super.key,
    this.statusText = 'Studio Server Offline • Toggle "Server ON" in Studio to load tracks',
  });

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.only(top: 8.0, bottom: 140.0),
        children: [
          // Offline / Connecting Status Banner
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
            decoration: BoxDecoration(
              color: const Color(0xFF1F1A14),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.sensors_off_rounded, color: Color(0xFFF59E0B), size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    statusText,
                    style: const TextStyle(
                      color: Color(0xFFFDE68A),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Shimmer Greeting Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                ShimmerBox(width: 170, height: 26, borderRadius: 6),
                ShimmerBox(width: 90, height: 24, borderRadius: 12),
              ],
            ),
          ),

          // 6 Quick-Play Shimmer Cards Grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 6,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 3.1,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemBuilder: (ctx, i) {
                return Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF222222),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      const ShimmerBox(width: 56, height: 56, borderRadius: 0),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            ShimmerBox(width: 90, height: 12, borderRadius: 3),
                            SizedBox(height: 6),
                            ShimmerBox(width: 60, height: 10, borderRadius: 3),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 12),

          // Shelf 1: Shimmer Recommended Tracks
          _buildShimmerSectionHeader('Recommended for Today'),
          SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: 16.0),
              itemCount: 5,
              itemBuilder: (ctx, i) => _buildShimmerAlbumCard(),
            ),
          ),

          const SizedBox(height: 16),

          // Shelf 2: Shimmer Popular Artists
          _buildShimmerSectionHeader('Popular Artists'),
          SizedBox(
            height: 140,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: 16.0),
              itemCount: 6,
              itemBuilder: (ctx, i) => _buildShimmerArtistAvatar(),
            ),
          ),

          const SizedBox(height: 16),

          // Shelf 3: Shimmer Trending Songs List
          _buildShimmerSectionHeader('Trending Tracks'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              children: List.generate(5, (index) => _buildShimmerSongTile()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 12.0, bottom: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const ShimmerBox(width: 45, height: 14, borderRadius: 4),
        ],
      ),
    );
  }

  Widget _buildShimmerAlbumCard() {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          ShimmerBox(width: 140, height: 140, borderRadius: 8),
          SizedBox(height: 8),
          ShimmerBox(width: 110, height: 12, borderRadius: 3),
          SizedBox(height: 5),
          ShimmerBox(width: 75, height: 10, borderRadius: 3),
        ],
      ),
    );
  }

  Widget _buildShimmerArtistAvatar() {
    return Container(
      margin: const EdgeInsets.only(right: 16.0),
      child: Column(
        children: const [
          ShimmerBox.circle(size: 88),
          SizedBox(height: 8),
          ShimmerBox(width: 65, height: 11, borderRadius: 3),
        ],
      ),
    );
  }

  Widget _buildShimmerSongTile() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          const ShimmerBox(width: 48, height: 48, borderRadius: 6),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                ShimmerBox(width: 140, height: 13, borderRadius: 3),
                SizedBox(height: 6),
                ShimmerBox(width: 90, height: 11, borderRadius: 3),
              ],
            ),
          ),
          const ShimmerBox(width: 28, height: 12, borderRadius: 3),
        ],
      ),
    );
  }
}

/// Full-Page Shimmer Skeleton for Search Screen
class SearchSkeletonView extends StatelessWidget {
  const SearchSkeletonView({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.only(top: 16.0, left: 16.0, right: 16.0, bottom: 140.0),
        children: [
          const ShimmerBox(width: double.infinity, height: 46, borderRadius: 8),
          const SizedBox(height: 24),
          const ShimmerBox(width: 140, height: 20, borderRadius: 4),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 6,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.6,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemBuilder: (ctx, i) => const ShimmerBox(
              width: double.infinity,
              height: double.infinity,
              borderRadius: 8,
            ),
          ),
        ],
      ),
    );
  }
}
