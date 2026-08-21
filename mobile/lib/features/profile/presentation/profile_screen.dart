import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/local_storage.dart';
import 'profile_image_cropper.dart';



class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isUploadingAvatar = false;
  final ImagePicker _picker = ImagePicker();

  static const List<String> _kPresetEmojis = [
    '🎧', '🎸', '🎵', '⚡', '👑', '🔥', 
    '🕶️', '💎', '🦁', '🐯', '🚀', '💿', 
    '🎙️', '🐺', '🦊', '🐉', '👾', '🪐', 
    '🌊', '☕', '✨', '⭐', '💫', '🎉',
  ];

  static const List<({String name, IconData icon, String label})> _kMusicIcons = [
    (name: 'headphones', icon: Icons.headphones_rounded, label: 'Headphones'),
    (name: 'music_note', icon: Icons.music_note_rounded, label: 'Music Note'),
    (name: 'album', icon: Icons.album_rounded, label: 'Vinyl Album'),
    (name: 'mic', icon: Icons.mic_rounded, label: 'Microphone'),
    (name: 'equalizer', icon: Icons.graphic_eq_rounded, label: 'Equalizer'),
    (name: 'fire', icon: Icons.local_fire_department_rounded, label: 'Fire Beats'),
    (name: 'bolt', icon: Icons.bolt_rounded, label: 'Energy Bolt'),
    (name: 'diamond', icon: Icons.diamond_rounded, label: 'Diamond VIP'),
    (name: 'rocket', icon: Icons.rocket_launch_rounded, label: 'Rocket'),
    (name: 'star', icon: Icons.star_rounded, label: 'Star Artist'),
    (name: 'speaker', icon: Icons.speaker_rounded, label: 'Subwoofer'),
    (name: 'piano', icon: Icons.piano_rounded, label: 'Keyboard'),
    (name: 'radio', icon: Icons.radio_rounded, label: 'Radio Broadcast'),
    (name: 'favorite', icon: Icons.favorite_rounded, label: 'Heart Beats'),
  ];

  IconData _getIconData(String name) {
    for (final item in _kMusicIcons) {
      if (item.name == name) return item.icon;
    }
    return Icons.headphones_rounded;
  }

  void _showProfilePhotoOptions(String? avatarUrl, String displayName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF181818),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _AvatarPickerModal(
        initialAvatarUrl: avatarUrl,
        displayName: displayName,
        onPhotoUpload: () {
          Navigator.pop(ctx);
          _pickAndUploadAvatar(displayName);
        },
        onSelectAvatarString: (newAvatarString) async {
          Navigator.pop(ctx);
          await _applyAvatar(newAvatarString, displayName);
        },
        onRemoveAvatar: () {
          Navigator.pop(ctx);
          _removeAvatar();
        },
      ),
    );
  }

  Future<void> _applyAvatar(String avatarValue, String displayName) async {
    setState(() => _isUploadingAvatar = true);
    await ref.read(userAvatarProvider.notifier).setAvatar(avatarValue);

    // Sync to PostgreSQL DB and Drive
    try {
      final userId = LocalStorageService.getUserId();
      await ref.read(apiClientProvider).updateProfile(
        userId: userId.isNotEmpty ? userId : 'listener-001',
        displayName: displayName,
        avatar: avatarValue,
      );
    } catch (_) {}

    if (mounted) {
      setState(() => _isUploadingAvatar = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: AppTheme.primaryGreen, size: 20),
              SizedBox(width: 10),
              Text('Avatar updated & synced to Cloud DB! ✨', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ],
          ),
          backgroundColor: Color(0xFF1E1E1E),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _removeAvatar() async {
    setState(() => _isUploadingAvatar = true);

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
      try {
        final dio = Dio();
        final userId = LocalStorageService.getUserId();
        const endpoints = [
          'http://192.168.1.94:5001/api/v1/uploads/avatar',
          'https://flutter-muxiz.onrender.com/api/v1/uploads/avatar',
          'http://localhost:5001/api/v1/uploads/avatar',
        ];
        for (final ep in endpoints) {
          try {
            await dio.delete(ep, data: {'userId': userId});
            break;
          } catch (_) {}
        }
      } catch (_) {}

      if (mounted) {
        setState(() => _isUploadingAvatar = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: AppTheme.primaryGreen, size: 20),
                SizedBox(width: 10),
                Text('Profile photo reset to default! ✨', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ],
            ),
            backgroundColor: Color(0xFF1E1E1E),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _isUploadingAvatar = false);
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

      setState(() => _isUploadingAvatar = true);

      // 1. Permanently copy to Application Documents Directory so it survives app restarts
      final docsDir = await getApplicationDocumentsDirectory();
      try {
        final existingFiles = docsDir.listSync();
        for (final f in existingFiles) {
          if (f.path.contains('user_profile_avatar')) {
            try { f.deleteSync(); } catch (_) {}
          }
        }
      } catch (_) {}

      final permanentFile = File('${docsDir.path}/user_profile_avatar_${DateTime.now().millisecondsSinceEpoch}.png');
      await finalFile.copy(permanentFile.path);

      // Instant local persistence & global reactive update across all pages
      await ref.read(userAvatarProvider.notifier).setAvatar(permanentFile.path);

      if (mounted) {
        setState(() => _isUploadingAvatar = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: AppTheme.primaryGreen, size: 20),
                SizedBox(width: 10),
                Text('Profile photo updated & uploading to Google Drive! ☁️✨', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ],
            ),
            backgroundColor: Color(0xFF1E1E1E),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
            duration: Duration(seconds: 3),
          ),
        );
      }

      // Background Google Drive & DB upload
      try {
        final dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 15),
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
        setState(() => _isUploadingAvatar = false);
      }
    }
  }

  void _showEditNameDialog(String currentName) {
    final controller = TextEditingController(text: currentName);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF181818),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20.0,
            right: 20.0,
            top: 20.0,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24.0,
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
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Enter your name',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF242424),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                  onPressed: () async {
                    final newName = controller.text.trim();
                    if (newName.isEmpty) return;
                    Navigator.pop(ctx);
                    await ref.read(userNameProvider.notifier).setName(newName);
                    await LocalStorageService.saveUserName(newName);

                    try {
                      final userId = LocalStorageService.getUserId();
                      await ref.read(apiClientProvider).updateProfile(
                        userId: userId.isNotEmpty ? userId : 'listener-001',
                        displayName: newName,
                      );
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
                  child: const Text('Save Changes', style: TextStyle(color: Colors.black, fontSize: 15, fontWeight: FontWeight.bold)),
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
        final parts = avatarUrl.replaceFirst('emoji:', '').split(':');
        final emoji = parts[0];
        final scale = parts.length > 1 ? (double.tryParse(parts[1]) ?? 56.0) : 56.0;
        imageContent = Container(
          color: const Color(0xFF1E1E1E),
          child: Center(
            child: Text(
              emoji,
              style: TextStyle(fontSize: scale),
            ),
          ),
        );
      } else if (avatarUrl.startsWith('icon:')) {
        final parts = avatarUrl.split(':');
        final iconName = parts.length > 1 ? parts[1] : 'headphones';
        final iconSize = parts.length > 2 ? (double.tryParse(parts[2]) ?? 54.0) : 54.0;
        final iconData = _getIconData(iconName);
        imageContent = Container(
          color: const Color(0xFF1A1A22),
          child: Center(
            child: Icon(
              iconData,
              color: AppTheme.primaryGreen,
              size: iconSize,
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
        color: const Color(0xFF1E1E1E),
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
    final email = LocalStorageService.getUserEmail();
    final favCount = LocalStorageService.getFavoriteSongIds().length;
    final downloadedCount = LocalStorageService.getDownloadedSongs().length;
    final recentsCount = LocalStorageService.getRecentlyPlayed().length;
    final customPlaylists = LocalStorageService.getCustomPlaylists();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top Navigation Bar (Clean, no pencil icon)
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
                  const SizedBox(width: 24), // Balance spacing
                ],
              ),
            ),

            // Scrollable Profile Details
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  children: [
                    const SizedBox(height: 16),

                    // Interactive Profile Avatar with Camera Badge
                    _buildAvatarWidget(avatarUrl, displayName),
                    const SizedBox(height: 16),

                    // Display Name (Clean, NO pencil icon next to name!)
                    Text(
                      displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // User Email or Listener Badge
                    Text(
                      email.isNotEmpty ? email : 'Muxiz VIP Listener',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Edit Profile Action Button
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white24),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      ),
                      onPressed: () => _showEditNameDialog(displayName),
                      icon: const Icon(Icons.edit_rounded, size: 14, color: AppTheme.primaryGreen),
                      label: const Text('Edit Name', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(height: 28),

                    // SECTION 1: YOUR MUSIC STATS (Real, authentic dynamic metrics)
                    _buildSectionHeader('Your Music Stats', Icons.insights_rounded),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard('Liked Songs', '$favCount', Icons.favorite_rounded, Colors.redAccent),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildStatCard('Playlists', '${customPlaylists.length}', Icons.queue_music_rounded, AppTheme.primaryGreen),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard('Downloaded', '$downloadedCount', Icons.download_done_rounded, Colors.cyanAccent),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildStatCard('Recently Played', '$recentsCount', Icons.history_rounded, Colors.amberAccent),
                        ),
                      ],
                    ),
                    const SizedBox(height: 140),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primaryGreen, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String count, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: const Color(0xFF16161C),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                ),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Dynamic Multi-Tab Avatar Picker with Live Resize Slider & Emoji/Icon Customization
