import { Injectable, Logger } from '@nestjs/common';
import { google, drive_v3 } from 'googleapis';
import { Readable } from 'stream';
import axios from 'axios';

@Injectable()
export class GoogleDriveService {
  private readonly logger = new Logger(GoogleDriveService.name);
  private driveClient: drive_v3.Drive | null = null;
  private rootFolderId: string;
  private subfoldersCache: Map<string, string> = new Map();

  constructor() {
    this.rootFolderId = process.env.GOOGLE_DRIVE_FOLDER_ID || '1lggxBl5SwcbcFdC83cbPGAxd8hdWpP0O';
    this.initDriveClient();
  }

  private initDriveClient() {
    const clientId = process.env.GOOGLE_CLIENT_ID?.trim();
    const clientSecret = process.env.GOOGLE_CLIENT_SECRET?.trim();
    const redirectUri = process.env.GOOGLE_REDIRECT_URI || 'http://localhost:5001/api/v1/auth/google/callback';
    const refreshToken = process.env.GOOGLE_DRIVE_REFRESH_TOKEN?.trim();

    if (!clientId || !clientSecret) {
      this.logger.warn('Google Drive Client ID or Client Secret not configured.');
      return;
    }

    const oauth2Client = new google.auth.OAuth2(clientId, clientSecret, redirectUri);
    if (refreshToken) {
      oauth2Client.setCredentials({ refresh_token: refreshToken });
    }

    this.driveClient = google.drive({ version: 'v3', auth: oauth2Client });
  }

  getDriveClient(): drive_v3.Drive | null {
    if (!this.driveClient) {
      this.initDriveClient();
    }
    return this.driveClient;
  }

  /**
   * Get or create subfolder inside MUXIZ root folder
   */
  async getOrCreateSubfolder(folderName: string): Promise<string> {
    if (this.subfoldersCache.has(folderName)) {
      return this.subfoldersCache.get(folderName)!;
    }

    const drive = this.getDriveClient();
    if (!drive) return this.rootFolderId;

    try {
      const q = `'${this.rootFolderId}' in parents and (name = '${folderName}' or name = '${folderName.toLowerCase()}') and mimeType = 'application/vnd.google-apps.folder' and trashed = false`;
      const res = await drive.files.list({
        q,
        fields: 'files(id, name)',
        pageSize: 1,
        supportsAllDrives: true,
        includeItemsFromAllDrives: true,
      });

      if (res.data.files && res.data.files.length > 0) {
        const id = res.data.files[0].id!;
        this.subfoldersCache.set(folderName, id);
        return id;
      }

      // Create the folder
      const created = await drive.files.create({
        requestBody: {
          name: folderName,
          mimeType: 'application/vnd.google-apps.folder',
          parents: [this.rootFolderId],
        },
        fields: 'id, name',
        supportsAllDrives: true,
      });

      const newId = created.data.id!;
      this.subfoldersCache.set(folderName, newId);
      return newId;
    } catch (error) {
      this.logger.error(`Error resolving folder ${folderName}: ${(error as Error).message}`);
      return this.rootFolderId;
    }
  }

  /**
   * Upload buffer file to Google Drive folder
   */
  async uploadFile(
    folderName: string,
    fileName: string,
    buffer: Buffer,
    mimeType: string,
  ): Promise<{ fileId: string; webContentLink?: string | null }> {
    const drive = this.getDriveClient();
    if (!drive) {
      throw new Error('Google Drive client is not initialized');
    }

    const folderId = await this.getOrCreateSubfolder(folderName);
    const stream = new Readable();
    stream.push(buffer);
    stream.push(null);

    const res = await drive.files.create({
      requestBody: {
        name: fileName,
        parents: [folderId],
      },
      media: {
        mimeType,
        body: stream,
      },
      fields: 'id, name, mimeType, webContentLink',
      supportsAllDrives: true,
    });

    const fileId = res.data.id!;

    // Make public reader permission so streaming & covers resolve
    try {
      await drive.permissions.create({
        fileId,
        requestBody: { role: 'reader', type: 'anyone' },
        supportsAllDrives: true,
      });
    } catch (e) {
      this.logger.debug(`Permission warning for ${fileId}: ${(e as Error).message}`);
    }

    return { fileId, webContentLink: res.data.webContentLink };
  }

  /**
   * Get direct streaming readable stream with optional range support
   */
  async getStreamStream(fileId: string, rangeHeader?: string): Promise<{
    stream: Readable;
    contentLength?: number;
    contentType?: string;
    contentRange?: string;
    status: number;
  }> {
    const drive = this.getDriveClient();
    if (!drive) {
      // Fallback direct public google drive URL stream via Axios
      const url = `https://drive.google.com/uc?id=${fileId}&export=download`;
      const headers: Record<string, string> = {};
      if (rangeHeader) {
        headers['Range'] = rangeHeader;
      }
      const resp = await axios.get(url, {
        headers,
        responseType: 'stream',
        validateStatus: () => true,
      });

      const clHeader = resp.headers['content-length'];
      const ctHeader = resp.headers['content-type'];
      const crHeader = resp.headers['content-range'];

      return {
        stream: resp.data,
        contentLength: clHeader ? parseInt(String(clHeader), 10) : undefined,
        contentType: ctHeader ? String(ctHeader) : 'audio/mpeg',
        contentRange: crHeader ? String(crHeader) : undefined,
        status: resp.status,
      };
    }

    const headers: Record<string, string> = {};
    if (rangeHeader) {
      headers['Range'] = rangeHeader;
    }

    const response = await drive.files.get(
      {
        fileId,
        alt: 'media',
        supportsAllDrives: true,
      },
      {
        headers,
        responseType: 'stream',
      },
    );

    return {
      stream: response.data as unknown as Readable,
      contentLength: response.headers['content-length'] ? parseInt(response.headers['content-length'], 10) : undefined,
      contentType: response.headers['content-type'] || 'audio/mpeg',
      contentRange: response.headers['content-range'],
      status: rangeHeader ? 206 : 200,
    };
  }

