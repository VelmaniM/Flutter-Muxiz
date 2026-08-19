import { Controller, Get, Post, Delete, Body, Param, UseGuards, Req, Query } from '@nestjs/common';
import { UsersService } from './users.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';

@UseGuards(JwtAuthGuard)
@Controller('api/v1/users')
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Get('favorites')
  async getFavorites(@Req() req: any) {
    return this.usersService.getFavorites(req.user.id);
  }

  @Post('favorites/:songId')
  async toggleFavorite(@Req() req: any, @Param('songId') songId: string) {
    return this.usersService.toggleFavorite(req.user.id, songId);
  }

  @Get('recently-played')
  async getRecentlyPlayed(@Req() req: any, @Query('limit') limit?: number) {
    return this.usersService.getRecentlyPlayed(req.user.id, limit);
  }

  @Post('recently-played/:songId')
  async recordRecentlyPlayed(@Req() req: any, @Param('songId') songId: string) {
    return this.usersService.recordRecentlyPlayed(req.user.id, songId);
  }

  @Post('history')
  async recordHistory(@Req() req: any, @Body() body: { songId: string; duration: number }) {
    return this.usersService.recordHistory(req.user.id, body.songId, body.duration);
  }

  @Get('downloads')
  async getDownloads(@Req() req: any) {
    return this.usersService.getDownloads(req.user.id);
  }

  @Post('downloads')
  async recordDownload(@Req() req: any, @Body() body: { songId: string; deviceId?: string; fileSize?: number }) {
    return this.usersService.recordDownload(req.user.id, body.songId, body.deviceId, body.fileSize);
  }

  @Delete('downloads/:songId')
  async removeDownload(@Req() req: any, @Param('songId') songId: string) {
    return this.usersService.removeDownload(req.user.id, songId);
  }
}
