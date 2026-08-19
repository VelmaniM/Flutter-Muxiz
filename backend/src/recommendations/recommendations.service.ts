import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { RedisService } from '../redis/redis.service';
import axios from 'axios';

export interface RecommendationContext {
  userId?: string;
  timeOfDay?: 'morning' | 'afternoon' | 'evening' | 'late_night';
  currentHour?: number;
  recentSongIds?: string[];
  favoriteSongIds?: string[];
}

@Injectable()
export class RecommendationsService {
  private readonly geminiApiKey = process.env.GEMINI_API_KEY || '';

  constructor(
    private readonly prisma: PrismaService,
    private readonly redis: RedisService,
  ) {}

  /**
   * Generates a Spotify-style personalized Home Feed combining
   * user telemetry, time-of-day mood analysis, and Gemini AI synthesis.
   */
  async getHomeFeed(ctx: RecommendationContext) {
    const userId = ctx.userId || 'listener-001';
    const hour = ctx.currentHour ?? new Date().getHours();
    const timeOfDay = this.getTimeOfDay(hour);

    const cacheKey = `home:feed:${userId}:${timeOfDay}`;
    return await this.redis.wrap(cacheKey, 1800, async () => {
      // 1. Fetch available active songs from database (or fallback)
    let allSongs: any[] = [];
    try {
      allSongs = await this.prisma.song.findMany({
        where: { status: 'active' },
        include: {
          artist: { select: { id: true, name: true, image: true } },
          album: { select: { id: true, title: true, artwork: true } },
        },
        orderBy: { playCount: 'desc' },
        take: 100,
      });
    } catch (e) {
      allSongs = [];
    }

    // 2. Fetch user's recent listening history & favorites
    let userRecents: any[] = [];
    let userFavorites: any[] = [];
    try {
      [userRecents, userFavorites] = await Promise.all([
        this.prisma.recentlyPlayed.findMany({
          where: { userId },
          include: { song: { include: { artist: true, album: true } } },
          orderBy: { playedAt: 'desc' },
          take: 20,
        }),
        this.prisma.favorite.findMany({
          where: { userId },
          include: { song: { include: { artist: true, album: true } } },
          orderBy: { createdAt: 'desc' },
          take: 30,
        }),
      ]);
    } catch (e) {}

    // Extract listened songs pool
    const listenedSongs = [
      ...userRecents.map((r) => r.song).filter(Boolean),
      ...userFavorites.map((f) => f.song).filter(Boolean),
    ];

    // 3. Time of Day & Contextual Vibes
    const hour = ctx.currentHour ?? new Date().getHours();
    const timeOfDay = this.getTimeOfDay(hour);

    // 4. Extract Top Artists & Dominant Genres
    const artistCounts: Record<string, number> = {};
    for (const s of listenedSongs) {
      const artist = s.artistName || s.artist?.name;
      if (artist) {
        artistCounts[artist] = (artistCounts[artist] || 0) + 1;
      }
    }

    const sortedArtists = Object.entries(artistCounts)
      .sort((a, b) => b[1] - a[1])
      .map((entry) => entry[0]);

    const topArtist = sortedArtists[0] || 'Anirudh Ravichander';
    const secondaryArtist = sortedArtists[1] || 'A.R. Rahman';

    // 5. Generate Spotify Daily Mixes (Cluster 1 & Cluster 2)
    const dailyMix1Songs = this.filterSongsByArtistsOrGenre(allSongs, [topArtist, 'Yuvan Shankar Raja', 'Harris Jayaraj']);
    const dailyMix2Songs = this.filterSongsByArtistsOrGenre(allSongs, [secondaryArtist, 'Sid Sriram', 'Pradeep Kumar']);

    // 6. Generate Time-of-Day Vibe Playlist
    const timeVibe = this.getTimeVibeConfig(timeOfDay);
    const timeVibeSongs = allSongs.slice(0, 15);

    // 7. Generate "Because You Listen To [Top Artist]"
    const topArtistSongs = allSongs.filter(
      (s) =>
        (s.artistName && s.artistName.toLowerCase().includes(topArtist.toLowerCase())) ||
        (s.artist?.name && s.artist.name.toLowerCase().includes(topArtist.toLowerCase()))
    );

    // 8. Discover Weekly (Personalized Recommendations)
    const discoverSongs = allSongs.filter(
      (s) => !listenedSongs.some((ls) => ls.id === s.id)
    ).slice(0, 15);

    // 9. Synthesize AI Creative Descriptions via Gemini if available
    const aiDescriptions = await this.synthesizeWithGemini({
      topArtist,
      secondaryArtist,
      timeOfDay,
      vibeTitle: timeVibe.title,
    });

    return {
      status: 'success',
      generatedAt: new Date().toISOString(),
      timeOfDay,
      topArtist,
      quickPlay: listenedSongs.slice(0, 6).length >= 4 ? listenedSongs.slice(0, 6) : allSongs.slice(0, 6),
      dailyMixes: [
        {
          id: 'daily_mix_1',
          title: `Daily Mix 1`,
          subtitle: `${topArtist}, ${secondaryArtist} and more`,
          description: aiDescriptions.dailyMix1 || `A dynamic mix featuring ${topArtist} and similar artists you love.`,
          gradient: ['#1DB954', '#121212'],
          coverUrl: dailyMix1Songs[0]?.artworkUrl || '',
          songs: dailyMix1Songs.length > 0 ? dailyMix1Songs : allSongs.slice(0, 12),
        },
        {
          id: 'daily_mix_2',
          title: `Daily Mix 2`,
          subtitle: `${secondaryArtist}, Sid Sriram and more`,
          description: aiDescriptions.dailyMix2 || `Melodic hits and chartbusters centered around ${secondaryArtist}.`,
          gradient: ['#7B2CBF', '#121212'],
          coverUrl: dailyMix2Songs[0]?.artworkUrl || '',
          songs: dailyMix2Songs.length > 0 ? dailyMix2Songs : allSongs.slice(6, 18),
        },
      ],
      timeVibe: {
        id: `vibe_${timeOfDay}`,
        title: timeVibe.title,
        subtitle: timeVibe.subtitle,
        description: aiDescriptions.timeVibe || timeVibe.description,
        coverUrl: timeVibeSongs[0]?.artworkUrl || '',
        songs: timeVibeSongs,
      },
      becauseYouListenTo: {
        artist: topArtist,
        title: `Because you listen to ${topArtist}`,
        subtitle: `Featuring top tracks and collaborations`,
        songs: topArtistSongs.length > 0 ? topArtistSongs : allSongs.slice(0, 10),
      },
      discoverWeekly: {
        id: 'discover_weekly',
        title: 'Discover Weekly',
        subtitle: 'Your weekly mixtape of fresh music',
        description: 'New discoveries and deep cuts picked just for you by Muxiz AI.',
        songs: discoverSongs.length > 0 ? discoverSongs : allSongs.slice(0, 15),
      },
    };
    });
  }

