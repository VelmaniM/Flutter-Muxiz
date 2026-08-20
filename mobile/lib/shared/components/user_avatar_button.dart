import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/storage/local_storage.dart';
import '../../features/profile/presentation/profile_screen.dart';

class UserAvatarButton extends ConsumerWidget {
  final double size;

  const UserAvatarButton({
    super.key,
    this.size = 36.0,
  });

  Widget _buildInitialFallback(String initial) {
    return Center(
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.44,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avatarUrl = ref.watch(userAvatarProvider);
    final userName = ref.watch(userNameProvider);
    final initial = (userName.isNotEmpty ? userName[0] : 'V').toUpperCase();

    Widget imageContent;
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      if (avatarUrl.startsWith('emoji:')) {
        final emoji = avatarUrl.replaceFirst('emoji:', '');
        imageContent = Center(
          child: Text(
            emoji,
            style: TextStyle(fontSize: size * 0.52),
          ),
        );
      } else if (avatarUrl.startsWith('http')) {
        imageContent = CachedNetworkImage(
          imageUrl: avatarUrl,
          key: ValueKey(avatarUrl),
          fit: BoxFit.cover,
          width: size,
          height: size,
          memCacheWidth: (size * 2).toInt(),
          memCacheHeight: (size * 2).toInt(),
          fadeInDuration: Duration.zero,
          fadeOutDuration: Duration.zero,
          placeholder: (context, url) => _buildInitialFallback(initial),
          errorWidget: (context, url, error) => _buildInitialFallback(initial),
        );
      } else {
        imageContent = Image.file(
          File(avatarUrl),
          key: ValueKey(avatarUrl),
          fit: BoxFit.cover,
          width: size,
          height: size,
          errorBuilder: (context, error, stackTrace) => _buildInitialFallback(initial),
        );
      }
    } else {
      imageContent = _buildInitialFallback(initial);
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (ctx) => const ProfileScreen()),
        );
      },
      child: ClipOval(
        child: Container(
          width: size,
          height: size,
          color: const Color(0xFF1E1E1E),
          child: imageContent,
        ),
      ),
    );
  }
}


