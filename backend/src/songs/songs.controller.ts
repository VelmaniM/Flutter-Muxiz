import { Controller, Get, Post, Delete, Body, Param, Query, Headers, Res } from '@nestjs/common';
import { SongsService } from './songs.service';
import { Response } from 'express';

@Controller('api/v1/songs')
export class SongsController {
  constructor(private readonly songsService: SongsService) {}

  @Get()
  async getSongs(
    @Query('page') page?: number,
    @Query('limit') limit?: number,
    @Query('genre') genre?: string,
    @Query('language') language?: string,
    @Query('artistId') artistId?: string,
    @Query('albumId') albumId?: string,
    @Query('search') search?: string,
    @Query('nocache') nocache?: string,
    @Query('t') t?: string,
  ) {
    return this.songsService.findAll({ page, limit, genre, language, artistId, albumId, search, nocache: nocache === '1' || nocache === 'true' });
  }

  @Post()
  async createSong(@Body() body: any) {
    return this.songsService.createSong(body);
  }

  @Get(':id')
  async getSong(@Param('id') id: string) {
    return this.songsService.findOne(id);
  }

  @Delete(':id')
  async deleteSong(@Param('id') id: string) {
    return this.songsService.deleteSong(id);
  }

  @Get(':id/stream')
  async streamSong(
    @Param('id') id: string,
    @Headers('range') rangeHeader: string | undefined,
    @Res() res: Response,
  ) {
    return this.songsService.streamSong(id, rangeHeader, res);
  }

  @Post(':id/like')
  async toggleLike(
    @Param('id') id: string,
    @Headers('x-user-id') headerUserId?: string,
    @Body('userId') bodyUserId?: string,
  ) {
    const userId = bodyUserId || headerUserId || 'listener-001';
    return this.songsService.toggleLike(id, userId);
  }

  @Get(':id/likes')
  async getLikes(@Param('id') id: string) {
    return this.songsService.getLikeCount(id);
  }
}


