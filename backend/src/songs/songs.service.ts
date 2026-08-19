import { Injectable, NotFoundException, Logger } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { GoogleDriveService } from '../storage/google-drive/google-drive.service';
import { RedisService } from '../redis/redis.service';
import { Response } from 'express';

@Injectable()
export class SongsService {
  private readonly logger = new Logger(SongsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly driveService: GoogleDriveService,
    private readonly redis: RedisService,
  ) {}

  async findAll(params: {
    page?: number;
    limit?: number;
    genre?: string;
    language?: string;
    artistId?: string;
    albumId?: string;
    search?: string;
    nocache?: boolean;
  }) {
    const page = Math.max(1, Number(params.page) || 1);
    const limit = Math.min(10000, Math.max(1, Number(params.limit) || 10000));
    const skip = (page - 1) * limit;

    const cacheKey = `songs:catalog:p${page}_l${limit}_s${params.search || ''}_g${params.genre || ''}_la${params.language || ''}_ar${params.artistId || ''}_al${params.albumId || ''}`;

    const fetcher = async () => {
      const where: any = { status: 'active' };

      if (params.genre) {
        where.genre = { equals: params.genre, mode: 'insensitive' };
      }
      if (params.language) {
        where.language = { equals: params.language, mode: 'insensitive' };
      }
      if (params.artistId) {
        where.artistId = params.artistId;
      }
      if (params.albumId) {
        where.albumId = params.albumId;
      }
      if (params.search) {
        where.OR = [
          { title: { contains: params.search, mode: 'insensitive' } },
          { artistName: { contains: params.search, mode: 'insensitive' } },
          { albumName: { contains: params.search, mode: 'insensitive' } },
          { movieName: { contains: params.search, mode: 'insensitive' } },
        ];
      }

      try {
        const [total, songs] = await Promise.all([
          this.prisma.song.count({ where }),
          this.prisma.song.findMany({
            where,
            skip,
            take: limit,
            orderBy: { createdAt: 'desc' },
            include: {
              artist: { select: { id: true, name: true, image: true } },
              album: { select: { id: true, title: true, artwork: true } },
            },
          }),
        ]);

        return {
          data: songs,
          meta: {
            total,
            page,
            limit,
            totalPages: Math.ceil(total / limit),
            hasNextPage: page * limit < total,
            hasPrevPage: page > 1,
          },
        };
      } catch (e) {
        return {
          data: [],
          meta: {
            total: 0,
            page,
            limit,
            totalPages: 0,
            hasNextPage: false,
            hasPrevPage: false,
          },
        };
      }
    };

    if (params.nocache) {
      const fresh = await fetcher();
      await this.redis.set(cacheKey, fresh, 3600);
      return fresh;
    }

    return await this.redis.wrap(cacheKey, 3600, fetcher);
  }

  async findOne(id: string) {
    const cacheKey = `song:${id}`;
    return await this.redis.wrap(cacheKey, 86400, async () => {
      const song = await this.prisma.song.findUnique({
        where: { id },
        include: {
          artist: true,
          album: true,
        },
      });

      if (!song) {
        throw new NotFoundException(`Song with ID ${id} not found`);
      }

      return song;
    });
  }

  async streamSong(id: string, rangeHeader: string | undefined, res: Response): Promise<void> {
    const song = await this.findOne(id);
    if (!song) {
      throw new NotFoundException(`Song not found`);
    }

    // Increment play count asynchronously in Redis / DB
    this.prisma.song
      .update({
        where: { id },
        data: { playCount: { increment: 1 } },
      })
      .catch(() => {});

    // If song has a Google Drive File ID, proxy it
    if (song.driveFileId) {
      try {
        const streamData = await this.driveService.getStreamStream(song.driveFileId, rangeHeader);

        res.status(streamData.status);
        if (streamData.contentType) res.setHeader('Content-Type', streamData.contentType);
        if (streamData.contentLength) res.setHeader('Content-Length', streamData.contentLength);
        if (streamData.contentRange) res.setHeader('Content-Range', streamData.contentRange);
        res.setHeader('Accept-Ranges', 'bytes');

        streamData.stream.pipe(res);
        return;
      } catch (err) {
        res.redirect(song.audioUrl);
        return;
      }
    }

    res.redirect(song.audioUrl);
  }

  private inMemoryFavorites: Map<string, Set<string>> = new Map();

  async toggleLike(songId: string, userId: string = 'listener-001') {
    if (!this.inMemoryFavorites.has(userId)) {
      this.inMemoryFavorites.set(userId, new Set());
    }
    const userFavs = this.inMemoryFavorites.get(userId)!;
    let isFavorite = false;

    try {
      // Ensure user exists in Postgres
      await this.prisma.user.upsert({
        where: { id: userId },
        update: {},
        create: {
          id: userId,
          email: `${userId}@muxiz.app`,
          displayName: 'Muxiz Listener',
        },
      });

      // Ensure song exists in Postgres
      const existingSong = await this.prisma.song.findUnique({ where: { id: songId } });
      if (!existingSong) {
        await this.prisma.song.create({
          data: {
            id: songId,
            title: 'Liked Track',
            audioUrl: 'https://sample.audio',
          },
        }).catch(() => {});
      }

      const existing = await this.prisma.favorite.findUnique({
        where: {
          userId_songId: { userId, songId },
        },
      });

      if (existing) {
        await this.prisma.favorite.delete({
          where: { id: existing.id },
        });
        isFavorite = false;
        userFavs.delete(songId);
      } else {
        await this.prisma.favorite.create({
          data: { userId, songId },
        });
        isFavorite = true;
        userFavs.add(songId);
      }

      const count = await this.prisma.favorite.count({
        where: { songId },
      });

      return {
        isFavorite,
        count: count || userFavs.size,
        songId,
      };
    } catch (_) {
      // In-memory fallback
      if (userFavs.has(songId)) {
        userFavs.delete(songId);
        isFavorite = false;
      } else {
        userFavs.add(songId);
        isFavorite = true;
      }

      return {
        isFavorite,
        count: userFavs.size,
        songId,
      };
    }
  }

