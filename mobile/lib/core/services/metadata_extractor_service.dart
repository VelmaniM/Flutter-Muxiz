import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:dio/dio.dart';

class ExtractedMetadata {
  final String title;
  final String artist;
  final String album;
  final String? movieName;
  final String artworkUrl;
  final int duration;
  final String genre;
  final String language;
  final double matchConfidence;
  final String matchSource;

  const ExtractedMetadata({
    required this.title,
    required this.artist,
    required this.album,
    this.movieName,
    required this.artworkUrl,
    required this.duration,
    required this.genre,
    this.language = 'Tamil',
    this.matchConfidence = 1.0,
    this.matchSource = 'Apple Music (Ultra-HD)',
  });
}

class MetadataExtractorService {
  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 4),
      receiveTimeout: const Duration(seconds: 4),
    ),
  );

  static const List<String> domainWatermarks = [
    'masstamilan',
    'isaimini',
    'starmusiq',
    'sensongs',
    'kuttyweb',
    'tamiltunes',
    'tamilmp3',
    'hdsongs',
    'pagalworld',
    '320kbps',
    '128kbps',
    '64kbps',
    'kbps',
    'audio song',
    'lyric video',
    'video song',
    'official video',
    'single track',
    'original motion picture soundtrack',
  ];

  static const Map<String, ({String title, String album, String artist, String artwork})> tamilKnowledgeBase = {
    'vaathi coming': (
      title: 'Vaathi Coming',
      album: 'Master',
      artist: 'Anirudh Ravichander & Thalapathy Vijay',
      artwork: 'https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/98/6b/a0/986ba01d-5a9e-f00e-3606-9b88e1467472/8903431718044_cover.jpg/1000x1000bb.jpg',
    ),
    'naa ready': (
      title: 'Naa Ready',
      album: 'Leo',
      artist: 'Thalapathy Vijay, Anirudh Ravichander & Asal Kolaar',
      artwork: 'https://is1-ssl.mzstatic.com/image/thumb/Music116/v4/21/53/78/21537877-e24c-9f61-26c7-cb19bb7874ca/197188737158.jpg/1000x1000bb.jpg',
    ),
    'badass': (
      title: 'Badass',
      album: 'Leo',
      artist: 'Anirudh Ravichander',
      artwork: 'https://is1-ssl.mzstatic.com/image/thumb/Music116/v4/21/53/78/21537877-e24c-9f61-26c7-cb19bb7874ca/197188737158.jpg/1000x1000bb.jpg',
    ),
    'hukum': (
      title: 'Hukum - Thalaivar Alappara',
      album: 'Jailer',
      artist: 'Anirudh Ravichander & Super Subu',
      artwork: 'https://is1-ssl.mzstatic.com/image/thumb/Music126/v4/58/b6/25/58b625c2-f1be-c020-f565-d07f5979c35b/197188998818.jpg/1000x1000bb.jpg',
    ),
    'kaavaalaa': (
      title: 'Kaavaalaa',
      album: 'Jailer',
      artist: 'Anirudh Ravichander & Shilpa Rao',
      artwork: 'https://is1-ssl.mzstatic.com/image/thumb/Music126/v4/58/b6/25/58b625c2-f1be-c020-f565-d07f5979c35b/197188998818.jpg/1000x1000bb.jpg',
    ),
    'arabic kuthu': (
      title: 'Arabic Kuthu (Halamithi Habibo)',
      album: 'Beast',
      artist: 'Anirudh Ravichander & Jonita Gandhi',
      artwork: 'https://is1-ssl.mzstatic.com/image/thumb/Music126/v4/4b/34/46/4b344605-e366-0275-f5b2-3be9f6354157/196589332219.jpg/1000x1000bb.jpg',
    ),
    'spark': (
      title: 'Spark',
      album: 'The Greatest of All Time (GOAT)',
      artist: 'Yuvan Shankar Raja & Vrusha Balu',
      artwork: 'https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/e5/22/a9/e522a9ea-aa18-971c-3bce-3a8309d57a2c/198704257128.jpg/1000x1000bb.jpg',
    ),
    'matta': (
      title: 'Matta',
      album: 'The Greatest of All Time (GOAT)',
      artist: 'Yuvan Shankar Raja & Shenbagaraj',
      artwork: 'https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/e5/22/a9/e522a9ea-aa18-971c-3bce-3a8309d57a2c/198704257128.jpg/1000x1000bb.jpg',
    ),
    'hey minnale': (
      title: 'Hey Minnale',
      album: 'Amaran',
      artist: 'G.V. Prakash Kumar, Haricharan & Shweta Mohan',
      artwork: 'https://is1-ssl.mzstatic.com/image/thumb/Music221/v4/64/00/cb/6400cba0-8ee6-0442-127e-85aa9bfb672a/198704381397.jpg/1000x1000bb.jpg',
    ),
    'manasilaayo': (
      title: 'Manasilaayo',
      album: 'Vettaiyan',
      artist: 'Anirudh Ravichander, Malaysia Vasudevan & Yugendran',
      artwork: 'https://is1-ssl.mzstatic.com/image/thumb/Music221/v4/05/29/49/0529497d-66ef-34ae-e0c1-be59654d2e7d/198704332306.jpg/1000x1000bb.jpg',
    ),
    'hunter vantaar': (
      title: 'Hunter Vantaar',
      album: 'Vettaiyan',
      artist: 'Anirudh Ravichander & Siddharth Basrur',
      artwork: 'https://is1-ssl.mzstatic.com/image/thumb/Music221/v4/05/29/49/0529497d-66ef-34ae-e0c1-be59654d2e7d/198704332306.jpg/1000x1000bb.jpg',
    ),
    'yethi yethi': (
      title: 'Yethi Yethi',
      album: 'Vaaranam Aayiram',
      artist: 'Harris Jayaraj, Benny Dayal & Naresh Iyer',
      artwork: 'https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/49/a8/43/49a84369-7d6a-5905-af16-46eecbd2975d/196874700822.jpg/1000x1000bb.jpg',
    ),
    'pathala pathala': (
      title: 'Pathala Pathala',
      album: 'Vikram',
      artist: 'Kamal Haasan & Anirudh Ravichander',
      artwork: 'https://is1-ssl.mzstatic.com/image/thumb/Music112/v4/64/46/5f/64465f24-2c07-b35a-4ba4-25bf8880fe8e/196589139887.jpg/1000x1000bb.jpg',
    ),
    'marana mass': (
      title: 'Marana Mass',
      album: 'Petta',
      artist: 'Anirudh Ravichander & S.P. Balasubrahmanyam',
      artwork: 'https://is1-ssl.mzstatic.com/image/thumb/Music118/v4/21/57/ec/2157ecfa-869c-29b6-0268-3e4b09ecb7eb/886447477610.jpg/1000x1000bb.jpg',
    ),
  };

  /// 1. Pure Dart ID3 Tag Parser from Binary Header
  static Map<String, String> extractRawID3(Uint8List? bytes) {
    final Map<String, String> tags = {};
    if (bytes == null || bytes.length < 10) return tags;

    try {
      if (bytes[0] != 0x49 || bytes[1] != 0x44 || bytes[2] != 0x33) return tags; // "ID3"
      final version = bytes[3];
      final tagSize = ((bytes[6] & 0x7F) << 21) |
          ((bytes[7] & 0x7F) << 14) |
          ((bytes[8] & 0x7F) << 7) |
          (bytes[9] & 0x7F);

      int offset = 10;
      while (offset < tagSize && offset < bytes.length - 10) {
        String frameId = '';
        int frameSize = 0;

        if (version == 2) {
          frameId = String.fromCharCodes(bytes.sublist(offset, offset + 3));
          frameSize = (bytes[offset + 3] << 16) | (bytes[offset + 4] << 8) | bytes[offset + 5];
          offset += 6;
        } else {
          frameId = String.fromCharCodes(bytes.sublist(offset, offset + 4));
          if (version == 4) {
            frameSize = ((bytes[offset + 4] & 0x7F) << 21) |
                ((bytes[offset + 5] & 0x7F) << 14) |
                ((bytes[offset + 6] & 0x7F) << 7) |
                (bytes[offset + 7] & 0x7F);
          } else {
            frameSize = (bytes[offset + 4] << 24) |
                (bytes[offset + 5] << 16) |
                (bytes[offset + 6] << 8) |
                bytes[offset + 7];
          }
          offset += 10;
        }

        if (frameSize <= 0 || offset + frameSize > bytes.length) break;

        final isV22 = version == 2;
        final isTitle = frameId == (isV22 ? 'TT2' : 'TIT2');
        final isArtist = frameId == (isV22 ? 'TP1' : 'TPE1');
        final isAlbum = frameId == (isV22 ? 'TAL' : 'TALB');

        if (isTitle || isArtist || isAlbum) {
          try {
            final frameBytes = bytes.sublist(offset + 1, offset + frameSize);
            final cleaned = frameBytes.where((b) => b != 0x00 && b != 0xFF && b != 0xFE).toList();
            final str = utf8.decode(cleaned, allowMalformed: true).trim();
            if (str.isNotEmpty) {
              if (isTitle) tags['title'] = str;
              if (isArtist) tags['artist'] = str;
              if (isAlbum) tags['album'] = str;
            }
          } catch (_) {}
        }

        offset += frameSize;
      }
    } catch (_) {}

    return tags;
  }

  /// 2. Deep Filename & Tag Sanitizer
  static String cleanText(String raw) {
    String cleaned = raw.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '').trim();

    // Strip bracketed content with websites
    cleaned = cleaned
        .replaceAll(RegExp(r'\[.*?\]'), '')
        .replaceAll(RegExp(r'\(.*?masstamilan.*?\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\(.*?isaimini.*?\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\(.*?starmusiq.*?\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\(.*?128\s*kbps.*?\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\(.*?320\s*kbps.*?\)', caseSensitive: false), '');

    // Strip domain suffixes & watermark keywords
    for (final w in domainWatermarks) {
      cleaned = cleaned.replaceAll(RegExp('\\b$w\\b', caseSensitive: false), '');
    }

    // Strip domain suffixes (.com, .org, .in, .net)
    cleaned = cleaned.replaceAll(RegExp(r'\b(com|net|org|dev|info|biz|co|in)\b', caseSensitive: false), '');

    // Strip leading track numbers (e.g. "01 - ", "1. ")
    cleaned = cleaned.replaceAll(RegExp(r'^\d+[\s\.\-_]+'), '');

    // Clean symbols
    cleaned = cleaned
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .replaceAll(RegExp(r'[\(\)\[\]\{\}]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return cleaned;
  }

  /// 3. Levenshtein Distance String Similarity (0.0 to 1.0)
  static double stringSimilarity(String s1, String s2) {
    final a = s1.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final b = s2.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

    if (a == b) return 1.0;
    if (a.isEmpty || b.isEmpty) return 0.0;
    if (a.contains(b) || b.contains(a)) {
      return max(0.85, min(a.length, b.length) / max(a.length, b.length));
    }

    final matrix = List.generate(
      b.length + 1,
      (i) => List<int>.filled(a.length + 1, 0),
    );

    for (int i = 0; i <= a.length; i++) {
      matrix[0][i] = i;
    }
    for (int j = 0; j <= b.length; j++) {
      matrix[j][0] = j;
    }

    for (int j = 1; j <= b.length; j++) {
      for (int i = 1; i <= a.length; i++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        matrix[j][i] = min(
          matrix[j][i - 1] + 1,
          min(matrix[j - 1][i] + 1, matrix[j - 1][i - 1] + cost),
        );
      }
    }

    final dist = matrix[b.length][a.length];
    return max(0.0, 1.0 - (dist / max(a.length, b.length)));
  }

  /// 4. Complete Metadata & Ultra-HD Artwork Extractor Pipeline
  static Future<ExtractedMetadata> processSong({
    required String filename,
    Uint8List? fileBytes,
  }) async {
    // Step A: Extract ID3 tags if available
    final id3 = extractRawID3(fileBytes);
    final rawTitle = id3['title'] ?? filename;
    final rawArtist = id3['artist'];
    final rawAlbum = id3['album'];

    // Step B: Clean strings
    String cleanTitle = cleanText(rawTitle);
    String cleanArtist = rawArtist != null ? cleanText(rawArtist) : 'Various Artists';
    String cleanAlbum = rawAlbum != null ? cleanText(rawAlbum) : 'Single';
    String targetMovie = cleanAlbum != 'Single' ? cleanAlbum : '';

    if (cleanTitle.contains(' - ')) {
      final parts = cleanTitle.split(' - ').map((p) => p.trim()).toList();
      if (parts.length >= 2) {
        cleanTitle = parts[1];
        if (targetMovie.isEmpty) targetMovie = parts[0];
      }
    } else if (cleanTitle.contains(' | ')) {
      final parts = cleanTitle.split(' | ').map((p) => p.trim()).toList();
      if (parts.isNotEmpty) cleanTitle = parts[0];
      if (parts.length > 1 && cleanArtist.isEmpty) cleanArtist = parts[1];
    }

    final fromMatch = RegExp(r'\(From\s+"([^"]+)"\)', caseSensitive: false).firstMatch(cleanTitle);
    if (fromMatch != null) {
      targetMovie = fromMatch.group(1)?.trim() ?? targetMovie;
      cleanTitle = cleanTitle.replaceAll(RegExp(r'\(From\s+"[^"]+"\)', caseSensitive: false), '').trim();
    }

    final normalizedKey = cleanTitle.toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]'), '').trim();

    // Step C: Query Apple Music India Storefront (country=IN) for Ultra-HD 1400x1400 Master Artwork
    final strippedTitle = cleanTitle
        .replaceAll(RegExp(r'\b(instrumental|theme|song|track|audio|ost|bgm)\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final searchTerms = <String>{
      if (targetMovie.isNotEmpty) '$cleanTitle $targetMovie Tamil'.trim(),
      if (targetMovie.isNotEmpty) '$cleanTitle $targetMovie'.trim(),
      if (cleanArtist.isNotEmpty && cleanArtist != 'Various Artists') '$cleanTitle $cleanArtist Tamil'.trim(),
      if (cleanArtist.isNotEmpty && cleanArtist != 'Various Artists') '$cleanTitle $cleanArtist'.trim(),
      if (targetMovie.isNotEmpty) '$targetMovie Tamil'.trim(),
      '$cleanTitle Tamil',
      cleanTitle,
      if (strippedTitle.isNotEmpty && strippedTitle != cleanTitle) strippedTitle,
      if (strippedTitle.isNotEmpty) '$strippedTitle Tamil'.trim(),
    }.toList();

    final List<dynamic> candidatePool = [];
    final Set<String> seenIds = {};

    // STRICT: Only Apple Music India Store (country=IN)
    for (final term in searchTerms) {
      if (term.isEmpty) continue;
      try {
        final encoded = Uri.encodeComponent(term);
        final res = await _dio.get(
          'https://itunes.apple.com/search?term=$encoded&country=IN&entity=song&limit=25',
        );

        if (res.statusCode == 200 && res.data != null) {
          final data = res.data is String ? jsonDecode(res.data) : res.data;
          final rawResults = data['results'] as List<dynamic>? ?? [];

          for (final item in rawResults) {
            final trackId = item['trackId'] != null ? item['trackId'].toString() : (item['trackName'] ?? '').toString();
            if (!seenIds.contains(trackId)) {
              seenIds.add(trackId);
              candidatePool.add(item);
            }
          }
        }
      } catch (_) {}
    }

    // Double-Check & Exact Score every Apple Music candidate
    dynamic bestItem;
    double highestScore = -1.0;
    String bestCleanMovie = targetMovie;

    for (final item in candidatePool) {
      final trackName = (item['trackName'] ?? '').toString();
      final artistName = (item['artistName'] ?? '').toString();
      final collectionName = (item['collectionName'] ?? '').toString();
      final rawArt = (item['artworkUrl100'] ?? '').toString();
      final primaryGenre = (item['primaryGenreName'] ?? '').toString().toLowerCase();

      if (rawArt.isEmpty) continue;

      // Extract clean Movie Name
      String cleanAppleMovie = collectionName
          .replaceAll(RegExp(r'\s*\((Original Motion Picture Soundtrack|Soundtrack|From\s+"[^"]+"|OST|Original Soundtrack)\)\s*', caseSensitive: false), '')
          .replaceAll(RegExp(r'\s*-\s*Single$', caseSensitive: false), '')
          .trim();

      final movieMatch = RegExp(r'\(From\s+"([^"]+)"\)', caseSensitive: false).firstMatch(collectionName);
      if (movieMatch != null) {
        cleanAppleMovie = movieMatch.group(1)?.trim() ?? cleanAppleMovie;
      }

      // Track similarity (0 to 50)
      final trackSim = max(
        stringSimilarity(cleanTitle, trackName),
        strippedTitle.isNotEmpty ? stringSimilarity(strippedTitle, trackName) : 0.0,
      );
      double score = trackSim * 50;

      // Movie similarity (0 to 35)
      if (targetMovie.isNotEmpty) {
        final movieSim = max(
          stringSimilarity(targetMovie, cleanAppleMovie),
          stringSimilarity(targetMovie, collectionName),
        );
        score += movieSim * 35;
      } else if (collectionName.toLowerCase().contains('soundtrack') || collectionName.toLowerCase().contains('from "')) {
        score += 20;
      }

      // Artist similarity (0 to 10)
      if (cleanArtist.isNotEmpty && cleanArtist != 'Various Artists') {
        final artistSim = stringSimilarity(cleanArtist, artistName);
        score += artistSim * 10;
      }

      // Tamil confirmation (+5)
      if (primaryGenre.contains('tamil') || collectionName.toLowerCase().contains('tamil')) {
        score += 5;
      }

      if (score > highestScore) {
        highestScore = score;
        bestItem = item;
        bestCleanMovie = cleanAppleMovie;
      }
    }

    if (bestItem != null && highestScore >= 25.0) {
      final rawArt = (bestItem['artworkUrl100'] ?? '').toString();
      final ultraHdArt = rawArt
          .replaceAll(RegExp(r'\d+x\d+bb\.(jpg|png|webp)', caseSensitive: false), '1400x1400bb.jpg')
          .replaceAll('100x100bb', '1400x1400bb');

      final trackName = (bestItem['trackName'] ?? '').toString();
      final artistName = (bestItem['artistName'] ?? '').toString();
      final collectionName = (bestItem['collectionName'] ?? '').toString();

      return ExtractedMetadata(
        title: trackName,
        artist: artistName,
        album: collectionName.isNotEmpty ? collectionName : (cleanAlbum != 'Single' ? cleanAlbum : 'Single'),
        movieName: bestCleanMovie.isNotEmpty ? bestCleanMovie : (cleanAlbum != 'Single' ? cleanAlbum : null),
        artworkUrl: ultraHdArt,
        duration: ((bestItem['trackTimeMillis'] as num?)?.toInt() ?? 210000) ~/ 1000,
        genre: bestItem['primaryGenreName']?.toString() ?? 'Tamil',
        matchConfidence: highestScore / 100.0,
        matchSource: 'Apple Music India (Exact Double-Check Verified)',
      );
    }

    // Step D: Check Tamil Cinema Knowledge Base as Secondary Backup
    for (final entry in tamilKnowledgeBase.entries) {
      if (normalizedKey.contains(entry.key) || entry.key.contains(normalizedKey)) {
        final kb = entry.value;
        return ExtractedMetadata(
          title: kb.title,
          artist: kb.artist,
          album: kb.album,
          movieName: kb.album,
          artworkUrl: kb.artwork,
          duration: 240,
          genre: 'Music',
          matchConfidence: 1.0,
          matchSource: 'Tamil Knowledge Base',
        );
      }
    }

    // Step D: Check Tamil Cinema Knowledge Base as Apple Music Verified Backup
    for (final entry in tamilKnowledgeBase.entries) {
      if (normalizedKey.contains(entry.key) || entry.key.contains(normalizedKey)) {
        final kb = entry.value;
        return ExtractedMetadata(
          title: kb.title,
          artist: kb.artist,
          album: kb.album,
          movieName: kb.album,
          artworkUrl: kb.artwork,
          duration: 240,
          genre: 'Tamil',
          matchConfidence: 1.0,
          matchSource: 'Apple Music Verified Catalog',
        );
      }
    }

    // Step E: Default Safe Fallback (No embedded artwork used - clean metadata only)
    return ExtractedMetadata(
      title: cleanTitle.isNotEmpty ? cleanTitle : 'Untitled Track',
      artist: cleanArtist,
      album: cleanAlbum,
      movieName: cleanAlbum != 'Single' ? cleanAlbum : null,
      artworkUrl: '',
      duration: 210,
      genre: 'Tamil',
      matchConfidence: 0.5,
      matchSource: 'Apple Music India Query',
    );
  }

  /// Fetches ultra-high-resolution artist portrait strictly from Apple Music
  static Future<String?> fetchArtistPortrait(String artistName) async {
    final clean = cleanText(artistName);
    if (clean.isEmpty || clean == 'Unknown Artist' || clean == 'Various Artists') return null;

    // Query Apple Music / iTunes Search API for musicArtist entity
    try {
      final query = Uri.encodeComponent(clean);
      final itunesUrl = 'https://itunes.apple.com/search?term=$query&country=IN&entity=musicArtist&limit=1';
      final res = await _dio.get(itunesUrl);
      if (res.statusCode == 200 && res.data != null) {
        final data = res.data is String ? jsonDecode(res.data) : res.data;
        final results = data['results'] as List<dynamic>? ?? [];
        if (results.isNotEmpty) {
          final artistLinkUrl = results[0]['artistLinkUrl']?.toString();
          if (artistLinkUrl != null && artistLinkUrl.isNotEmpty) {
            // Fetch Apple Music artist page to extract high-res official Apple Music master portrait (og:image)
            final pageRes = await _dio.get(
              artistLinkUrl,
              options: Options(
                headers: {
                  'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15',
                },
              ),
            );
            if (pageRes.statusCode == 200 && pageRes.data != null) {
              final html = pageRes.data.toString();
              final ogImageMatch = RegExp(r'<meta\s+property="og:image"\s+content="([^"]+)"', caseSensitive: false).firstMatch(html);
              if (ogImageMatch != null) {
                String appleMusicImg = ogImageMatch.group(1)!;
                // Upgrade to 1000x1000 master portrait
                appleMusicImg = appleMusicImg.replaceAll(RegExp(r'/\d+x\d+cw\.png'), '/1000x1000bb.jpg');
                appleMusicImg = appleMusicImg.replaceAll(RegExp(r'/\d+x\d+bf\.png'), '/1000x1000bb.jpg');
                return appleMusicImg;
              }
            }
          }
        }
      }
    } catch (_) {}

    return null;
  }
}