  /**
   * Upload entire song package (audio -> Songs/, cover -> Covers/, details -> Metadata/)
   */
  async uploadSongPackage(params: {
    audioBuffer: Buffer;
    audioName: string;
    audioMime?: string;
    artworkBuffer?: Buffer;
    artworkName?: string;
    artworkMime?: string;
    metadata?: any;
  }) {
    const {
      audioBuffer,
      audioName,
      audioMime = 'audio/mpeg',
      artworkBuffer,
      artworkName,
      artworkMime = 'image/jpeg',
      metadata = {},
    } = params;

    // 1. Upload audio to Songs folder
    const audioRes = await this.uploadFile('Songs', audioName, audioBuffer, audioMime);
    const driveAudioUrl = `https://drive.google.com/uc?id=${audioRes.fileId}&export=download`;

    // 2. Upload artwork to Covers folder if available
    let driveArtworkUrl = metadata.artworkUrl || metadata.artwork || '';
    let artworkFileId: string | undefined;

    if (artworkBuffer) {
      try {
        const artRes = await this.uploadFile('Covers', artworkName || `${metadata.title || 'cover'}.jpg`, artworkBuffer, artworkMime);
        artworkFileId = artRes.fileId;
        driveArtworkUrl = this.getArtworkUrl(artRes.fileId);
      } catch (artErr) {
        this.logger.warn(`Cover upload warning: ${(artErr as Error).message}`);
      }
    }

    // 3. Construct song metadata
    const trackId = metadata.id || `upload_${Date.now()}`;
    const songDetails = {
      id: trackId,
      title: metadata.title || audioName.replace(/\.[^/.]+$/, '') || 'Untitled Track',
      artist: metadata.artist || 'Unknown Artist',
      album: metadata.album || metadata.movieName || 'Single',
      movieName: metadata.movieName || null,
      duration: metadata.duration || 180,
      genre: metadata.genre || 'Music',
      language: metadata.language || 'Tamil',
      audioUrl: driveAudioUrl,
      artworkUrl: driveArtworkUrl,
      lyrics: metadata.lyrics || [],
      gradient: metadata.gradient || ['#1DB954', '#0B0C10'],
      audioFileId: audioRes.fileId,
      artworkFileId,
      dateAdded: new Date().toISOString(),
    };

    // 4. Save metadata JSON to Metadata folder
    try {
      const jsonBuffer = Buffer.from(JSON.stringify(songDetails, null, 2), 'utf-8');
      await this.uploadFile('Metadata', `${trackId}.json`, jsonBuffer, 'application/json');
    } catch (_) {}

    return songDetails;
  }

  /**
   * Delete a file from Google Drive by File ID
   */
  async deleteFile(fileId: string): Promise<boolean> {
    if (!fileId) return false;
    const drive = this.getDriveClient();
    if (!drive) {
      this.logger.warn(`Cannot delete file ${fileId}: Google Drive client not initialized`);
      return false;
    }

    try {
      await drive.files.delete({
        fileId,
        supportsAllDrives: true,
      });
      this.logger.log(`🗑️ Successfully deleted file ${fileId} from Google Drive`);
      return true;
    } catch (err: any) {
      // If file already deleted or not found, treat as success
      if (err?.code === 404 || err?.status === 404) {
        this.logger.log(`File ${fileId} was already removed from Google Drive`);
        return true;
      }
      this.logger.error(`Error deleting Google Drive file ${fileId}: ${err?.message || err}`);
      return false;
    }
  }

  /**
   * Delete a file from Google Drive by folder name and file name
   */
  async deleteFileByName(folderName: string, fileName: string): Promise<boolean> {
    const drive = this.getDriveClient();
    if (!drive) return false;

    try {
      const folderId = await this.getOrCreateSubfolder(folderName);
      const q = `'${folderId}' in parents and name = '${fileName.replace(/'/g, "\\'")}' and trashed = false`;
      const res = await drive.files.list({
        q,
        fields: 'files(id, name)',
        pageSize: 10,
        supportsAllDrives: true,
        includeItemsFromAllDrives: true,
      });

      if (res.data.files && res.data.files.length > 0) {
        for (const file of res.data.files) {
          if (file.id) {
            await this.deleteFile(file.id);
          }
        }
        return true;
      }
      return false;
    } catch (err: any) {
      this.logger.warn(`Could not delete file ${fileName} in ${folderName}: ${err?.message || err}`);
      return false;
    }
  }

  /**
   * Get artwork preview URL
   */
  getArtworkUrl(fileId: string): string {
    return `https://lh3.googleusercontent.com/d/${fileId}`;
  }
}
