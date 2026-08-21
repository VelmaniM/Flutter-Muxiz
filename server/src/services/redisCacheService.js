const Redis = require('ioredis');

class RedisCacheService {
  constructor() {
    this.client = null;
    this.memoryCache = new Map();
    this.isRedisConnected = false;
    this._init();
  }

  _init() {
    const redisUrl = process.env.REDIS_URL || 'redis://127.0.0.1:6379';
    try {
      this.client = new Redis(redisUrl, {
        connectTimeout: 2000,
        maxRetriesPerRequest: 1,
        retryStrategy: () => null, // Don't block if Redis server not installed
        lazyConnect: true,
      });

      this.client.connect().then(() => {
        this.isRedisConnected = true;
        console.log('⚡ [RedisCache] Connected to High-Performance Redis Cluster!');
      }).catch(() => {
        this.isRedisConnected = false;
        console.log('⚡ [RedisCache] Redis server offline, activated 0ms In-Memory Ultra-Cache Engine.');
      });

      this.client.on('error', () => {
        this.isRedisConnected = false;
      });
    } catch (_) {
      this.isRedisConnected = false;
    }
  }

  async get(key) {
    if (this.isRedisConnected && this.client) {
      try {
        const val = await this.client.get(key);
        return val ? JSON.parse(val) : null;
      } catch (_) {}
    }
    const mem = this.memoryCache.get(key);
    if (!mem) return null;
    if (mem.expiresAt && Date.now() > mem.expiresAt) {
      this.memoryCache.delete(key);
      return null;
    }
    return mem.data;
  }

  async set(key, value, ttlSeconds = 300) {
    if (this.isRedisConnected && this.client) {
      try {
        await this.client.set(key, JSON.stringify(value), 'EX', ttlSeconds);
        return;
      } catch (_) {}
    }
    this.memoryCache.set(key, {
      data: value,
      expiresAt: ttlSeconds ? Date.now() + ttlSeconds * 1000 : null,
    });
  }

  async del(key) {
    if (this.isRedisConnected && this.client) {
      try {
        await this.client.del(key);
      } catch (_) {}
    }
    this.memoryCache.delete(key);
  }

  async flushAll() {
    if (this.isRedisConnected && this.client) {
      try {
        await this.client.flushall();
      } catch (_) {}
    }
    this.memoryCache.clear();
    console.log('🧹 [RedisCache] Flushed all cache keys.');
  }

  /**
   * Express Middleware for automatic route caching
   */
  middleware(ttlSeconds = 60, prefix = 'route') {
    return async (req, res, next) => {
      if (req.method !== 'GET') return next();
      const key = `cache:${prefix}:${req.originalUrl || req.url}`;
      try {
        const cached = await this.get(key);
        if (cached) {
          res.setHeader('X-Cache-Status', 'HIT');
          return res.json(cached);
        }
        res.setHeader('X-Cache-Status', 'MISS');
        const originalJson = res.json.bind(res);
        res.json = (data) => {
          if (res.statusCode >= 200 && res.statusCode < 300) {
            this.set(key, data, ttlSeconds).catch(() => {});
          }
          return originalJson(data);
        };
        next();
      } catch (_) {
        next();
      }
    };
  }
}

module.exports = new RedisCacheService();
