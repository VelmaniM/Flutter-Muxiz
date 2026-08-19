import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import '../../../app/constants.dart';
import '../../../app/theme.dart';
import '../../../core/audio/audio_manager.dart';
import '../../../core/data/mock_catalog.dart';
import '../../../core/services/recommendation_service.dart';
import '../../../shared/models/song.dart';
import '../../../shared/components/user_avatar_button.dart';
import '../../../shared/components/song_tile.dart';
import '../../settings/presentation/settings_screen.dart';

class QueuedUpload {
  final PlatformFile file;
  String status; // 'pending', 'processing', 'completed', 'error'
  double progress;
  String statusMessage;
  Song? song;
  String? errorMessage;

  QueuedUpload({
    required this.file,
    this.status = 'pending',
    this.progress = 0.0,
    this.statusMessage = 'Waiting in queue...',
    this.song,
    this.errorMessage,
  });
}

class UploadScreen extends ConsumerStatefulWidget {
  const UploadScreen({super.key});

  @override
  ConsumerState<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends ConsumerState<UploadScreen> {
  final List<QueuedUpload> _uploadQueue = [];
  bool _isProcessingQueue = false;
  final List<Song> _recentUploads = [];

  Future<void> _pickAndProcessSongs() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav', 'm4a', 'aac', 'flac'],
        allowMultiple: true,
      );

      if (result == null || result.files.isEmpty) return;

      setState(() {
        for (final file in result.files) {
          _uploadQueue.add(QueuedUpload(
            file: file,
            status: 'pending',
            statusMessage: 'In Queue (Ready for upload)',
          ));
        }
      });