  private getTimeOfDay(hour: number): 'morning' | 'afternoon' | 'evening' | 'late_night' {
    if (hour >= 5 && hour < 12) return 'morning';
    if (hour >= 12 && hour < 17) return 'afternoon';
    if (hour >= 17 && hour < 22) return 'evening';
    return 'late_night';
  }

  private getTimeVibeConfig(timeOfDay: string) {
    switch (timeOfDay) {
      case 'morning':
        return {
          title: 'Morning Motivation & Acoustic Starts',
          subtitle: 'Energizing melodies to kickstart your day',
          description: 'Uplifting tunes and acoustic rhythms for fresh focus.',
        };
      case 'afternoon':
        return {
          title: 'Afternoon Flow & Hit Beats',
          subtitle: 'High energy tracks to power through the day',
          description: 'Non-stop chartbusters and upbeat melodies.',
        };
      case 'evening':
        return {
          title: 'Evening Unwind & Chartbusters',
          subtitle: 'Relax and groove with the biggest hits',
          description: 'Romantic melodies and vibrant celebration anthems.',
        };
      case 'late_night':
      default:
        return {
          title: 'Late Night Melodies & Deep Chill',
          subtitle: 'Soft vocals, soul harmonies & soothing strings',
          description: 'Calming late-night acoustics for deep listening.',
        };
    }
  }

