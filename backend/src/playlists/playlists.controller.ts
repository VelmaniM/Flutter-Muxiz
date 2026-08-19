import { Controller, Get, Post, Delete, Body, Param, Headers, Query, Req } from '@nestjs/common';
import { PlaylistsService } from './playlists.service';

@Controller('api/v1/playlists')
export class PlaylistsController {
  constructor(private readonly playlistsService: PlaylistsService) {}

  @Get()
  async getMyPlaylists(
    @Req() req: any,
    @Headers('x-user-id') headerUserId?: string,
    @Query('userId') queryUserId?: string,
  ) {
    const userId = req.user?.id || headerUserId || queryUserId || 'listener-001';
    return this.playlistsService.getUserPlaylists(userId);
  }

  @Post()
  async createPlaylist(
    @Body() body: { title: string; description?: string; cover?: string; userId?: string; initialSongId?: string },
    @Req() req?: any,
    @Headers('x-user-id') headerUserId?: string,
  ) {
    const userId = req?.user?.id || headerUserId || body.userId || 'listener-001';
    return this.playlistsService.createPlaylist(userId, body.title, body.description, body.cover, body.initialSongId);
  }

  @Post(':id/songs')
  async addSong(@Param('id') playlistId: string, @Body() body: { songId: string }) {
    return this.playlistsService.addSongToPlaylist(playlistId, body.songId);
  }

  @Delete(':id/songs/:songId')
  async removeSong(@Param('id') playlistId: string, @Param('songId') songId: string) {
    return this.playlistsService.removeSongFromPlaylist(playlistId, songId);
  }

  @Delete(':id')
  async deletePlaylist(@Param('id') playlistId: string) {
    return this.playlistsService.deletePlaylist(playlistId);
  }
}
