# 🎛️ Muxiz Studio — Next.js & React Music Management Engine

A high-performance, full-stack **Next.js 15 & React 19** music management application for Muxiz. Features instant Apple Music metadata & HD artwork auto-extraction, smart Tamil Genre & Mood classification, in-browser audio preview, Google Drive audio streaming, and direct PostgreSQL database synchronization via Prisma.

---

## 📁 Architecture

```text
flutter-muxiz/
├── mobile/         # Flutter iOS & Android Mobile Application
├── backend/        # NestJS API Backend (Streaming, Recommendation & Auth Services)
└── studio/         # 🎛️ Next.js + React Standalone Studio Engine
    ├── app/
    │   ├── layout.jsx            # HTML root & Inter font
    │   ├── page.jsx              # Main Studio React Dashboard
    │   ├── globals.css           # Modern Design System (Inter, Glassmorphism)
    │   └── api/                  # Next.js Server Route Handlers
    │       ├── health/           # PostgreSQL DB & Cloud Health
    │       ├── songs/            # GET/PUT/DELETE Songs
    │       ├── artists/          # GET/PUT/DELETE Artists & Discographies
    │       └── uploads/          # Google Drive Audio & Image Uploads
    ├── components/
    │   ├── Sidebar.jsx           # Clean navigation & metrics
    │   ├── IngestQueue.jsx       # Drag-and-drop, Apple Music fetcher & audio previews
    │   ├── CatalogTable.jsx      # Interactive data table with play icons & search
    │   ├── ArtistsHub.jsx        # Artist discography & custom photo upload
    │   ├── AudioPlayerBar.jsx    # Persistent bottom player bar with seek slider
    │   └── EditSongModal.jsx     # Song metadata editor modal
    ├── lib/
    │   ├── prisma.js             # Singleton PostgreSQL Prisma Client
    │   ├── gdrive.js             # Google Drive OAuth2 Client & Streams
    │   └── metadata.js           # Smart Genre & Mood classifier
    ├── prisma/
    │   └── schema.prisma         # PostgreSQL Schema
    ├── package.json              # Next.js 15, React 19, Lucide Icons, Prisma
    └── next.config.mjs
```

---

## 🚀 Running Studio Standalone

### 1. Install & Generate Prisma:
```bash
cd studio
npm install
npx prisma generate
```

### 2. Development Mode:
```bash
npm run dev
```
Studio will run at:
- **Local URL**: [http://localhost:5001](http://localhost:5001) (or `http://localhost:3000`)
- **Network URL**: `http://192.168.1.94:5001`

### 3. Production Build & Start:
```bash
npm run build
npm start
```

---

## 🌟 Key Capabilities

- 📥 **Batch Audio Ingestion**: Drop audio files (`.mp3`, `.m4a`, `.wav`, `.flac`) for zero-click metadata extraction and Apple Music 600x600 HD artwork retrieval.
- 🎭 **Smart Genre & Mood Classifier**: Classifies tracks into 8 categories (Melody / Romantic, Dance / Kuthu, Mass / Energetic, Soulful / Sad, Chill / Lo-Fi, Folk / Gaana, Hip-Hop / Rap, Classical / Devotional).
- 🎵 **In-Browser & Persistent Audio Player**: Play queued local audio files before uploading, or stream live PostgreSQL songs with real-time waveform seek and volume controls.
- ☁️ **Google Drive Direct Cloud Ingestion**: Streams audio directly to Google Drive folders with public streaming URLs.
- 🗄️ **PostgreSQL Live Catalog Sync**: Automatic creation and updating of songs, artists, and album relationships.