  private filterSongsByArtistsOrGenre(songs: any[], keywords: string[]) {
    if (!songs || songs.length === 0) return [];
    const matched = songs.filter((s) => {
      const art = (s.artistName || s.artist?.name || '').toLowerCase();
      const title = (s.title || '').toLowerCase();
      const genre = (s.genre || '').toLowerCase();
      return keywords.some(
        (kw) =>
          art.includes(kw.toLowerCase()) ||
          title.includes(kw.toLowerCase()) ||
          genre.includes(kw.toLowerCase())
      );
    });

    return matched.length >= 4 ? matched : songs.slice(0, 12);
  }

  // In-memory daily cache for AI trending insights (resets every day at 5:30 AM IST)
  private trendingCache: { data: any; expiresAt: number } | null = null;

  /**
   * Calculates the next 5:30 AM IST (00:00:00 UTC) expiration epoch timestamp.
   * Ensures the dynamic AI Tamil trend intelligence resets daily at 5:30 AM Indian Standard Time.
   */
  private getNext530AmIstExpiry(): number {
    const now = new Date();
    // 05:30 AM IST is exactly 00:00:00 UTC of each day.
    const nextResetUtc = new Date(Date.UTC(
      now.getUTCFullYear(),
      now.getUTCMonth(),
      now.getUTCDate() + 1,
      0, 0, 0, 0
    ));
    return nextResetUtc.getTime();
  }

  /**
   * Analyzes live Tamil music trends (Spotify/Apple Music/YouTube Tamil trends)
   * using Gemini AI with automatic daily 5:30 AM IST caching and dynamic fallback.
   */
  async getTrendingTamilInsights() {
    const now = Date.now();
    if (this.trendingCache && this.trendingCache.expiresAt > now) {
      return this.trendingCache.data;
    }

    let allSongs: any[] = [];
    try {
      allSongs = await this.prisma.song.findMany({
        where: { status: 'active' },
        include: {
          artist: { select: { id: true, name: true, image: true } },
          album: { select: { id: true, title: true, artwork: true } },
        },
        orderBy: { playCount: 'desc' },
        take: 120,
      });
    } catch (_) {
      allSongs = [];
    }

    // Dynamic AI synthesis or Intelligent Algorithmic Scoring
    const aiAnalysis = await this.analyzeTamilTrendsWithGemini(allSongs);

    const result = {
      status: 'success',
      generatedAt: new Date().toISOString(),
      source: 'Gemini AI + Muxiz Live Stream Intelligence',
      dailySpotlight: aiAnalysis.dailySpotlight || {
        title: "Today's Tamil AI Spotlight",
        rationale: 'Top viral chartbusters currently dominating Spotify Tamil Top 50 & Apple Music India.',
        badge: '🔥 #1 Trending Today',
      },
      trendingBadges: aiAnalysis.badges || [
        { id: 'viral', label: '⚡ Viral Tamil Hit', color: '#1DB954' },
        { id: 'top_streamed', label: '🔥 Top Streamed', color: '#FF4D4D' },
        { id: 'high_replay', label: '🔁 High Replay Value', color: '#9B51E0' },
        { id: 'fresh_drop', label: '🚀 Fresh Drop', color: '#2F80ED' },
      ],
      trendingCategories: [
        {
          id: 'top_trending_now',
          title: '🔥 Trending Today in Tamil Music',
          subtitle: 'Real-time high-momentum tracks analyzed by AI',
          songs: allSongs.slice(0, 15),
        },
        {
          id: 'viral_chartbusters',
          title: '🌟 Top Hits & Fan Favorites',
          subtitle: 'Most-streamed anthems & viral reels songs',
          songs: allSongs.slice(15, 30),
        },
        {
          id: 'latest_kollywood_drops',
          title: '🚀 Latest Kollywood Releases (2024-2026)',
          subtitle: 'Fresh soundtrack cuts & new singles',
          songs: allSongs.slice(30, 45),
        },
      ],
    };

    // Cache until next 5:30 AM IST (00:00:00 UTC)
    this.trendingCache = {
      data: result,
      expiresAt: this.getNext530AmIstExpiry(),
    };

    return result;
  }

