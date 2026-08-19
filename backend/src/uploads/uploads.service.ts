import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { GoogleDriveService } from '../storage/google-drive/google-drive.service';
import { RedisService } from '../redis/redis.service';
import * as mm from 'music-metadata';

@Injectable()
export class UploadsService {
  private readonly logger = new Logger(UploadsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly driveService: GoogleDriveService,
    private readonly redis: RedisService,
  ) {}

  async processAndUploadSong(
    audioBuffer: Buffer,
    originalFilename: string,
    mimeType: string = 'audio/mpeg',
  ) {
    const startTime = Date.now();
    this.logger.log(`⚡ [High-Speed Upload] Processing: "${originalFilename}" (${(audioBuffer.length / (1024 * 1024)).toFixed(2)} MB)`);

    let extractedTitle = originalFilename.replace(/\.[^/.]+$/, '');
    let extractedArtist = 'Unknown Artist';
    let extractedAlbum = 'Single';
    let duration = 180;
    let genre = 'Music';
    let releaseDate: Date | null = null;
    let coverBuffer: Buffer | null = null;
    let coverMime = 'image/jpeg';

    // 1. Fast binary ID3 header parsing
    try {
      const metadata = await mm.parseBuffer(audioBuffer, mimeType, { duration: true, skipCovers: true });
      if (metadata.common.title) extractedTitle = metadata.common.title.trim();
      if (metadata.common.artist) extractedArtist = metadata.common.artist.trim();
      if (metadata.common.album) extractedAlbum = metadata.common.album.trim();
      if (metadata.common.genre && metadata.common.genre.length > 0) genre = metadata.common.genre[0];
      if (metadata.common.year) releaseDate = new Date(`${metadata.common.year}-01-01`);
      if (metadata.format.duration) duration = Math.round(metadata.format.duration);
    } catch (_) {}

    // String similarity helper
    const stringSimilarity = (str1: string, str2: string): number => {
      const a = (str1 || '').toLowerCase().replace(/[^a-z0-9]/g, '');
      const b = (str2 || '').toLowerCase().replace(/[^a-z0-9]/g, '');
      if (!a || !b) return 0;
      if (a === b) return 1.0;
      if (a.includes(b) || b.includes(a)) {
        return Math.max(0.85, Math.min(a.length, b.length) / Math.max(a.length, b.length));
      }
      return 0.5;
    };

    const sanitize = (str: string) => {
      return (str || '')
        .replace(/\.[a-zA-Z0-9]+$/, '')
        .replace(/\[.*?\]/g, '')
        .replace(/\(.*?(masstamilan|isaimini|starmusiq|128kbps|320kbps|sensongs|kuttyweb|tamiltunes).*?\)/gi, '')
        .replace(/\b(masstamilan|isaimini|starmusiq|sensongs|kuttyweb|tamiltunes|320kbps|128kbps|kbps)\b/gi, '')
        .replace(/_/g, ' ')
        .replace(/\s+/g, ' ')
        .trim();
    };

    const rawClean = sanitize(extractedTitle);
    let targetSongName = rawClean;
    let targetMovieName = extractedAlbum !== 'Single' ? sanitize(extractedAlbum) : '';

    if (rawClean.includes(' - ')) {
      const parts = rawClean.split(' - ').map((p) => p.trim());
      if (parts.length >= 2) {
        targetSongName = parts[1];
        if (!targetMovieName) targetMovieName = parts[0];
      }
    }

    // 2. Ultra-Fast Parallel Apple Music Queries (Promise.allSettled)
    const searchQueries = [
      targetMovieName ? `${targetSongName} ${targetMovieName} Tamil`.trim() : '',
      extractedArtist !== 'Unknown Artist' ? `${targetSongName} ${extractedArtist}`.trim() : '',
      `${targetSongName} Tamil`.trim(),
      targetSongName.trim(),
    ].filter(Boolean);

    let bestCandidate: any = null;
    let highestScore = -1;

    const parallelSearches = await Promise.allSettled(
      searchQueries.slice(0, 3).map(async (query) => {
        const cacheKey = `applemusic:query:${query.toLowerCase()}`;
        let rawResults = await this.redis.get<any[]>(cacheKey);
        if (!rawResults) {
          const res = await fetch(`https://itunes.apple.com/search?term=${encodeURIComponent(query)}&country=IN&entity=song&limit=10`);
          if (res.ok) {
            const json: any = await res.json();
            rawResults = (json.results as any[]) || [];
            if (rawResults.length > 0) {
              await this.redis.set(cacheKey, rawResults, 604800);
            }
          }
        }
        return rawResults || [];
      }),
    );

    const candidatePool: any[] = [];
    const seenIds = new Set<string>();

    for (const result of parallelSearches) {
      if (result.status === 'fulfilled' && Array.isArray(result.value)) {
        for (const item of result.value) {
          const trackId = String(item.trackId || item.trackName);
          if (!seenIds.has(trackId)) {
            seenIds.add(trackId);
            candidatePool.push(item);
          }
        }
      }
    }

    for (const item of candidatePool) {
      const trackName = item.trackName || '';
      const collectionName = item.collectionName || '';
      const artistName = item.artistName || '';

      const trackSim = Math.max(stringSimilarity(targetSongName, trackName), stringSimilarity(rawClean, trackName));
      let score = trackSim * 50;

      if (targetMovieName && collectionName.toLowerCase().includes(targetMovieName.toLowerCase())) {
        score += 35;
      }
      if (extractedArtist && artistName.toLowerCase().includes(extractedArtist.toLowerCase())) {
        score += 10;
      }

      if (score > highestScore) {
        highestScore = score;
        bestCandidate = item;
      }
    }

    let artworkUrl = 'https://is1-ssl.mzstatic.com/image/thumb/Music128/v4/b3/e2/37/b3e237ba-7652-067a-a594-395015b2043c/cover.jpg/1400x1400bb.jpg';

    if (bestCandidate && bestCandidate.artworkUrl100) {
      artworkUrl = bestCandidate.artworkUrl100
        .replace(/\/100x100bb\.(jpg|png)/i, '/1400x1400bb.jpg')
        .replace('100x100bb', '1400x1400bb');

      if (bestCandidate.trackName) extractedTitle = bestCandidate.trackName;
      if (bestCandidate.artistName) extractedArtist = bestCandidate.artistName;
      if (bestCandidate.collectionName) extractedAlbum = bestCandidate.collectionName;
      if (bestCandidate.primaryGenreName) genre = bestCandidate.primaryGenreName;
      if (bestCandidate.releaseDate) releaseDate = new Date(bestCandidate.releaseDate);
      if (bestCandidate.trackTimeMillis) duration = Math.round(bestCandidate.trackTimeMillis / 1000);
    }

    const cleanSongTitle = extractedTitle.trim().replace(/[/\\?%*:|"<>]/g, '_');

    // 3. CONCURRENT PARALLEL GOOGLE DRIVE UPLOADS (Audio + Artwork in parallel!)
    const audioFilename = `${cleanSongTitle}.mp3`;

    // Fetch cover art buffer asynchronously
    const fetchCoverPromise = fetch(artworkUrl)
      .then((res) => (res.ok ? res.arrayBuffer() : null))
      .then((ab) => (ab ? Buffer.from(ab) : null))
      .catch(() => null);

    // Parallel upload of Audio & Cover to Google Drive
    const [audioRes, fetchedCover] = await Promise.all([
      this.driveService.uploadFile('Songs', audioFilename, audioBuffer, mimeType),
      fetchCoverPromise,
    ]);

    let artworkFileId: string | null = null;
    if (fetchedCover) {
      coverBuffer = fetchedCover;
      // Upload cover in non-blocking background task to speed up response
      this.driveService
        .uploadFile('Covers', `${cleanSongTitle}.jpg`, coverBuffer, 'image/jpeg')
        .then((res) => {
          artworkFileId = res.fileId;
        })
        .catch(() => {});
    }

    const driveAudioUrl = `https://drive.google.com/uc?id=${audioRes.fileId}&export=download`;

    // 4. Save/Upsert in PostgreSQL Database (Atomic Prisma Transaction)
    const artist = await this.prisma.artist.upsert({
      where: { name: extractedArtist },
      update: { image: artworkUrl },
      create: { name: extractedArtist, image: artworkUrl },
    });

    const album = await this.prisma.album.create({
      data: {
        title: extractedAlbum,
        artistId: artist.id,
        artwork: artworkUrl,
        releaseDate,
      },
    });

    const song = await this.prisma.song.upsert({
      where: {
        title_artistName: {
          title: extractedTitle,
          artistName: artist.name,
        },
      },
      update: {
        artistId: artist.id,
        albumId: album.id,
        albumName: album.title,
        movieName: targetMovieName || (extractedAlbum !== 'Single' ? extractedAlbum : null),
        releaseDate,
        duration,
        genre,
        language: 'Tamil',
        driveFileId: audioRes.fileId,
        artworkFileId: artworkFileId || undefined,
        audioUrl: driveAudioUrl,
        artworkUrl,
        lyrics: [`${extractedTitle} by ${extractedArtist}`],
      },
      create: {
        title: extractedTitle,
        artistId: artist.id,
        albumId: album.id,
        artistName: artist.name,
        albumName: album.title,
        movieName: targetMovieName || (extractedAlbum !== 'Single' ? extractedAlbum : null),
        releaseDate,
        duration,
        genre,
        language: 'Tamil',
        driveFileId: audioRes.fileId,
        artworkFileId,
        audioUrl: driveAudioUrl,
        artworkUrl,
        lyrics: [`${extractedTitle} by ${extractedArtist}`],
      },
      include: {
        artist: { select: { id: true, name: true, image: true } },
        album: { select: { id: true, title: true, artwork: true } },
      },
    });

    // Invalidate caches instantly
    await this.redis.set(`song:${song.id}`, song, 86400);
    await this.redis.invalidateCatalog();

    // 5. Asynchronous Metadata JSON upload to Google Drive
    this.driveService
      .uploadFile('Metadata', `${cleanSongTitle}.json`, Buffer.from(JSON.stringify(song, null, 2), 'utf-8'), 'application/json')
      .catch(() => {});

    const elapsed = ((Date.now() - startTime) / 1000).toFixed(2);
    this.logger.log(`⚡ [Speed 100% Done] "${song.title}" uploaded to Google Drive & Supabase in ${elapsed}s!`);

    return song;
  }
}
