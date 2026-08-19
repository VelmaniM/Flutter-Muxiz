import { Injectable, OnModuleInit, OnModuleDestroy, Logger } from '@nestjs/common';
import Redis from 'ioredis';

@Injectable()
export class RedisService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(RedisService.name);
  private client: Redis | null = null;
  private isConnected = false;
  private inMemoryFallback = new Map<string, { value: any; expiry: number }>();

  onModuleInit() {
    this.initRedis();
  }

  private initRedis() {
    try {
      const host = process.env.REDIS_HOST || '127.0.0.1';
      const port = Number(process.env.REDIS_PORT) || 6379;
      const password = process.env.REDIS_PASSWORD || undefined;

      this.client = new Redis({
        host,
        port,
        password,
        retryStrategy: (times) => {
          const delay = Math.min(times * 100, 3000);
          return delay;
        },
        maxRetriesPerRequest: 3,
        enableReadyCheck: true,
        lazyConnect: false,
      });

      this.client.on('connect', () => {
        this.isConnected = true;
        this.logger.log(`⚡ [Redis] Successfully connected to Redis Server at ${host}:${port}`);
      });

      this.client.on('error', (err) => {
        this.isConnected = false;
        this.logger.warn(`⚠️ [Redis] Connection notice: ${err.message} (Using ultra-fast in-memory fallback)`);
      });

      this.client.on('close', () => {
        this.isConnected = false;
      });
    } catch (e) {
      this.logger.warn(`⚠️ [Redis] Failed to initialize Redis client: ${(e as Error).message}`);
    }
  }

  onModuleDestroy() {
    if (this.client) {
      this.client.disconnect();
    }
  }

  /**
   * Get value from cache with type safety
   */
  async get<T>(key: string): Promise<T | null> {
    try {
      if (this.isConnected && this.client) {
        const raw = await this.client.get(key);
        if (raw) {
          return JSON.parse(raw) as T;
        }
        return null;
      }
    } catch (e) {
      this.logger.debug(`Redis get error for key "${key}": ${(e as Error).message}`);
    }

    // In-memory fallback
    const item = this.inMemoryFallback.get(key);
    if (item) {
      if (item.expiry > Date.now()) {
        return item.value as T;
      }
      this.inMemoryFallback.delete(key);
    }
    return null;
  }

  /**
   * Set value in cache with TTL in seconds
   */
  async set(key: string, value: any, ttlSeconds: number = 3600): Promise<void> {
    const serialized = JSON.stringify(value);
    try {
      if (this.isConnected && this.client) {
        if (ttlSeconds > 0) {
          await this.client.set(key, serialized, 'EX', ttlSeconds);
        } else {
          await this.client.set(key, serialized);
        }
        return;
      }
    } catch (e) {
      this.logger.debug(`Redis set error for key "${key}": ${(e as Error).message}`);
    }

    // In-memory fallback
    this.inMemoryFallback.set(key, {
      value,
      expiry: Date.now() + ttlSeconds * 1000,
    });
  }

  /**
   * Cache-Aside Wrapper: Return cached item or compute, cache, and return
   */
  async wrap<T>(key: string, ttlSeconds: number, fn: () => Promise<T>): Promise<T> {
    const cached = await this.get<T>(key);
    if (cached !== null && cached !== undefined) {
      return cached;
    }

    const fresh = await fn();
    if (fresh !== null && fresh !== undefined) {
      await this.set(key, fresh, ttlSeconds);
    }
    return fresh;
  }

  /**
   * Delete a specific cache key
   */
  async del(key: string | string[]): Promise<void> {
    const keys = Array.isArray(key) ? key : [key];
    try {
      if (this.isConnected && this.client && keys.length > 0) {
        await this.client.del(...keys);
      }
    } catch (e) {
      this.logger.debug(`Redis del error: ${(e as Error).message}`);
    }

    for (const k of keys) {
      this.inMemoryFallback.delete(k);
    }
  }

  /**
   * Delete all keys matching a pattern (e.g. "songs:*", "artist:*")
   */
  async delByPattern(pattern: string): Promise<void> {
    try {
      if (this.isConnected && this.client) {
        const keys = await this.client.keys(pattern);
        if (keys.length > 0) {
          await this.client.del(...keys);
          this.logger.log(`🧹 [Redis] Invalidated ${keys.length} keys matching "${pattern}"`);
        }
      }
    } catch (e) {
      this.logger.debug(`Redis delByPattern error: ${(e as Error).message}`);
    }

    // In-memory pattern deletion
    const regex = new RegExp(`^${pattern.replace(/\*/g, '.*')}$`);
    for (const k of this.inMemoryFallback.keys()) {
      if (regex.test(k)) {
        this.inMemoryFallback.delete(k);
      }
    }
  }

  /**
   * Invalidate all music catalog feeds
   */
  async invalidateCatalog(): Promise<void> {
    await Promise.all([
      this.delByPattern('songs:*'),
      this.delByPattern('artists:*'),
      this.delByPattern('albums:*'),
      this.delByPattern('home:*'),
      this.delByPattern('search:*'),
    ]);
  }

  /**
   * Invalidate specific song & related artist/album caches
   */
  async invalidateSong(songId: string, artistId?: string, albumId?: string): Promise<void> {
    const keys = [`song:${songId}`, `player:stream:${songId}`];
    if (artistId) keys.push(`artist:${artistId}`);
    if (albumId) keys.push(`album:${albumId}`);
    await this.del(keys);
    await this.delByPattern('songs:catalog:*');
  }

  /**
   * Check connection status
   */
  getStatus(): { connected: boolean; provider: 'redis' | 'memory' } {
    return {
      connected: this.isConnected,
      provider: this.isConnected ? 'redis' : 'memory',
    };
  }
}
