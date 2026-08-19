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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avatarUrl = ref.watch(userAvatarProvider);
    final userName = ref.watch(userNameProvider);
    final initial = (userName.isNotEmpty ? userName[0] : 'V').toUpperCase();

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (ctx) => const ProfileScreen()),
        );
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black,
          border: Border.all(color: Colors.white24, width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: avatarUrl != null && avatarUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: avatarUrl,
                fit: BoxFit.cover,
                width: size,
                height: size,
                placeholder: (context, url) => Container(
                  color: Colors.black,
                  child: Center(
                    child: Text(
                      initial,
                      style: TextStyle(color: Colors.white, fontSize: size * 0.45, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.black,
                  child: Center(
                    child: Text(
                      initial,
                      style: TextStyle(color: Colors.white, fontSize: size * 0.45, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              )
            : Center(
                child: Text(
                  initial,
                  style: TextStyle(color: Colors.white, fontSize: size * 0.48, fontWeight: FontWeight.bold),
                ),
              ),
      ),
    );
  }
}

