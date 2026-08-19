import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class PlaylistsService {
  constructor(private readonly prisma: PrismaService) {}

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

  async getUserPlaylists(userId: string) {
    await this.ensureUser(userId);
    try {
      return await this.prisma.playlist.findMany({
        where: {
          OR: [{ userId }, { isPublic: true }],
        },
        include: {
          songs: {
            include: {
              song: true,
            },
            orderBy: { position: 'asc' },
          },
        },
        orderBy: { updatedAt: 'desc' },
      });
    } catch {
      return [];
    }
  }

  async getPlaylistById(id: string) {
    try {
      return await this.prisma.playlist.findUnique({
        where: { id },
        include: {
          songs: {
            include: {
              song: true,
            },
            orderBy: { position: 'asc' },
          },
        },
      });
    } catch {
      return null;
    }
  }

  async createPlaylist(userId: string, title: string, description?: string, cover?: string, initialSongId?: string) {
    await this.ensureUser(userId);
    try {
      const playlist = await this.prisma.playlist.create({
        data: {
          userId,
          title,
          description: description || 'Custom Playlist',
          cover: cover || '',
          isPublic: true,
        },
        include: {
          songs: {
            include: { song: true },
          },
        },
      });

      if (initialSongId) {
        await this.addSongToPlaylist(playlist.id, initialSongId);
        return await this.getPlaylistById(playlist.id) || playlist;
      }

      return playlist;
    } catch {
      return {
        id: `local_${Date.now()}`,
        userId,
        title,
        description: description || 'Custom Playlist',
        cover: cover || '',
        isPublic: true,
        createdAt: new Date(),
        updatedAt: new Date(),
        songs: [],
      };
    }
  }

  async addSongToPlaylist(playlistId: string, songId: string) {
    try {
      // Ensure song exists in DB to prevent foreign key errors
      const songExists = await this.prisma.song.findUnique({
        where: { id: songId },
      });

      if (!songExists) {
        await this.prisma.song.upsert({
          where: { id: songId },
          update: {},
          create: {
            id: songId,
            title: 'Track',
            artistName: 'Artist',
            audioUrl: '',
            duration: 180,
          },
        });
      }

      // Check if already in playlist
      const existing = await this.prisma.playlistSong.findUnique({
        where: {
          playlistId_songId: { playlistId, songId },
        },
      });

      if (existing) {
        return { success: true, added: false, alreadyExists: true, playlistSong: existing };
      }

      const lastSong = await this.prisma.playlistSong.findFirst({
        where: { playlistId },
        orderBy: { position: 'desc' },
      });

      const position = lastSong ? lastSong.position + 1 : 0;

      const created = await this.prisma.playlistSong.create({
        data: {
          playlistId,
          songId,
          position,
        },
      });

      return { success: true, added: true, alreadyExists: false, playlistSong: created };
    } catch {
      return { success: false, added: false, alreadyExists: false, message: 'Could not add song to playlist' };
    }
  }

  async removeSongFromPlaylist(playlistId: string, songId: string) {
    try {
      return await this.prisma.playlistSong.deleteMany({
        where: { playlistId, songId },
      });
    } catch {
      return { count: 0 };
    }
  }

  async deletePlaylist(playlistId: string) {
    try {
      await this.prisma.playlistSong.deleteMany({
        where: { playlistId },
      }).catch(() => {});

      return await this.prisma.playlist.delete({
        where: { id: playlistId },
      });
    } catch {
      return null;
    }
  }
}
