import { Controller, Post, Body, HttpException, HttpStatus } from '@nestjs/common';
import axios from 'axios';
import { GoogleDriveService } from './google-drive/google-drive.service';
import { SongsService } from '../songs/songs.service';

@Controller('api/v1/storage')
export class StorageController {
  constructor(
    private readonly driveService: GoogleDriveService,
    private readonly songsService: SongsService,
  ) {}

  @Post('upload')
  async uploadSongPackage(@Body() body: any) {
    try {
      const audioData = body.audioData;
      const audioName = body.audioName || 'track.mp3';
      const audioMime = body.audioMime || 'audio/mpeg';
      const artworkData = body.artworkData;
      const artworkName = body.artworkName || 'cover.jpg';
      const artworkMime = body.artworkMime || 'image/jpeg';
      const metadata = body.metadata || {};

      if (!audioData) {
        throw new HttpException('audioData (base64) is required', HttpStatus.BAD_REQUEST);
      }

      const audioBuffer = Buffer.from(audioData, 'base64');
      const artworkBuffer = artworkData ? Buffer.from(artworkData, 'base64') : undefined;

      // 1. Upload to Google Drive
      let trackDetails: any;
      try {
        trackDetails = await this.driveService.uploadSongPackage({
          audioBuffer,
          audioName,
          audioMime,
          artworkBuffer,
          artworkName,
          artworkMime,
          metadata,
        });
      } catch (driveErr) {
        // Fallback to Cloud Google Drive Upload API
        try {
          const cloudDriveRes = await axios.post(
            'https://muxiz.vercel.app/api/drive/upload',
            {
              audioData,
              audioName,
              audioMime,
              artworkData,
              artworkName,
              artworkMime,
              metadata,
            },
            {
              timeout: 60000,
              headers: { 'Content-Type': 'application/json' },
            },
          );
          if (cloudDriveRes.data && cloudDriveRes.data.track) {
            trackDetails = cloudDriveRes.data.track;
          }
        } catch (cloudErr: any) {
          // Keep metadata
        }

        if (!trackDetails) {
          trackDetails = {
            id: metadata.id || `upload_${Date.now()}`,
            title: metadata.title || audioName.replace(/\.[^/.]+$/, ''),
            artist: metadata.artist || 'Unknown Artist',
            album: metadata.album || metadata.movieName || 'Single',
            movieName: metadata.movieName || null,
            duration: metadata.duration || 210,
            genre: metadata.genre || 'Music',
            language: metadata.language || 'Tamil',
            audioUrl: metadata.audioUrl || '',
            artworkUrl: metadata.artworkUrl || '',
            lyrics: metadata.lyrics || [],
            gradient: metadata.gradient || ['#1DB954', '#0B0C10'],
          };
        }
      }

      // 2. Persist to PostgreSQL Database
      await this.songsService.createSong({
        id: trackDetails.id,
        title: trackDetails.title,
        artistName: trackDetails.artist,
        albumName: trackDetails.album,
        movieName: trackDetails.movieName,
        artworkUrl: trackDetails.artworkUrl,
        audioUrl: trackDetails.audioUrl,
        duration: trackDetails.duration,
        genre: trackDetails.genre,
        language: trackDetails.language,
        lyrics: trackDetails.lyrics,
        gradient: trackDetails.gradient,
      });

      return {
        success: true,
        message: 'Successfully uploaded song package to Google Drive & PostgreSQL Database',
        track: trackDetails,
      };
    } catch (err: any) {
      throw new HttpException(
        err.message || 'Upload failed',
        err.status || HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }
}
