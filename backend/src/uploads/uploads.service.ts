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
    this.logger.log(`Processing song upload: ${originalFilename}`);

    let extractedTitle = originalFilename.replace(/\.[^/.]+$/, '');
    let extractedArtist = 'Unknown Artist';
    let extractedAlbum = 'Single';
    let duration = 180;
    let genre = 'Music';
    let releaseDate: Date | null = null;
    let coverBuffer: Buffer | null = null;
    let coverMime = 'image/jpeg';

    try {
      const metadata = await mm.parseBuffer(audioBuffer, mimeType, { duration: true });
      
      if (metadata.common.title) extractedTitle = metadata.common.title.trim();
      if (metadata.common.artist) extractedArtist = metadata.common.artist.trim();
      if (metadata.common.album) extractedAlbum = metadata.common.album.trim();
      if (metadata.common.genre && metadata.common.genre.length > 0) {
        genre = metadata.common.genre[0];
      }
      if (metadata.common.year) {
        releaseDate = new Date(`${metadata.common.year}-01-01`);
      }
      if (metadata.format.duration) {
        duration = Math.round(metadata.format.duration);
      }
      // Note: 0% embedded artwork used. All artwork is fetched strictly from Apple Music.
    } catch (parseError) {
      this.logger.warn(`Could not parse ID3 metadata: ${(parseError as Error).message}. Using fallback filename parsing.`);
    }

    // String similarity helper for exact double checking
    const stringSimilarity = (str1: string, str2: string): number => {
      const a = (str1 || '').toLowerCase().replace(/[^a-z0-9]/g, '');
      const b = (str2 || '').toLowerCase().replace(/[^a-z0-9]/g, '');
      if (!a || !b) return 0;
      if (a === b) return 1.0;
      if (a.includes(b) || b.includes(a)) {
        return Math.max(0.85, Math.min(a.length, b.length) / Math.max(a.length, b.length));
      }
      // Levenshtein distance
      const matrix = Array.from({ length: a.length + 1 }, (_, i) => [i]);
      for (let j = 0; j <= b.length; j++) matrix[0][j] = j;
      for (let i = 1; i <= a.length; i++) {
        for (let j = 1; j <= b.length; j++) {
          const cost = a[i - 1] === b[j - 1] ? 0 : 1;
          matrix[i][j] = Math.min(
            matrix[i - 1][j] + 1,
            matrix[i][j - 1] + 1,
            matrix[i - 1][j - 1] + cost,
          );
        }
      }
      const dist = matrix[a.length][b.length];
      return Math.max(0, 1 - dist / Math.max(a.length, b.length));
    };

    // Clean text helper
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

    // Parse potential Movie & Song compounds from filename/tags
    let rawClean = sanitize(extractedTitle);
    let targetSongName = rawClean;
    let targetMovieName = extractedAlbum !== 'Single' ? sanitize(extractedAlbum) : '';

    if (rawClean.includes(' - ')) {
      const parts = rawClean.split(' - ').map((p) => p.trim());
      if (parts.length >= 2) {
        // e.g. "Leo - Naa Ready" or "Naa Ready - Leo"
        targetSongName = parts[1];
        if (!targetMovieName) targetMovieName = parts[0];
      }
    } else if (rawClean.includes(' | ')) {
      const parts = rawClean.split(' | ').map((p) => p.trim());
      if (parts.length >= 2) {
        targetSongName = parts[0];
        if (!targetMovieName) targetMovieName = parts[1];
      }
    }

    const fromMatch = rawClean.match(/\(From\s+"([^"]+)"\)/i);
    if (fromMatch && fromMatch[1]) {
      targetMovieName = sanitize(fromMatch[1]);
      targetSongName = rawClean.replace(/\(From\s+"[^"]+"\)/i, '').trim();
    }

    this.logger.log(`🎯 Target Search: Song="${targetSongName}", Movie="${targetMovieName}", Artist="${extractedArtist}"`);

    // 1. Fetch High-Resolution Candidates STRICTLY from Apple Music India Store (country=IN)
    let artworkUrl: string = '';
    let artworkFileId: string | null = null;
    let coverFound = false;

    // Search permutations to guarantee Apple Music India discovery
    const searchQueries = [
      targetMovieName ? `${targetSongName} ${targetMovieName} Tamil`.trim() : '',
      targetMovieName ? `${targetSongName} ${targetMovieName}`.trim() : '',
      extractedArtist !== 'Unknown Artist' ? `${targetSongName} ${extractedArtist} Tamil`.trim() : '',
      extractedArtist !== 'Unknown Artist' ? `${targetSongName} ${extractedArtist}`.trim() : '',
      targetMovieName ? `${targetMovieName} Tamil`.trim() : '',
      `${targetSongName} Tamil`.trim(),
      targetSongName.trim(),
    ].filter(Boolean) as string[];

    const candidatePool: any[] = [];
    const seenTrackIds = new Set<string>();

    for (const query of searchQueries) {
      try {
        const cacheKey = `applemusic:query:${query.toLowerCase()}`;
        let rawResults = await this.redis.get<any[]>(cacheKey);

        if (!rawResults) {
          const searchTerm = encodeURIComponent(query);
          const itunesApiUrl = `https://itunes.apple.com/search?term=${searchTerm}&country=IN&entity=song&limit=25`;
          const response = await fetch(itunesApiUrl);
          if (response.ok) {
            const json: any = await response.json();
            rawResults = (json.results as any[]) || [];
            if (rawResults.length > 0) {
              await this.redis.set(cacheKey, rawResults, 604800); // 7 days cache
            }
          }
        }

        if (rawResults && Array.isArray(rawResults)) {
          for (const item of rawResults) {
            const trackId = item.trackId ? String(item.trackId) : (item.trackName + item.collectionName);
            if (!seenTrackIds.has(trackId)) {
              seenTrackIds.add(trackId);
              candidatePool.push(item);
            }
          }
        }
      } catch (e) {
        this.logger.warn(`Apple Music query failed for "${query}": ${(e as Error).message}`);
      }
    }

    // Double-Check & Exact Score every Apple Music candidate
    let bestCandidate: any = null;
    let highestScore = -1;

    for (const item of candidatePool) {
      const trackName = item.trackName || '';
      const collectionName = item.collectionName || '';
      const artistName = item.artistName || '';
      const primaryGenre = (item.primaryGenreName || '').toLowerCase();

      // Extract clean Movie Name from Apple Music collectionName
      let cleanAppleMovie = collectionName
        .replace(/\s*\((Original Motion Picture Soundtrack|Soundtrack|From\s+"[^"]+"|OST|Original Soundtrack)\)\s*/gi, '')
        .replace(/\s*-\s*Single$/gi, '')
        .trim();

      const movieMatch = collectionName.match(/\(From\s+"([^"]+)"\)/i);
      if (movieMatch && movieMatch[1]) {
        cleanAppleMovie = movieMatch[1].trim();
      }

      // Track similarity score (0 to 50)
      const trackSim = Math.max(
        stringSimilarity(targetSongName, trackName),
        stringSimilarity(rawClean, trackName),
      );
      let score = trackSim * 50;

      // Movie similarity score (0 to 35)
      if (targetMovieName) {
        const movieSim = Math.max(
          stringSimilarity(targetMovieName, cleanAppleMovie),
          stringSimilarity(targetMovieName, collectionName),
        );
        score += movieSim * 35;
      } else {
        // If no movie provided, give points for soundtrack status
        if (collectionName.toLowerCase().includes('soundtrack') || collectionName.toLowerCase().includes('from "')) {
          score += 20;
        }
      }

      // Artist similarity score (0 to 10)
      if (extractedArtist && extractedArtist !== 'Unknown Artist') {
        const artistSim = stringSimilarity(extractedArtist, artistName);
        score += artistSim * 10;
      }

      // Tamil genre confirmation (+5 pts)
      if (primaryGenre.includes('tamil') || collectionName.toLowerCase().includes('tamil')) {
        score += 5;
      }

      if (score > highestScore) {
        highestScore = score;
        bestCandidate = {
          ...item,
          cleanMovie: cleanAppleMovie,
          matchScore: score,
        };
      }
    }

    if (bestCandidate && bestCandidate.artworkUrl100) {
      const appleArtworkUrl = bestCandidate.artworkUrl100
        .replace(/\/100x100bb\.(jpg|png)/i, '/1400x1400bb.jpg')
        .replace('100x100bb', '1400x1400bb');

      this.logger.log(`🍎 [Double-Checked] Apple Music Exact Match (Score: ${bestCandidate.matchScore.toFixed(1)}): Track="${bestCandidate.trackName}", Movie="${bestCandidate.cleanMovie}", Album="${bestCandidate.collectionName}", Artist="${bestCandidate.artistName}"`);

      const imgRes = await fetch(appleArtworkUrl);
      if (imgRes.ok) {
        const imgArrayBuffer = await imgRes.arrayBuffer();
        coverBuffer = Buffer.from(imgArrayBuffer);
        coverMime = 'image/jpeg';
        artworkUrl = appleArtworkUrl;
        coverFound = true;
      }

      // Assign exact verified Apple Music metadata
      if (bestCandidate.trackName) extractedTitle = bestCandidate.trackName;
      if (bestCandidate.artistName) extractedArtist = bestCandidate.artistName;
      if (bestCandidate.collectionName) extractedAlbum = bestCandidate.collectionName;
      if (bestCandidate.cleanMovie) targetMovieName = bestCandidate.cleanMovie;
      if (bestCandidate.primaryGenreName) genre = bestCandidate.primaryGenreName;
      if (bestCandidate.releaseDate) releaseDate = new Date(bestCandidate.releaseDate);
      if (bestCandidate.trackTimeMillis) duration = Math.round(bestCandidate.trackTimeMillis / 1000);
    } else {
      this.logger.log(`ℹ️ Using sanitized local metadata for "${extractedTitle}" (No Apple Music candidate reached confidence threshold)`);
    }

    // Clean song title for unified filenames across Drive and Database
    const cleanSongTitle = extractedTitle.trim().replace(/[/\\?%*:|"<>]/g, '_');

    // 2. Upload Ultra-HD Apple Music cover artwork buffer to Google Drive Covers folder
    if (coverBuffer && coverFound) {
      try {
        const coverFilename = `${cleanSongTitle}.jpg`;
        const coverRes = await this.driveService.uploadFile(
          'Covers',
          coverFilename,
          coverBuffer,
          coverMime,
        );
        artworkFileId = coverRes.fileId;
        if (!artworkUrl) {
          artworkUrl = this.driveService.getArtworkUrl(artworkFileId);
        }
      } catch (err) {
        this.logger.warn(`Failed to upload artwork to Drive: ${(err as Error).message}`);
      }
    }

    // 3. Upload audio file to Drive (named <SongTitle>.mp3)
    const audioFilename = `${cleanSongTitle}.mp3`;
    const audioRes = await this.driveService.uploadFile(
      'Songs',
      audioFilename,
      audioBuffer,
      mimeType,
    );
    const driveAudioUrl = `https://drive.google.com/uc?id=${audioRes.fileId}&export=download`;

    // 4. Fetch & Update Official Apple Music Artist Master Portrait Every Time
    const artistCacheKey = `applemusic:artist:${extractedArtist.toLowerCase()}`;
    let artistPortrait = (await this.redis.get<string>(artistCacheKey)) || artworkUrl;

    if (!artistPortrait || artistPortrait === artworkUrl) {
      try {
        const itunesArtistUrl = `https://itunes.apple.com/search?term=${encodeURIComponent(extractedArtist)}&country=IN&entity=musicArtist&limit=1`;
        const aRes = await fetch(itunesArtistUrl);
        if (aRes.ok) {
          const aJson: any = await aRes.json();
          if (aJson.results && aJson.results.length > 0 && aJson.results[0].artistLinkUrl) {
            const pageRes = await fetch(aJson.results[0].artistLinkUrl, {
              headers: { 'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)' },
            });
            if (pageRes.ok) {
              const html = await pageRes.text();
              const match = html.match(/<meta\s+property="og:image"\s+content="([^"]+)"/i);
              if (match && match[1]) {
                artistPortrait = match[1].replace(/\/\d+x\d+cw\.png/, '/1000x1000bb.jpg');
                this.logger.log(`🍎 Verified Apple Music Artist Master Portrait for "${extractedArtist}": ${artistPortrait}`);
                await this.redis.set(artistCacheKey, artistPortrait, 1209600); // 14 days cache
              }
            }
          }
        }
      } catch (_) {}
    }

    // Upsert Artist with verified Apple Music master portrait
    let artist = await this.prisma.artist.findUnique({
      where: { name: extractedArtist },
    });

    if (!artist) {
      artist = await this.prisma.artist.create({
        data: {
          name: extractedArtist,
          image: artistPortrait,
        },
      });
    } else if (artistPortrait && (!artist.image || artist.image.includes('placeholder') || artist.image.includes('default'))) {
      artist = await this.prisma.artist.update({
        where: { id: artist.id },
        data: { image: artistPortrait },
      });
    }

    let album = await this.prisma.album.findFirst({
      where: { title: extractedAlbum, artistId: artist.id },
    });

    if (!album) {
      album = await this.prisma.album.create({
        data: {
          title: extractedAlbum,
          artistId: artist.id,
          artwork: artworkUrl,
          releaseDate,
        },
      });
    }

    // 5. Save/Update Song in PostgreSQL via Prisma with Hard Deduplication
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
        artworkUrl: artworkUrl || undefined,
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

    this.logger.log(`✅ Song "${extractedTitle}" by "${artist.name}" (Unique Record ID: ${song.id}) saved to PostgreSQL, Redis, and Drive!`);

    // Cache song in Redis and invalidate catalog feeds
    await this.redis.set(`song:${song.id}`, song, 86400);
    await this.redis.invalidateCatalog();

    // 6. Upload metadata JSON to Drive Metadata folder (named <SongTitle>.json)
    try {
      const metaJson = JSON.stringify(song, null, 2);
      await this.driveService.uploadFile(
        'Metadata',
        `${cleanSongTitle}.json`,
        Buffer.from(metaJson, 'utf-8'),
        'application/json',
      );
    } catch (e) {
      this.logger.warn(`Could not upload JSON metadata to Drive: ${(e as Error).message}`);
    }

    return song;
  }
}
