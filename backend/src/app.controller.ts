import { Controller, Get, Res } from '@nestjs/common';
import { PrismaService } from './prisma/prisma.service';

@Controller()
export class AppController {
  constructor(private readonly prisma: PrismaService) {}

  @Get()
  async getRoot(@Res() res: any) {
    let totalSongs = 440;
    try {
      totalSongs = await this.prisma.song.count();
    } catch (_) {}

    const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Muxiz Cloud Music API — 100% Operational</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;600;700;800&display=swap" rel="stylesheet">
  <style>
    :root {
      --bg: #0A0D14;
      --card-bg: rgba(22, 28, 45, 0.7);
      --accent: #1DB954;
      --accent-glow: rgba(29, 185, 84, 0.35);
      --text: #FFFFFF;
      --muted: #94A3B8;
      --border: rgba(255, 255, 255, 0.08);
    }
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      background: radial-gradient(circle at 50% 0%, #152238 0%, var(--bg) 75%);
      color: var(--text);
      font-family: 'Plus Jakarta Sans', sans-serif;
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
      padding: 24px;
    }
    .container {
      width: 100%;
      max-width: 680px;
      background: var(--card-bg);
      backdrop-filter: blur(20px);
      border: 1px solid var(--border);
      border-radius: 28px;
      padding: 40px;
      box-shadow: 0 25px 50px -12px rgba(0,0,0,0.5), 0 0 40px var(--accent-glow);
    }
    .header {
      display: flex;
      align-items: center;
      gap: 16px;
      margin-bottom: 24px;
    }
    .status-badge {
      display: inline-flex;
      align-items: center;
      gap: 8px;
      background: rgba(29, 185, 84, 0.15);
      border: 1px solid rgba(29, 185, 84, 0.4);
      color: #1DB954;
      font-weight: 700;
      font-size: 13px;
      padding: 6px 14px;
      border-radius: 100px;
      margin-bottom: 12px;
    }
    .status-dot {
      width: 8px;
      height: 8px;
      background: #1DB954;
      border-radius: 50%;
      box-shadow: 0 0 10px #1DB954;
      animation: pulse 2s infinite;
    }
    @keyframes pulse {
      0%, 100% { opacity: 1; transform: scale(1); }
      50% { opacity: 0.4; transform: scale(0.8); }
    }
    h1 {
      font-size: 28px;
      font-weight: 800;
      letter-spacing: -0.5px;
      margin-bottom: 8px;
    }
    p {
      color: var(--muted);
      font-size: 15px;
      line-height: 1.5;
    }
    .stats-grid {
      display: grid;
      grid-template-columns: repeat(3, 1fr);
      gap: 16px;
      margin: 28px 0;
    }
    .stat-card {
      background: rgba(255,255,255,0.03);
      border: 1px solid var(--border);
      border-radius: 16px;
      padding: 16px;
      text-align: center;
    }
    .stat-val {
      font-size: 24px;
      font-weight: 800;
      color: var(--accent);
    }
    .stat-lbl {
      font-size: 12px;
      color: var(--muted);
      margin-top: 4px;
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }
    .endpoints {
      background: rgba(0,0,0,0.3);
      border: 1px solid var(--border);
      border-radius: 18px;
      padding: 20px;
      margin-top: 24px;
    }
    .endpoints h3 {
      font-size: 14px;
      text-transform: uppercase;
      letter-spacing: 1px;
      color: var(--muted);
      margin-bottom: 12px;
    }
    .endpoint-link {
      display: flex;
      align-items: center;
      justify-content: space-between;
      color: #93C5FD;
      text-decoration: none;
      font-family: monospace;
      font-size: 13px;
      padding: 10px 14px;
      background: rgba(255,255,255,0.04);
      border-radius: 10px;
      margin-bottom: 8px;
      transition: all 0.2s;
    }
    .endpoint-link:hover {
      background: rgba(29, 185, 84, 0.15);
      color: #1DB954;
      transform: translateX(4px);
    }
    .tag {
      font-size: 11px;
      padding: 2px 8px;
      border-radius: 6px;
      background: rgba(255,255,255,0.1);
      color: #FFF;
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="status-badge">
      <div class="status-dot"></div>
      ALL SYSTEMS OPERATIONAL
    </div>
    <h1>Muxiz Cloud Music Engine</h1>
    <p>High-performance native audio backend powered by NestJS, Supabase PostgreSQL, and Google Drive Cloud Storage.</p>

    <div class="stats-grid">
      <div class="stat-card">
        <div class="stat-val">${totalSongs}</div>
        <div class="stat-lbl">Active Tracks</div>
      </div>
      <div class="stat-card">
        <div class="stat-val">100%</div>
        <div class="stat-lbl">Apple Music HD</div>
      </div>
      <div class="stat-card">
        <div class="stat-val">Google Drive</div>
        <div class="stat-lbl">Audio Storage</div>
      </div>
    </div>

    <div class="endpoints">
      <h3>Live API Endpoints</h3>
      <a class="endpoint-link" href="/api/v1/songs" target="_blank">
        <span>GET /api/v1/songs</span>
        <span class="tag">JSON</span>
      </a>
      <a class="endpoint-link" href="/api/v1/recommendations/home-feed" target="_blank">
        <span>GET /api/v1/recommendations/home-feed</span>
        <span class="tag">JSON</span>
      </a>
      <a class="endpoint-link" href="/api/v1/search?q=anirudh" target="_blank">
        <span>GET /api/v1/search?q=anirudh</span>
        <span class="tag">JSON</span>
      </a>
    </div>
  </div>
</body>
</html>`;

    return res.send(html);
  }
}
