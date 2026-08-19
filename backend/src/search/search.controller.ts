import { Controller, Get, Query } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { RedisService } from '../redis/redis.service';

@Controller('api/v1/search')
export class SearchController {
  constructor(
    private readonly prisma: PrismaService,
    private readonly redis: RedisService,
  ) {}

  @Get()
  async search(@Query('q') query: string = '', @Query('limit') limit: number = 20) {
    const q = (query || '').trim();
    if (!q) {
      return { songs: [], artists: [], albums: [] };
    }

    const takeLimit = Math.min(50, Math.max(1, Number(limit) || 20));
    const cacheKey = `search:q:${q.toLowerCase()}:l:${takeLimit}`;

    return await this.redis.wrap(cacheKey, 1800, async () => {
      try {
        const [songs, artists, albums] = await Promise.all([
          this.prisma.song.findMany({
            where: {
              status: 'active',
              OR: [
                { title: { contains: q, mode: 'insensitive' } },
                { artistName: { contains: q, mode: 'insensitive' } },
                { albumName: { contains: q, mode: 'insensitive' } },
                { movieName: { contains: q, mode: 'insensitive' } },
                { genre: { contains: q, mode: 'insensitive' } },
              ],
            },
            take: takeLimit,
            orderBy: { playCount: 'desc' },
          }),
          this.prisma.artist.findMany({
            where: { name: { contains: q, mode: 'insensitive' } },
            take: 10,
          }),
          this.prisma.album.findMany({
            where: { title: { contains: q, mode: 'insensitive' } },
            take: 10,
          }),
        ]);

        return { songs, artists, albums };
      } catch (e) {
        return { songs: [], artists: [], albums: [] };
      }
    });
  }
}
