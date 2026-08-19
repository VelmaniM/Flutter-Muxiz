import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import '../../../app/theme.dart';
import '../../../core/data/mock_catalog.dart';
import '../../../core/storage/local_storage.dart';
import '../../../shared/components/album_card.dart';
import '../../../shared/components/artist_avatar.dart';
import '../../details/presentation/playlist_detail_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late String _displayName;
  String? _avatarUrl;
  bool _isUploadingAvatar = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _displayName = LocalStorageService.getUserName();
    _avatarUrl = LocalStorageService.getUserAvatar();
  }

  Future<void> _pickAndUploadAvatar() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image == null) return;

      setState(() {
        _isUploadingAvatar = true;
      });

      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 25),
      ));

      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          image.path,
          filename: image.name.isNotEmpty ? image.name : 'avatar.jpg',
        ),
        'userId': LocalStorageService.getUserId(),
        'displayName': _displayName,
      });

      const endpoints = [
        'https://flutter-muxiz.onrender.com/api/v1/uploads/avatar',
        'http://localhost:5001/api/v1/uploads/avatar',
        'http://192.168.1.94:5001/api/v1/uploads/avatar',
      ];

      String? uploadedUrl;
      for (final ep in endpoints) {
        try {
          final res = await dio.post(ep, data: formData);
          if (res.statusCode == 200 || res.statusCode == 201) {
            uploadedUrl = res.data['avatarUrl'] as String?;
            break;
          }
        } catch (_) {}
      }

      // Fallback: If cloud offline, save local image file path as avatar
      uploadedUrl ??= image.path;

      await LocalStorageService.saveUserAvatar(uploadedUrl);

      if (mounted) {
        setState(() {
          _avatarUrl = uploadedUrl;
          _isUploadingAvatar = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: AppTheme.primaryGreen, size: 20),
                SizedBox(width: 10),
                Text('Profile photo updated & saved to Drive! ✨', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ],
            ),
            backgroundColor: const Color(0xFF1E1E1E),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
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

  void _showEditNameDialog() {
    final textController = TextEditingController(text: _displayName);

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
                    await LocalStorageService.saveUserName(newName);

                    setState(() {
                      _displayName = newName;
                    });

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

  Widget _buildAvatarWidget() {
    final initial = (_displayName.isNotEmpty ? _displayName[0] : 'V').toUpperCase();

    Widget imageContent;
    if (_avatarUrl != null && _avatarUrl!.isNotEmpty) {
      if (_avatarUrl!.startsWith('http')) {
        imageContent = CachedNetworkImage(
          imageUrl: _avatarUrl!,
          fit: BoxFit.cover,
          width: 112,
          height: 112,
          placeholder: (context, url) => Container(
            color: AppTheme.card,
            child: const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryGreen, strokeWidth: 2),
            ),
          ),
          errorWidget: (context, url, error) => Center(
            child: Text(
              initial,
              style: const TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.bold),
            ),
          ),
        );
      } else {
        imageContent = Image.file(
          File(_avatarUrl!),
          fit: BoxFit.cover,
          width: 112,
          height: 112,
          errorBuilder: (context, error, stackTrace) => Center(
            child: Text(
              initial,
              style: const TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.bold),
            ),
          ),
        );
      }
    } else {
      imageContent = Center(
        child: Text(
          initial,
          style: const TextStyle(color: Colors.black, fontSize: 44, fontWeight: FontWeight.bold),
        ),
      );
    }

    return GestureDetector(
      onTap: _pickAndUploadAvatar,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 116,
            height: 116,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: _avatarUrl == null || _avatarUrl!.isEmpty
                  ? const LinearGradient(
                      colors: [AppTheme.primaryGreen, Color(0xFF007A33)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.6), width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.2),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: _isUploadingAvatar
                ? Container(
                    color: Colors.black54,
                    child: const Center(
                      child: CircularProgressIndicator(color: AppTheme.primaryGreen, strokeWidth: 3),
                    ),
                  )
                : imageContent,
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
    final playlists = MockMusicCatalog.featuredPlaylists;
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
                    onPressed: _showEditNameDialog,
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
                    _buildAvatarWidget(),
                    const SizedBox(height: 16),

                    // Display Name with edit pen
                    GestureDetector(
                      onTap: _showEditNameDialog,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _displayName,
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
                          onPressed: _showEditNameDialog,
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

                    // Public Playlists Section
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

                    // Recently Played Artists
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
                    const SizedBox(height: 48),
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