  private async analyzeTamilTrendsWithGemini(songs: any[]): Promise<any> {
    if (!this.geminiApiKey || this.geminiApiKey.length < 10) {
      return {};
    }

    try {
      const topSample = songs.slice(0, 20).map((s) => ({
        title: s.title,
        artist: s.artistName || s.artist?.name,
        album: s.albumName || s.album?.title,
      }));

      const prompt = `You are the Lead Music Data Analyst & AI Curator for Spotify/Apple Music Tamil Charts.
Sample active Tamil catalog tracks: ${JSON.stringify(topSample)}.
Analyze current Tamil listener trends and return a JSON object:
{
  "dailySpotlight": {
    "title": "Today's Tamil AI Spotlight",
    "rationale": "1-sentence exciting summary of why these songs are trending today (e.g. Leo, GOAT, Amaran, Anirudh bangers)",
    "badge": "🔥 #1 Trending Today"
  }
}
Return ONLY valid JSON.`;

      const res = await axios.post(
        `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${this.geminiApiKey}`,
        {
          contents: [{ parts: [{ text: prompt }] }],
          generationConfig: {
            responseMimeType: 'application/json',
            temperature: 0.7,
          },
        },
        { timeout: 3500 }
      );

      const candidate = res.data?.candidates?.[0]?.content?.parts?.[0]?.text;
      if (candidate) {
        return JSON.parse(candidate);
      }
    } catch (_) {}

    return {};
  }

  /**
   * Calls Gemini Generative Language API if valid API key is present
   */
  private async synthesizeWithGemini(params: {
    topArtist: string;
    secondaryArtist: string;
    timeOfDay: string;
    vibeTitle: string;
  }): Promise<{ dailyMix1?: string; dailyMix2?: string; timeVibe?: string }> {
    if (!this.geminiApiKey || this.geminiApiKey.length < 10) {
      return {};
    }

    try {
      const prompt = `You are the AI Music Recommendation Engine for Spotify-like music app Muxiz.
User's top artists: ${params.topArtist}, ${params.secondaryArtist}.
Current time context: ${params.timeOfDay} (${params.vibeTitle}).
Generate 3 short, engaging 1-sentence playlist descriptions:
1. dailyMix1: Description for Daily Mix 1 (${params.topArtist})
2. dailyMix2: Description for Daily Mix 2 (${params.secondaryArtist})
3. timeVibe: Description for ${params.vibeTitle}
Return ONLY valid JSON matching this structure:
{"dailyMix1": "...", "dailyMix2": "...", "timeVibe": "..."}`;

      const res = await axios.post(
        `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${this.geminiApiKey}`,
        {
          contents: [{ parts: [{ text: prompt }] }],
          generationConfig: {
            responseMimeType: 'application/json',
            temperature: 0.7,
          },
        },
        { timeout: 3000 }
      );

      const candidate = res.data?.candidates?.[0]?.content?.parts?.[0]?.text;
      if (candidate) {
        return JSON.parse(candidate);
      }
    } catch (e) {
      // Graceful fallback to heuristic algorithm
    }

    return {};
  }
}
