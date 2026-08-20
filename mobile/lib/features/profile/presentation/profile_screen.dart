import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme.dart';
import '../../../core/data/mock_catalog.dart';
import '../../../core/storage/local_storage.dart';
import '../../../shared/components/album_card.dart';
import '../../../shared/components/artist_avatar.dart';
import '../../details/presentation/playlist_detail_screen.dart';
import '../../auth/presentation/login_screen.dart';
import 'profile_image_cropper.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isUploadingAvatar = false;
  final ImagePicker _picker = ImagePicker();

  void _showProfilePhotoOptions(String? avatarUrl, String displayName) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF181818),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Profile Photo',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 16),

                // SAMPLE AVATAR EMOJIS PICKER
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Choose Avatar Emoji',
                    style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 52,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: const [
                      '🎧', '🎸', '🎵', '⚡', '👑', '🔥', 
                      '🕶️', '💎', '🦁', '🐯', '🚀', '💿', 
                      '🎙️', '🐺', '🦊', '🐉', '👾', '🪐', 
                      '🌊', '☕', '✨', '⭐', '💫', '🎉',
                    ].length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (ctx, idx) {
                      const sampleEmojis = [
                        '🎧', '🎸', '🎵', '⚡', '👑', '🔥', 
                        '🕶️', '💎', '🦁', '🐯', '🚀', '💿', 
                        '🎙️', '🐺', '🦊', '🐉', '👾', '🪐', 
                        '🌊', '☕', '✨', '⭐', '💫', '🎉',
                      ];
                      final em = sampleEmojis[idx];
                      final isSelected = avatarUrl == 'emoji:$em';
                      return InkWell(
                        onTap: () async {
                          Navigator.pop(ctx);
                          await ref.read(userAvatarProvider.notifier).setAvatar('emoji:$em');
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    Text(em, style: const TextStyle(fontSize: 20)),
                                    const SizedBox(width: 10),
                                    Text('Avatar updated to $em! ✨', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                                backgroundColor: const Color(0xFF1E1E1E),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        borderRadius: BorderRadius.circular(26),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected ? AppTheme.primaryGreen.withValues(alpha: 0.25) : const Color(0xFF242424),
                            border: Border.all(
                              color: isSelected ? AppTheme.primaryGreen : Colors.white12,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Center(
                            child: Text(em, style: const TextStyle(fontSize: 22)),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),
                const Divider(color: Colors.white10, height: 1),
                const SizedBox(height: 10),

                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.photo_library_rounded, color: AppTheme.primaryGreen, size: 22),
                  ),
                  title: Text(
                    avatarUrl != null && avatarUrl.isNotEmpty ? 'Upload Custom Photo' : 'Upload Photo from Device',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  subtitle: const Text(
                    'Pick any photo from your device gallery or files',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12.5),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAndUploadAvatar(displayName);
                  },
                ),
                if (avatarUrl != null && avatarUrl.isNotEmpty) ...[
                  const Divider(color: Colors.white10, height: 16),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 22),
                    ),
                    title: const Text(
                      'Remove Current Photo',
                      style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600, fontSize: 16),
                    ),
                    subtitle: const Text(
                      'Reset to clean default round profile icon with black background',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12.5),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      _removeAvatar();
                    },
                  ),
                ],
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _removeAvatar() async {
    setState(() {
      _isUploadingAvatar = true;
    });

    try {
      try {
        final docsDir = await getApplicationDocumentsDirectory();
        final permanentFile = File('${docsDir.path}/user_profile_avatar.png');
        if (await permanentFile.exists()) {
          await permanentFile.delete();
        }
      } catch (_) {}

      await ref.read(userAvatarProvider.notifier).setAvatar(null);

      // Async backend remove
      final dio = Dio();
      const endpoints = [
        'http://192.168.1.94:5001/api/v1/uploads/avatar',
        'https://flutter-muxiz.onrender.com/api/v1/uploads/avatar',
        'http://localhost:5001/api/v1/uploads/avatar',
      ];
      for (final ep in endpoints) {
        try {
          await dio.delete(ep, data: {'userId': LocalStorageService.getUserId()});
          break;
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _isUploadingAvatar = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: AppTheme.primaryGreen, size: 20),
                SizedBox(width: 10),
                Text('Profile photo removed successfully! ✨', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ],
            ),
            backgroundColor: const Color(0xFF1E1E1E),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploadingAvatar = false;
        });
      }
    }
  }

  Future<void> _pickAndUploadAvatar(String displayName) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 95,
      );

      if (image == null) return;

      File finalFile = File(image.path);
      try {
        if (mounted) {
          final cropped = await ProfileImageCropperDialog.show(context, finalFile);
          if (cropped != null) {
            finalFile = cropped;
          }
        }
      } catch (_) {}

      setState(() {
        _isUploadingAvatar = true;
      });

      // 1. Permanently copy to Application Documents Directory so it survives app restarts
      final docsDir = await getApplicationDocumentsDirectory();
      try {
        final existingFiles = docsDir.listSync();
        for (final f in existingFiles) {
          if (f.path.contains('user_profile_avatar')) {
            try {
              f.deleteSync();
            } catch (_) {}
          }
        }
      } catch (_) {}

      final permanentFile = File('${docsDir.path}/user_profile_avatar_${DateTime.now().millisecondsSinceEpoch}.png');
      await finalFile.copy(permanentFile.path);

      // Instant local persistence & global reactive update across all pages
      await ref.read(userAvatarProvider.notifier).setAvatar(permanentFile.path);

      if (mounted) {
        setState(() {
          _isUploadingAvatar = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: AppTheme.primaryGreen, size: 20),
                SizedBox(width: 10),
                Text('Profile photo updated successfully! ✨', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ],
            ),
            backgroundColor: const Color(0xFF1E1E1E),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 3),
          ),
        );
      }

      // Background cloud sync (safe, non-blocking)
      try {
        final dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ));

        final formData = FormData.fromMap({
          'file': await MultipartFile.fromFile(
            permanentFile.path,
            filename: 'avatar_${DateTime.now().millisecondsSinceEpoch}.png',
          ),
          'userId': LocalStorageService.getUserId(),
          'displayName': displayName,
        });

        const endpoints = [
          'http://192.168.1.94:5001/api/v1/uploads/avatar',
          'https://flutter-muxiz.onrender.com/api/v1/uploads/avatar',
          'http://localhost:5001/api/v1/uploads/avatar',
        ];

        for (final ep in endpoints) {
          try {
            final res = await dio.post(ep, data: formData);
            if (res.statusCode == 200 || res.statusCode == 201) {
              final uploadedUrl = res.data['avatarUrl'] as String?;
              if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
                await ref.read(userAvatarProvider.notifier).setAvatar(uploadedUrl);
              }
              break;
            }
          } catch (_) {}
        }
      } catch (_) {}
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploadingAvatar = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update photo: $e', style: const TextStyle(color: Colors.white)),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showEditNameDialog(String currentName) {
    final textController = TextEditingController(text: currentName);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF161616),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Edit Display Name',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Enter the name you would like to display on your profile.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: textController,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Enter your name',
                  hintStyle: const TextStyle(color: AppTheme.textSecondary),
                  filled: true,
                  fillColor: const Color(0xFF222222),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 1.5),
                  ),
                  prefixIcon: const Icon(Icons.person_outline, color: AppTheme.primaryGreen),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                  onPressed: () async {
                    final newName = textController.text.trim();
                    if (newName.isEmpty) return;

                    Navigator.pop(ctx);
                    await ref.read(userNameProvider.notifier).setName(newName);

                    // Sync with backend asynchronously
                    try {
                      final dio = Dio();
                      const endpoints = [
                        'https://flutter-muxiz.onrender.com/api/v1/uploads/profile',
                        'http://localhost:5001/api/v1/uploads/profile',
                        'http://192.168.1.94:5001/api/v1/uploads/profile',
                      ];
                      for (final ep in endpoints) {
                        try {
                          await dio.post(ep, data: {
                            'userId': LocalStorageService.getUserId(),
                            'displayName': newName,
                          });
                          break;
                        } catch (_) {}
                      }
                    } catch (_) {}

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Row(
                            children: [
                              Icon(Icons.check_circle, color: AppTheme.primaryGreen, size: 20),
                              SizedBox(width: 10),
                              Text('Name updated successfully! ✨', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                            ],
                          ),
                          backgroundColor: Color(0xFF1E1E1E),
                          behavior: SnackBarBehavior.floating,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  child: const Text(
                    'Save Changes',
                    style: TextStyle(color: Colors.black, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAvatarWidget(String? avatarUrl, String displayName) {
    final initial = (displayName.isNotEmpty ? displayName[0] : 'V').toUpperCase();

    Widget imageContent;
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      if (avatarUrl.startsWith('emoji:')) {
        final emoji = avatarUrl.replaceFirst('emoji:', '');
        imageContent = Container(
          color: const Color(0xFF1E1E1E),
          child: Center(
            child: Text(
              emoji,
              style: const TextStyle(fontSize: 56),
            ),
          ),
        );
      } else if (avatarUrl.startsWith('http')) {
        imageContent = CachedNetworkImage(
          imageUrl: avatarUrl,
          key: ValueKey(avatarUrl),
          fit: BoxFit.cover,
          width: 112,
          height: 112,
          placeholder: (context, url) => Container(
            color: Colors.black,
            child: const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryGreen, strokeWidth: 2),
            ),
          ),
          errorWidget: (context, url, error) => Container(
            color: Colors.black,
            child: Center(
              child: Text(
                initial,
                style: const TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        );
      } else {
        imageContent = Image.file(
          File(avatarUrl),
          key: ValueKey(avatarUrl),
          fit: BoxFit.cover,
          width: 112,
          height: 112,
          errorBuilder: (context, error, stackTrace) => Container(
            color: Colors.black,
            child: Center(
              child: Text(
                initial,
                style: const TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        );
      }
    } else {
      imageContent = Container(
        color: Colors.black,
        child: Center(
          child: Text(
            initial,
            style: const TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () => _showProfilePhotoOptions(avatarUrl, displayName),
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipOval(
            child: Container(
              width: 116,
              height: 116,
              color: Colors.black,
              child: _isUploadingAvatar
                  ? Container(
                      color: Colors.black87,
                      child: const Center(
                        child: CircularProgressIndicator(color: AppTheme.primaryGreen, strokeWidth: 3),
                      ),
                    )
                  : imageContent,
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.background, width: 3),
                boxShadow: const [
                  BoxShadow(color: Colors.black45, blurRadius: 6, offset: Offset(0, 2)),
                ],
              ),
              child: const Icon(Icons.camera_alt_rounded, size: 18, color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl = ref.watch(userAvatarProvider);
    final displayName = ref.watch(userNameProvider);
    final playlists = ref.watch(customPlaylistsProvider);
    final artists = MockMusicCatalog.popularArtists;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top Navigation Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    'Profile',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: Colors.white, size: 22),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => _showEditNameDialog(displayName),
                  ),
                ],
              ),
            ),

            // Scrollable Profile Details
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    const SizedBox(height: 16),

                    // Interactive Profile Avatar with Camera Badge
                    _buildAvatarWidget(avatarUrl, displayName),
                    const SizedBox(height: 16),

                    // Display Name with edit pen
                    GestureDetector(
                      onTap: () => _showEditNameDialog(displayName),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            displayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.edit_rounded, color: AppTheme.primaryGreen, size: 18),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Followers / Following
                    const Text(
                      '14 Followers  •  28 Following',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Edit Profile and Share Action Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white38),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                          ),
                          onPressed: () => _showEditNameDialog(displayName),
                          icon: const Icon(Icons.edit, size: 15, color: Colors.white),
                          label: const Text('Edit profile', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          icon: const Icon(Icons.share_outlined, color: Colors.white70),
                          onPressed: () {},
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // Public Playlists Section (Only when playlists exist)
                    if (playlists.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Public Playlists',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            TextButton(
                              onPressed: () {},
                              child: const Text(
                                'See all',
                                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 210,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          itemCount: playlists.length,
                          itemBuilder: (context, index) {
                            final playlist = playlists[index];
                            return Padding(
                              padding: const EdgeInsets.only(right: 14.0),
                              child: AlbumCard(
                                title: playlist.title,
                                subtitle: '${playlist.songs.length} songs',
                                imageUrl: playlist.coverUrl,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => PlaylistDetailScreen(playlist: playlist),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Recently Played Artists (Only when artists exist)
                    if (artists.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.0),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Recently played artists',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 140,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          itemCount: artists.length,
                          itemBuilder: (context, index) {
                            final artist = artists[index];
                            return Padding(
                              padding: const EdgeInsets.only(right: 16.0),
                              child: ArtistAvatar(
                                name: artist.name,
                                imageUrl: artist.imageUrl,
                                radius: 45,
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],

                    // Log Out Button
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.redAccent, width: 1.2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          minimumSize: const Size(double.infinity, 46),
                        ),
                        onPressed: () async {
                          await LocalStorageService.logout();
                          if (context.mounted) {
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(builder: (ctx) => const LoginScreen()),
                              (route) => false,
                            );
                          }
                        },
                        icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
                        label: const Text(
                          'Log out of Muxiz',
                          style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    ),

                    const SizedBox(height: 60),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
