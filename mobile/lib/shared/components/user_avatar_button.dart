import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../features/profile/presentation/profile_screen.dart';

class UserAvatarButton extends StatelessWidget {
  final double size;

  const UserAvatarButton({
    super.key,
    this.size = 36.0,
  });

  @override
  Widget build(BuildContext context) {
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
          gradient: const LinearGradient(
            colors: [AppTheme.primaryGreen, Color(0xFF007A33)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: Colors.white24, width: 1.5),
        ),
        child: Center(
          child: Icon(Icons.person, color: Colors.black, size: size * 0.55),
        ),
      ),
    );
  }
}