      _processNextInQueue();
    } catch (e) {
      debugPrint('Error picking files: $e');
    }
  }

  Future<void> _processNextInQueue() async {
    if (_isProcessingQueue) return;

    _isProcessingQueue = true;

    // Process up to 3 songs concurrently in parallel for high speed
    final pendingItems = _uploadQueue.where((q) => q.status == 'pending').toList();

    Future<void> processSingle(QueuedUpload item) async {
      if (item.status == 'completed') return;

      setState(() {
        item.status = 'processing';
        item.progress = 0.20;
        item.statusMessage = 'Reading audio bytes...';
      });

      try {
        Uint8List? audioBytes = item.file.bytes;
        if (audioBytes == null && item.file.path != null) {
          audioBytes = await File(item.file.path!).readAsBytes();
        }

        if (audioBytes == null) {
          throw Exception('Could not read audio file bytes.');
        }

        setState(() {
          item.progress = 0.40;
          item.statusMessage = 'Uploading to Drive & Cloud DB...';
        });

        final dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 40),
          sendTimeout: const Duration(seconds: 120),
          receiveTimeout: const Duration(seconds: 120),
        ));

        final cleanTitle = item.file.name.replaceAll(RegExp(r'[/\\?%*:|"<>]+'), '_');
        final realAudioPath = item.file.path;
        String? backendSongId;
        String? finalAudioUrl;
        String? finalArtworkUrl;
        bool backendSaved = false;

        final candidateUrls = [
          AppConstants.defaultApiBaseUrl,
          ...AppConstants.fallbackApiBaseUrls,
        ];

        // Direct high-speed multipart upload
        for (final baseUrl in candidateUrls) {
          if (backendSaved) break;
          try {
            final formData = FormData.fromMap({
              'file': MultipartFile.fromBytes(
                audioBytes,
                filename: cleanTitle,
              ),
            });

            final uploadRes = await dio.post(
              '$baseUrl/uploads/song',
              data: formData,
              onSendProgress: (sent, total) {
                if (total > 0) {
                  setState(() {
                    item.progress = 0.40 + (sent / total) * 0.50;
                  });
                }
              },
              options: Options(
                sendTimeout: const Duration(seconds: 90),
                receiveTimeout: const Duration(seconds: 90),
              ),
            );

            if (uploadRes.statusCode == 200 || uploadRes.statusCode == 201) {
              final songData = uploadRes.data is String ? jsonDecode(uploadRes.data) : uploadRes.data;
              if (songData != null && songData['id'] != null) {
                backendSongId = songData['id']?.toString();
                finalAudioUrl = songData['audioUrl']?.toString();
                finalArtworkUrl = songData['artworkUrl']?.toString() ?? songData['artwork']?.toString();
                backendSaved = true;

                final validatedSong = Song(
                  id: backendSongId ?? 'upload_${DateTime.now().millisecondsSinceEpoch}',
                  title: (songData['title'] ?? cleanTitle).toString(),
                  artist: (songData['artistName'] ?? songData['artist']?['name'] ?? 'Tamil Artist').toString(),
                  album: (songData['albumName'] ?? songData['album']?['title'] ?? 'Single').toString(),
                  movieName: songData['movieName']?.toString(),
                  artworkUrl: finalArtworkUrl ?? 'https://is1-ssl.mzstatic.com/image/thumb/Music128/v4/b3/e2/37/b3e237ba-7652-067a-a594-395015b2043c/cover.jpg/1400x1400bb.jpg',
                  audioUrl: finalAudioUrl ?? realAudioPath ?? '',
                  duration: (songData['duration'] as num?)?.toInt() ?? 180,
                  genre: (songData['genre'] ?? 'Tamil').toString(),
                  language: 'Tamil',
                  isDownloaded: false,
                );

                MockMusicCatalog.syncSong(validatedSong);
                _recentUploads.insert(0, validatedSong);
                ref.read(homeFeedProvider.notifier).refreshFeed();

                setState(() {
                  item.status = 'completed';
                  item.progress = 1.0;
                  item.statusMessage = 'Uploaded to Drive & DB ✅';
                  item.song = validatedSong;
                });
                break;
              }
            }
          } catch (err) {
            debugPrint('Upload error on $baseUrl: $err');
          }
        }

        if (!backendSaved) {
          throw Exception('Could not connect to Cloud Backend. Please check network.');
        }
      } catch (err) {
        setState(() {
          item.status = 'error';
          item.progress = 0.0;
          item.errorMessage = err.toString();
          item.statusMessage = 'Upload error: ${err.toString().replaceAll(RegExp(r'DioException.*?:'), '').trim()}';
        });
      }
    }

    // Run parallel batches with concurrency = 3
    const concurrency = 3;
    for (int i = 0; i < pendingItems.length; i += concurrency) {
      final batch = pendingItems.skip(i).take(concurrency);
      await Future.wait(batch.map((item) => processSingle(item)));
    }

    setState(() {
      _isProcessingQueue = false;
    });
  }

  void _clearCompletedQueue() {
    setState(() {
      _uploadQueue.removeWhere((q) => q.status == 'completed');
    });
  }

  @override
  Widget build(BuildContext context) {
    final completedCount = _uploadQueue.where((q) => q.status == 'completed').length;
    final totalCount = _uploadQueue.length;
    final double overallProgress = totalCount > 0 ? (completedCount / totalCount) : 0.0;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // FIXED Top Header Bar (Identical aligned position as HomeScreen)
            Container(
              color: AppTheme.background,
              padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 8.0, bottom: 4.0),
              child: Row(
                children: [
                  const UserAvatarButton(size: 36),
                  const SizedBox(width: 10),
                  const Text(
                    'Upload Songs',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const Spacer(),
                  if (_uploadQueue.isNotEmpty && !_isProcessingQueue)
                    TextButton.icon(
                      onPressed: _clearCompletedQueue,
                      icon: const Icon(Icons.clear_all_rounded, color: AppTheme.textSecondary, size: 18),
                      label: const Text('Clear', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.settings_outlined, color: Colors.white, size: 20),
                    padding: const EdgeInsets.all(2),
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (ctx) => const SettingsScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Apple Music artwork will be extracted automatically and uploaded sequentially to Google Drive & PostgreSQL DB.',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12.5),
                    ),
                    const SizedBox(height: 18),

                    // Multi-Song Selection Hero Button with '+' Plus Icon
                    GestureDetector(
                      onTap: _pickAndProcessSongs,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF181818),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppTheme.primaryGreen.withValues(alpha: 0.35),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryGreen.withValues(alpha: 0.12),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 68,
                              height: 68,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppTheme.primaryGreen.withValues(alpha: 0.15),
                              ),
                              child: const Icon(
                                Icons.add_rounded,
                                color: AppTheme.primaryGreen,
                                size: 44,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Select Audio Files to Upload',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Supports Multiple Files • Sequential Uploads • .mp3, .m4a, .flac',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Sequential Upload Queue Card
                    if (_uploadQueue.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF202020),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    if (_isProcessingQueue)
                                      const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppTheme.primaryGreen,
                                        ),
                                      )
                                    else
                                      const Icon(Icons.check_circle_rounded, color: AppTheme.primaryGreen, size: 18),
                                    const SizedBox(width: 8),
                                    Text(
                                      _isProcessingQueue
                                          ? 'Uploading Queue ($completedCount / $totalCount)'
                                          : 'Uploads Finished ($completedCount / $totalCount)',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  '${(overallProgress * 100).toInt()}%',
                                  style: const TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: overallProgress,
                                backgroundColor: Colors.white10,
                                valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryGreen),
                                minHeight: 4,
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Queue Items List
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _uploadQueue.length,
                              separatorBuilder: (ctx, i) => const Divider(color: Colors.white10, height: 16),
                              itemBuilder: (ctx, i) {
                                final item = _uploadQueue[i];
                                return Row(
                                  children: [
                                    // Status Icon / Artwork
                                    if (item.song?.artworkUrl != null)
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: CachedNetworkImage(
                                          imageUrl: item.song!.artworkUrl,
                                          width: 36,
                                          height: 36,
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    else
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.05),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Icon(
                                          item.status == 'completed'
                                              ? Icons.check_circle_rounded
                                              : item.status == 'processing'
                                                  ? Icons.cloud_upload_rounded
                                                  : item.status == 'error'
                                                      ? Icons.error_outline_rounded
                                                      : Icons.schedule_rounded,
                                          color: item.status == 'completed'
                                              ? AppTheme.primaryGreen
                                              : item.status == 'processing'
                                                  ? Colors.amber
                                                  : item.status == 'error'
                                                      ? Colors.redAccent
                                                      : Colors.white38,
                                          size: 20,
                                        ),
                                      ),
                                    const SizedBox(width: 12),

                                    // Title & Status
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.song?.title ?? item.file.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            item.statusMessage,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: item.status == 'completed'
                                                  ? AppTheme.primaryGreen
                                                  : item.status == 'error'
                                                      ? Colors.redAccent
                                                      : AppTheme.textSecondary,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Action
                                    if (item.song != null)
                                      IconButton(
                                        icon: const Icon(Icons.play_circle_fill_rounded, color: AppTheme.primaryGreen, size: 28),
                                        onPressed: () {
                                          ref.read(playerStateProvider.notifier).playSong(item.song!);
                                        },
                                      )
                                    else if (item.status == 'processing')
                                      const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.amber,
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Recent Uploads Section
                    if (_recentUploads.isNotEmpty) ...[
                      const Text(
                        'Recent Uploads',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _recentUploads.length,
                        itemBuilder: (ctx, i) {
                          final s = _recentUploads[i];
                          return SongTile(
                            song: s,
                            queueContext: _recentUploads,
                            queueIndex: i,
                          );
                        },
                      ),
                    ],
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
}
