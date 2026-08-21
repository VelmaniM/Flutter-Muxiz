import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme.dart';
import '../../../core/data/mock_catalog.dart';
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

          // Studio Server Connection Section
          _buildSectionHeader('Studio Server Connection'),
          ListTile(
            leading: const Icon(Icons.cloud_sync_rounded, color: AppTheme.primaryGreen, size: 22),
            title: const Text('Server Address', style: TextStyle(color: Colors.white, fontSize: 15)),
            subtitle: Text(
              MockMusicCatalog.activeServerHost,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
            trailing: const Icon(Icons.edit_rounded, color: AppTheme.textSecondary, size: 20),
            onTap: () => _showServerConfigDialog(),
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

  void _showServerConfigDialog() {
    final controller = TextEditingController(text: MockMusicCatalog.activeServerHost);
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF242424),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Studio Server IP / URL', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter the IP address of your Mac running Muxiz Studio (e.g. http://192.168.1.50:5001)',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12.5),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'http://192.168.1.x:5001',
                  hintStyle: const TextStyle(color: Colors.white30),
                  filled: true,
                  fillColor: const Color(0xFF1E1E1E),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              onPressed: () async {
                final newHost = controller.text.trim().replaceAll(RegExp(r'/+$'), '');
                if (newHost.isNotEmpty) {
                  MockMusicCatalog.activeServerHost = newHost;
                  await LocalStorageService.saveServerHost(newHost);
                  MockMusicCatalog.initializeCatalog(forceRefresh: true);
                  setState(() {});
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: const Text('Save & Connect', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }
}