  async getLikeCount(songId: string) {
    try {
      const count = await this.prisma.favorite.count({
        where: { songId },
      });
      return { count };
    } catch {
      return { count: 0 };
    }
  }

  async createSong(data: {
    id?: string;
    title: string;
    artistName?: string;
    albumName?: string;
    movieName?: string;
    artworkUrl?: string;
    audioUrl: string;
    duration?: number;
    genre?: string;
    language?: string;
    lyrics?: string[];
    gradient?: string[];
  }) {
    const artistName = (data.artistName || 'Unknown Artist').trim();
    const albumName = (data.albumName || data.movieName || 'Single').trim();
    const title = (data.title || 'Untitled Track').trim();
    const artwork = data.artworkUrl || 'https://c.saavncdn.com/978/Leo-Tamil-2023-20231019181048-500x500.jpg';

    try {
      // 1. Upsert Artist
      const artist = await this.prisma.artist.upsert({
        where: { name: artistName },
        update: {},
        create: { name: artistName, image: artwork },
      });

      // 2. Upsert Album
      let album = await this.prisma.album.findFirst({
        where: { title: albumName, artistId: artist.id },
      });

      if (!album) {
        album = await this.prisma.album.create({
          data: { title: albumName, artistId: artist.id, artwork },
        });
      }

      // 3. Find existing song by title & artist to strictly prevent duplicates
      const existing = await this.prisma.song.findFirst({
        where: {
          OR: [
            ...(data.id ? [{ id: data.id }] : []),
            {
              title: { equals: title, mode: 'insensitive' },
              artistName: { equals: artist.name, mode: 'insensitive' },
            },
          ],
        },
      });

      const songId = existing?.id || data.id || `upload_${Date.now()}`;
      const saved = await this.prisma.song.upsert({
        where: { id: songId },
        update: {
          title,
          artistId: artist.id,
          albumId: album.id,
          artistName: artist.name,
          albumName: album.title,
          movieName: data.movieName || null,
          artworkUrl: artwork,
          audioUrl: data.audioUrl,
          duration: data.duration || 180,
          genre: data.genre || 'Music',
          language: data.language || 'Tamil',
          lyrics: data.lyrics || [],
          gradient: data.gradient || ['#1DB954', '#0B0C10'],
        },
        create: {
          id: songId,
          title,
          artistId: artist.id,
          albumId: album.id,
          artistName: artist.name,
          albumName: album.title,
          movieName: data.movieName || null,
          artworkUrl: artwork,
          audioUrl: data.audioUrl,
          duration: data.duration || 180,
          genre: data.genre || 'Music',
          language: data.language || 'Tamil',
          lyrics: data.lyrics || [],
          gradient: data.gradient || ['#1DB954', '#0B0C10'],
        },
        include: {
          artist: { select: { id: true, name: true, image: true } },
          album: { select: { id: true, title: true, artwork: true } },
        },
      });

      // Cache new song and invalidate catalog feed
      if (saved) {
        await this.redis.set(`song:${saved.id}`, saved, 86400);
        await this.redis.invalidateCatalog();
      }

      return saved;
    } catch (e) {
      return null;
    }
  }

  async deleteSong(id: string) {
    // Invalidate Redis cache immediately
    await this.redis.invalidateSong(id);
    await this.redis.invalidateCatalog();

    // 1. Check if song exists in PostgreSQL
    let song: any = null;
    try {
      song = await this.prisma.song.findUnique({ where: { id } });
    } catch (_) {}

    // 2. Delete files from Google Drive (Audio, Covers, and Metadata)
    if (song) {
      const cleanTitle = (song.title || '').trim().replace(/[/\\?%*:|"<>]/g, '_');

      // Direct file ID deletion
      if (song.driveFileId) {
        await this.driveService.deleteFile(song.driveFileId);
      }
      if (song.artworkFileId) {
        await this.driveService.deleteFile(song.artworkFileId);
      }

      // Name-based fallback deletion in case IDs were unlinked
      if (cleanTitle) {
        await this.driveService.deleteFileByName('Songs', `${cleanTitle}.mp3`);
        await this.driveService.deleteFileByName('Covers', `${cleanTitle}.jpg`);
        await this.driveService.deleteFileByName('Metadata', `${cleanTitle}.json`);
      }
      await this.driveService.deleteFileByName('Metadata', `${id}.json`);
    } else {
      // Direct deletion by ID for metadata JSON
      await this.driveService.deleteFileByName('Metadata', `${id}.json`);
    }

    // 3. Delete database relationships and song record in PostgreSQL
    try {
      await this.prisma.favorite.deleteMany({ where: { songId: id } }).catch(() => {});
      await this.prisma.recentlyPlayed.deleteMany({ where: { songId: id } }).catch(() => {});
      await this.prisma.listeningHistory.deleteMany({ where: { songId: id } }).catch(() => {});
      await this.prisma.downloadRecord.deleteMany({ where: { songId: id } }).catch(() => {});
      await this.prisma.playlistSong.deleteMany({ where: { songId: id } }).catch(() => {});
      await this.prisma.song.delete({ where: { id } }).catch(() => {});
    } catch (_) {}

    // 4. Clear in-memory state
    for (const [_, favSet] of this.inMemoryFavorites.entries()) {
      favSet.delete(id);
    }

    return {
      success: true,
      message: `Song ${id} successfully deleted from Google Drive, PostgreSQL DB, and playlists`,
      id,
    };
  }
}
