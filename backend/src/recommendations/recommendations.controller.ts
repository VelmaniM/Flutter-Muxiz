import { Controller, Get, Post, Query, Body, Headers } from '@nestjs/common';
import { RecommendationsService } from './recommendations.service';

@Controller('api/v1/recommendations')
export class RecommendationsController {
  constructor(private readonly recommendationsService: RecommendationsService) {}

  @Get('home-feed')
  async getHomeFeed(
    @Query('userId') queryUserId?: string,
    @Headers('x-user-id') headerUserId?: string,
    @Query('hour') hour?: number,
  ) {
    const userId = queryUserId || headerUserId || 'listener-001';
    return this.recommendationsService.getHomeFeed({
      userId,
      currentHour: hour !== undefined ? Number(hour) : undefined,
    });
  }

  @Get('trending')
  async getTrending() {
    return this.recommendationsService.getTrendingTamilInsights();
  }

  @Post('synthesize')
  async synthesizeFeed(
    @Body() body: {
      userId?: string;
      recentSongIds?: string[];
      favoriteSongIds?: string[];
      hour?: number;
    },
  ) {
    return this.recommendationsService.getHomeFeed({
      userId: body.userId || 'listener-001',
      recentSongIds: body.recentSongIds,
      favoriteSongIds: body.favoriteSongIds,
      currentHour: body.hour,
    });
  }
}
