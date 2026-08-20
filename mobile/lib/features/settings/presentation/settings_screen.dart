import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme.dart';
import '../../../core/storage/local_storage.dart';
import '../../../shared/components/user_avatar_button.dart';
import '../../profile/presentation/profile_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _offlineMode = false;
  bool _gaplessPlayback = true;
  bool _automix = true;
  double _crossfade = 0.0;
  String _audioQuality = 'Very High (320 kbps)';

  @override
  Widget build(BuildContext context) {
    final userName = ref.watch(userNameProvider);
    final displayName = userName.isNotEmpty ? userName : 'Music Listener';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: const Color(0xFF181818),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Settings', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: ListView(
        children: [
          // Account Tile with live UserAvatarButton
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: const UserAvatarButton(size: 48),
            title: Text(displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            subtitle: const Text('View Profile • Premium Individual', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (ctx) => const ProfileScreen()),
              );
            },
          ),
          const Divider(color: AppTheme.divider, height: 1),

          // Playback Section
          _buildSectionHeader('Playback'),
          SwitchListTile(
            title: const Text('Offline Mode', style: TextStyle(color: Colors.white, fontSize: 15)),
            subtitle: const Text('Only play music that you\'ve downloaded.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12.5)),
            value: _offlineMode,
            activeThumbColor: AppTheme.primaryGreen,
            onChanged: (val) {
              setState(() {
                _offlineMode = val;
              });
            },
          ),
          SwitchListTile(
            title: const Text('Gapless Playback', style: TextStyle(color: Colors.white, fontSize: 15)),
            subtitle: const Text('Allows continuous audio between tracks.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12.5)),
            value: _gaplessPlayback,
            activeThumbColor: AppTheme.primaryGreen,
            onChanged: (val) {
              setState(() {
                _gaplessPlayback = val;
              });
            },
          ),
          SwitchListTile(
            title: const Text('Automix', style: TextStyle(color: Colors.white, fontSize: 15)),
            subtitle: const Text('Allows smooth transitions between songs.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12.5)),
            value: _automix,
            activeThumbColor: AppTheme.primaryGreen,
            onChanged: (val) {
              setState(() {
                _automix = val;
              });
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Crossfade', style: TextStyle(color: Colors.white, fontSize: 15)),
                    Text('${_crossfade.toInt()}s', style: const TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.bold)),
                  ],
                ),
                Slider(
                  value: _crossfade,
                  min: 0,
                  max: 12,
                  divisions: 12,
                  activeColor: AppTheme.primaryGreen,
                  inactiveColor: Colors.white24,
                  onChanged: (val) {
                    setState(() {
                      _crossfade = val;
                    });
                  },
                ),
              ],
            ),
          ),
          const Divider(color: AppTheme.divider, height: 24),

          // Audio Quality Section
          _buildSectionHeader('Audio Quality'),
          ListTile(
            title: const Text('Streaming Quality', style: TextStyle(color: Colors.white, fontSize: 15)),
            subtitle: Text(_audioQuality, style: const TextStyle(color: AppTheme.primaryGreen, fontSize: 12.5)),
            trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
            onTap: () => _showQualityPicker(),
          ),
          const Divider(color: AppTheme.divider, height: 24),

          // Storage Section
          _buildSectionHeader('Storage & Cache'),
          ListTile(
            title: const Text('Clear Cache', style: TextStyle(color: Colors.white, fontSize: 15)),
            subtitle: const Text('Free up storage without deleting downloaded songs.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12.5)),
            trailing: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white30),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              onPressed: () async {
                await LocalStorageService.clearAllPlaybackAndCache();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Cache & playback memory cleared successfully!'),
                      backgroundColor: AppTheme.card,
                    ),
                  );
                }
              },
              child: const Text('Clear Cache', style: TextStyle(color: Colors.white, fontSize: 12)),
            ),
          ),

          const SizedBox(height: 12),
          // Account / Session Section
          _buildSectionHeader('Storage & Cache'),
          ListTile(
            leading: const Icon(Icons.cleaning_services_rounded, color: AppTheme.primaryGreen, size: 22),
            title: const Text('Clear Playback Cache', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            subtitle: const Text('Free up local storage without affecting saved playlists', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            onTap: () async {
              await LocalStorageService.clearAllPlaybackAndCache();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Playback cache cleared!'),
                    backgroundColor: Color(0xFF1E1E1E),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 6),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showQualityPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF282828),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final options = [
          'Automatic (Recommended)',
          'Low (24 kbps)',
          'Normal (96 kbps)',
          'High (160 kbps)',
          'Very High (320 kbps)',
        ];

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: options.map((opt) {
              final isSelected = opt == _audioQuality;
              return ListTile(
                title: Text(
                  opt,
                  style: TextStyle(
                    color: isSelected ? AppTheme.primaryGreen : Colors.white,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                trailing: isSelected ? const Icon(Icons.check_rounded, color: AppTheme.primaryGreen) : null,
                onTap: () {
                  setState(() {
                    _audioQuality = opt;
                  });
                  Navigator.pop(ctx);
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }
}
