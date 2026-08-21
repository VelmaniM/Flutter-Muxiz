import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../app/theme.dart';
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

  IconData _getIconData(String name) {
    switch (name) {
      case 'headphones': return Icons.headphones_rounded;
      case 'music_note': return Icons.music_note_rounded;
      case 'album': return Icons.album_rounded;
      case 'mic': return Icons.mic_rounded;
      case 'radio': return Icons.radio_rounded;
      case 'equalizer': return Icons.graphic_eq_rounded;
      case 'favorite': return Icons.favorite_rounded;
      case 'star': return Icons.star_rounded;
      case 'fire': return Icons.local_fire_department_rounded;
      case 'bolt': return Icons.bolt_rounded;
      case 'diamond': return Icons.diamond_rounded;
      case 'rocket': return Icons.rocket_launch_rounded;
      case 'speaker': return Icons.speaker_rounded;
      case 'piano': return Icons.piano_rounded;
      default: return Icons.headphones_rounded;
    }
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
      } else if (avatarUrl.startsWith('icon:')) {
        final parts = avatarUrl.split(':');
        final iconName = parts.length > 1 ? parts[1] : 'headphones';
        final iconData = _getIconData(iconName);
        imageContent = Center(
          child: Icon(
            iconData,
            color: AppTheme.primaryGreen,
            size: size * 0.55,
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


