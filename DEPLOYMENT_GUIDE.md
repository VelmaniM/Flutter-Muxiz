# 🚀 Muxiz Music — 24/7 100% Free Cloud Deployment Guide

Mac-ஐ ஆஃப் செய்தாலும் **24/7 நேரலையாக பாடல்கள் Database-ல் ஏறவும்**, உலகத்தில் எங்கிருந்தும் Phone-லிருந்து பாடல்களை Upload செய்யவும் இந்த 3 எளிய படிகளை பின்பற்றுங்கள்:

---

## 📌 படி 1: Free Cloud PostgreSQL Database உருவாக்குதல் (Supabase)

1. [https://supabase.com](https://supabase.com) சென்று **Sign Up / Sign In with GitHub** செய்யுங்கள் (100% இலவசம்).
2. **"New Project"** கிளிக் செய்து:
   - Project Name: `muxiz-db`
   - Database Password: ஒரு வலுவான பாஸ்வர்டு உள்ளிடவும் (எ.கா: `MuxizMusic2026!`).
   - Region: `Singapore (ap-southeast-1)` அல்லது `India (ap-south-1)` தேர்ந்தெடுக்கவும்.
3. Project உருவானதும், **Project Settings -> Database -> Connection string -> URI** (Transaction Pooler or Direct) காப்பி செய்யுங்கள்:
   ```env
   DATABASE_URL="postgresql://postgres:[YOUR-PASSWORD]@db.xxxx.supabase.co:5432/postgres?schema=public"
   ```

---

## 📌 படி 2: Free 24/7 Backend Deploy செய்தல் (Render.com)

1. [https://render.com](https://render.com) சென்று **Sign In with GitHub** செய்யுங்கள்.
2. **"New +" -> "Web Service"** கிளிக் செய்யுங்கள்.
3. உங்கள் `flutter-muxiz` GitHub Repository-ஐ தேர்வு செய்யுங்கள்.
4. பின்வரும் அமைப்புகளை உள்ளிடவும்:
   - **Name**: `muxiz-backend`
   - **Region**: `Singapore`
   - **Root Directory**: `backend`
   - **Runtime**: `Node` (அல்லது `Docker`)
   - **Build Command**: `npm install && npx prisma generate && npm run build`
   - **Start Command**: `npm run start:prod`
   - **Instance Type**: `Free` ($0/month)

5. **"Environment Variables"** பகுதியில் கீழே உள்ளவற்றை Add செய்யுங்கள்:
   ```env
   NODE_ENV=production
   PORT=5001
   JWT_SECRET=muxiz_super_secret_jwt_key_2026_production
   JWT_EXPIRES_IN=30d
   DATABASE_URL=[YOUR_SUPABASE_DATABASE_URL]
   DIRECT_URL=[YOUR_SUPABASE_DIRECT_URL]
   GOOGLE_CLIENT_ID=[YOUR_GOOGLE_CLIENT_ID]
   GOOGLE_CLIENT_SECRET=[YOUR_GOOGLE_CLIENT_SECRET]
   GOOGLE_REDIRECT_URI=https://muxiz-backend.onrender.com/api/v1/auth/google/callback
   GOOGLE_DRIVE_FOLDER_ID=[YOUR_GOOGLE_DRIVE_FOLDER_ID]
   GOOGLE_DRIVE_REFRESH_TOKEN=[YOUR_GOOGLE_DRIVE_REFRESH_TOKEN]
   CLOUDINARY_CLOUD_NAME=[YOUR_CLOUDINARY_CLOUD_NAME]
   CLOUDINARY_API_KEY=[YOUR_CLOUDINARY_API_KEY]
   CLOUDINARY_API_SECRET=[YOUR_CLOUDINARY_API_SECRET]
   CLOUDINARY_UPLOAD_PRESET=[YOUR_CLOUDINARY_UPLOAD_PRESET]
   GEMINI_API_KEY=[YOUR_GEMINI_API_KEY]
   ```

6. **"Deploy Web Service"** கிளிக் செய்யுங்கள். 2 நிமிடங்களில் உங்கள் நேரலை Backend URL கிடைக்கும்:
   👉 `https://muxiz-backend.onrender.com`

---

## 📌 படி 3: Cloud Database-ல் 56 பாடல்களை Sync செய்தல்

Render-ல் Deploy ஆனதும், உங்கள் Mac Terminal-லிருந்து ஒரே ஒரு முறை Supabase Database-க்கு பாடல்களை ஏற்றிவிடலாம்:

```bash
cd backend
DATABASE_URL="[YOUR-SUPABASE-URL]" npx prisma db push
DATABASE_URL="[YOUR-SUPABASE-URL]" npm run seed:catalog
```

---

## 📌 படி 4: Mobile App-ல் Live Render URL இணைத்தல்

Render Backend URL கிடைத்தவுடன், `mobile/lib/app/constants.dart`-ல்:
```dart
static const String envApiUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://muxiz-backend.onrender.com/api/v1',
);
```
என்று மாற்றிய பிறகு `make build-apk` கொடுத்தால், உங்கள் App வாழ்நாள் முழுவதும் 24/7 Cloud-ல் எந்த Mac-உம் இல்லாமல் நேரலையாக இயங்கும்!
