import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class UsersService {
  constructor(private readonly prisma: PrismaService) {}

  private inMemoryFavorites: Map<string, Set<string>> = new Map();

  private async ensureUser(userId: string) {
    try {
      return await this.prisma.user.upsert({
        where: { id: userId },
        update: {},
        create: {
          id: userId,
          email: `${userId}@muxiz.app`,
          displayName: 'Muxiz Listener',
        },
      });
    } catch {
      return null;
    }
  }

  async getFavorites(userId: string) {
    try {
      const favs = await this.prisma.favorite.findMany({
        where: { userId },
        include: {
          song: {
            include: {
              artist: true,
              album: true,
            },
          },
        },
        orderBy: { createdAt: 'desc' },
      });

      return favs.map((f) => f.song);
    } catch (_) {
      const songIds = Array.from(this.inMemoryFavorites.get(userId) || []);
      return songIds.map((id) => ({
        id,
        title: 'Liked Track',
        artistName: 'Tamil Artist',
        audioUrl: '',
        artworkUrl: '',
      }));
    }
  }

  async toggleFavorite(userId: string, songId: string) {
    if (!this.inMemoryFavorites.has(userId)) {
      this.inMemoryFavorites.set(userId, new Set());
    }
    const userFavs = this.inMemoryFavorites.get(userId)!;
    let isFavorite = false;

    try {
      await this.prisma.user.upsert({
        where: { id: userId },
        update: {},
        create: {
          id: userId,
          email: `${userId}@muxiz.app`,
          displayName: 'Muxiz Listener',
        },
      });

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

      return { isFavorite, count: count || userFavs.size };
    } catch (e) {
      if (userFavs.has(songId)) {
        userFavs.delete(songId);
        isFavorite = false;
      } else {
        userFavs.add(songId);
        isFavorite = true;
      }
      return { isFavorite, count: userFavs.size };
    }
  }

  async recordRecentlyPlayed(userId: string, songId: string) {
    try {
      await this.ensureUser(userId);
      const songExists = await this.prisma.song.findUnique({ where: { id: songId } });
      if (!songExists) {
        await this.prisma.song.upsert({
          where: { id: songId },
          update: {},
          create: { id: songId, title: 'Track', artistName: 'Artist', audioUrl: '', duration: 180 },
        });
      }
      return await this.prisma.recentlyPlayed.upsert({
        where: {
          userId_songId: { userId, songId },
        },
        create: {
          userId,
          songId,
          playedAt: new Date(),
        },
        update: {
          playedAt: new Date(),
        },
      });
    } catch {
      return null;
    }
  }

  async getRecentlyPlayed(userId: string, limit: number = 20) {
    try {
      const recent = await this.prisma.recentlyPlayed.findMany({
        where: { userId },
        take: limit,
        orderBy: { playedAt: 'desc' },
        include: {
          song: {
            include: {
              artist: true,
              album: true,
            },
          },
        },
      });
      return recent.map((r) => r.song);
    } catch {
      return [];
    }
  }

  async recordHistory(userId: string, songId: string, duration: number) {
    try {
      await this.ensureUser(userId);
      const songExists = await this.prisma.song.findUnique({ where: { id: songId } });
      if (!songExists) {
        await this.prisma.song.upsert({
          where: { id: songId },
          update: {},
          create: { id: songId, title: 'Track', artistName: 'Artist', audioUrl: '', duration: 180 },
        });
      }
      return await this.prisma.listeningHistory.create({
        data: {
          userId,
          songId,
          duration: duration || 180,
        },
      });
    } catch {
      return null;
    }
  }

  async recordDownload(userId: string, songId: string, deviceId: string = 'ios-device', fileSize: number = 0) {
    try {
      await this.prisma.user.upsert({
        where: { id: userId },
        update: {},
        create: { id: userId, email: `${userId}@muxiz.app`, displayName: 'Muxiz Listener' },
      });
      return await this.prisma.downloadRecord.upsert({
        where: { userId_songId_deviceId: { userId, songId, deviceId } },
        create: { userId, songId, deviceId, fileSize },
        update: { downloadedAt: new Date(), fileSize },
      });
    } catch {
      return null;
    }
  }

  async removeDownload(userId: string, songId: string) {
    try {
      return await this.prisma.downloadRecord.deleteMany({
        where: { userId, songId },
      });
    } catch {
      return { count: 0 };
    }
  }

  async getDownloads(userId: string) {
    try {
      const records = await this.prisma.downloadRecord.findMany({
        where: { userId },
        include: {
          song: {
            include: { artist: true, album: true },
          },
        },
        orderBy: { downloadedAt: 'desc' },
      });
      return records.map((r) => r.song);
    } catch {
      return [];
    }
  }
}
