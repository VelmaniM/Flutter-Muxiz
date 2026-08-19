import 'package:flutter/material.dart';
import '../../app/theme.dart';
import 'shimmer_box.dart';

class ArtistAvatar extends StatelessWidget {
  final String name;
  final String imageUrl;
  final VoidCallback? onTap;
  final double radius;

  const ArtistAvatar({
    super.key,
    required this.name,
    required this.imageUrl,
    this.onTap,
    this.radius = 44,
  });

  @override
  Widget build(BuildContext context) {
    final double diameter = radius * 2;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: diameter,
        margin: const EdgeInsets.only(right: 14.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: diameter,
              height: diameter,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white12, width: 1.0),
              ),
              child: MuxizImage.circle(
                imageUrl: imageUrl,
                size: diameter,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 12.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