class _AvatarPickerModal extends StatefulWidget {
  final String? initialAvatarUrl;
  final String displayName;
  final VoidCallback onPhotoUpload;
  final ValueChanged<String> onSelectAvatarString;
  final VoidCallback onRemoveAvatar;

  const _AvatarPickerModal({
    required this.initialAvatarUrl,
    required this.displayName,
    required this.onPhotoUpload,
    required this.onSelectAvatarString,
    required this.onRemoveAvatar,
  });

  @override
  State<_AvatarPickerModal> createState() => _AvatarPickerModalState();
}

class _AvatarPickerModalState extends State<_AvatarPickerModal> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _customEmojiController = TextEditingController();
  
  double _iconSize = 54.0;
  String _selectedIcon = 'headphones';

  double _emojiSize = 56.0;
  String _selectedEmoji = '🎧';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _customEmojiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.72,
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        child: Column(
          children: [
            // Drag handle
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),

            const Text(
              'Customize Profile Avatar',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            // Tab Bar
            TabBar(
              controller: _tabController,
              indicatorColor: AppTheme.primaryGreen,
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: AppTheme.primaryGreen,
              unselectedLabelColor: Colors.white60,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              tabs: const [
                Tab(icon: Icon(Icons.music_note_rounded, size: 18), text: 'Music Icons'),
                Tab(icon: Icon(Icons.emoji_emotions_rounded, size: 18), text: 'Emoji Avatar'),
                Tab(icon: Icon(Icons.photo_library_rounded, size: 18), text: 'Custom Photo'),
              ],
            ),
            const SizedBox(height: 12),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // TAB 1: MUSIC ICONS WITH LIVE RESIZE
                  _buildMusicIconsTab(),

                  // TAB 2: EMOJIS WITH CUSTOM TEXT INPUT & RESIZE
                  _buildEmojiTab(),

                  // TAB 3: CUSTOM PHOTO UPLOAD
                  _buildPhotoTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMusicIconsTab() {
    return Column(
      children: [
        // Live Preview & Size Slider
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF22222A),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: const BoxDecoration(
                  color: Color(0xFF16161C),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    _getIconForName(_selectedIcon),
                    color: AppTheme.primaryGreen,
                    size: _iconSize * 0.75,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Icon Size / Scale', style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600)),
                        Text('${_iconSize.toInt()}px', style: const TextStyle(color: AppTheme.primaryGreen, fontSize: 12.5, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Slider(
                      value: _iconSize,
                      min: 30,
                      max: 68,
                      activeColor: AppTheme.primaryGreen,
                      inactiveColor: Colors.white12,
                      onChanged: (val) => setState(() => _iconSize = val),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Grid of Music Icons
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.1,
            ),
            itemCount: _ProfileScreenState._kMusicIcons.length,
            itemBuilder: (ctx, idx) {
              final item = _ProfileScreenState._kMusicIcons[idx];
              final isSelected = _selectedIcon == item.name;
              return InkWell(
                onTap: () {
                  setState(() => _selectedIcon = item.name);
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primaryGreen.withValues(alpha: 0.2) : const Color(0xFF22222A),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? AppTheme.primaryGreen : Colors.white12,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(item.icon, color: isSelected ? AppTheme.primaryGreen : Colors.white, size: 26),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isSelected ? AppTheme.primaryGreen : Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),

        // Apply Button
        SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(23)),
            ),
            onPressed: () {
              widget.onSelectAvatarString('icon:$_selectedIcon:${_iconSize.toInt()}');
            },
            child: const Text('Apply Icon Avatar', style: TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildEmojiTab() {
    return Column(
      children: [
        // Live Preview & Size Slider
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF22222A),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: const BoxDecoration(
                  color: Color(0xFF16161C),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    _selectedEmoji,
                    style: TextStyle(fontSize: _emojiSize * 0.7),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Emoji Size / Scale', style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600)),
                        Text('${_emojiSize.toInt()}px', style: const TextStyle(color: AppTheme.primaryGreen, fontSize: 12.5, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Slider(
                      value: _emojiSize,
                      min: 32,
                      max: 72,
                      activeColor: AppTheme.primaryGreen,
                      inactiveColor: Colors.white12,
                      onChanged: (val) => setState(() => _emojiSize = val),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Custom Emoji Text Input Field
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _customEmojiController,
                maxLength: 2,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, color: Colors.white),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: 'Type any custom emoji (e.g. 🦊)',
                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                  filled: true,
                  fillColor: const Color(0xFF22222A),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.primaryGreen),
                  ),
                ),
                onChanged: (val) {
                  if (val.trim().isNotEmpty) {
                    setState(() => _selectedEmoji = val.trim());
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Grid of Presets
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 6,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: _ProfileScreenState._kPresetEmojis.length,
            itemBuilder: (ctx, idx) {
              final em = _ProfileScreenState._kPresetEmojis[idx];
              final isSelected = _selectedEmoji == em;
              return InkWell(
                onTap: () {
                  setState(() => _selectedEmoji = em);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primaryGreen.withValues(alpha: 0.25) : const Color(0xFF22222A),
                    borderRadius: BorderRadius.circular(12),
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
        const SizedBox(height: 8),

        // Apply Button
        SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(23)),
            ),
            onPressed: () {
              widget.onSelectAvatarString('emoji:$_selectedEmoji:${_emojiSize.toInt()}');
            },
            child: const Text('Apply Emoji Avatar', style: TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoTab() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          tileColor: const Color(0xFF22222A),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.photo_library_rounded, color: AppTheme.primaryGreen, size: 24),
          ),
          title: const Text('Upload Custom Photo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
          subtitle: const Text('Crop, zoom, rotate & upload to Google Drive', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white54),
          onTap: widget.onPhotoUpload,
        ),
        if (widget.initialAvatarUrl != null && widget.initialAvatarUrl!.isNotEmpty) ...[
          const SizedBox(height: 14),
          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            tileColor: const Color(0xFF22222A),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 24),
            ),
            title: const Text('Reset to Default Avatar', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600, fontSize: 15)),
            subtitle: const Text('Clear custom image and restore clean letter icon', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white54),
            onTap: widget.onRemoveAvatar,
          ),
        ],
      ],
    );
  }

  IconData _getIconForName(String name) {
    for (final item in _ProfileScreenState._kMusicIcons) {
      if (item.name == name) return item.icon;
    }
    return Icons.headphones_rounded;
  }
}
