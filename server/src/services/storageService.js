const fs = require('fs');
const path = require('path');
const { getOAuth2Client, getAccessToken, getDriveClient, FOLDER_ID } = require('../config/googleDrive');

// Ensure vault storage folder exists
const vaultDir = path.join(__dirname, '../../data/vault');
if (!fs.existsSync(vaultDir)) {
  fs.mkdirSync(vaultDir, { recursive: true });
}

class StorageService {
  /**
   * Generates a direct upload URL
   * Tries Google Drive Resumable Session; seamlessly falls back to High-Speed Local Media Vault
   */
  static async createResumableSession(fileName, mimeType = 'audio/mpeg') {
    try {
      const accessToken = await getAccessToken();

      if (!accessToken) {
        throw new Error('OAuth token unavailable');
      }

      const metadata = {
        name: fileName,
        parents: FOLDER_ID ? [FOLDER_ID] : [],
        mimeType: mimeType,
      };

      const gRes = await fetch(
        'https://www.googleapis.com/upload/drive/v3/files?uploadType=resumable',
        {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${accessToken}`,
            'Content-Type': 'application/json; charset=UTF-8',
            'X-Upload-Content-Type': mimeType,
          },
          body: JSON.stringify(metadata),
        }
      );

      const uploadUrl = gRes.headers.get('location');
      if (uploadUrl) {
        return {
          success: true,
          uploadUrl,
          provider: 'GOOGLE_DRIVE',
          expiresIn: 3600,
        };
      }
      throw new Error(`Google Drive API error: ${gRes.status}`);
    } catch (error) {
      console.warn('⚠️ [StorageService] Google Drive OAuth unavailable, routing to High-Speed Local Media Vault:', error.message);
      const safeId = 'vlt_' + Date.now() + '_' + Math.random().toString(36).substring(2, 7);
      return {
        success: true,
        uploadUrl: `/api/v1/uploads/direct?fileId=${safeId}&fileName=${encodeURIComponent(fileName)}`,
        provider: 'LOCAL_VAULT',
        fileId: safeId,
      };
    }
  }

  /**
   * Handles direct upload stream to Local Media Vault
   */
  static async saveDirectUploadStream(fileId, req) {
    return new Promise((resolve, reject) => {
      const filePath = path.join(vaultDir, `${fileId}.mp3`);
      const writeStream = fs.createWriteStream(filePath);

      req.pipe(writeStream);

      writeStream.on('finish', () => {
        resolve({
          fileId,
          filePath,
          directStreamUrl: `/api/v1/songs/stream/${fileId}`,
        });
      });

      writeStream.on('error', (err) => {
        reject(err);
      });
    });
  }

  static async uploadToGoogleDriveBackground(fileId, filePath, fileName) {
    try {
      const { getDriveClient, FOLDER_ID } = require('../config/googleDrive');
      const drive = getDriveClient();
      if (!fs.existsSync(filePath)) return;

      const fileMetadata = {
        name: fileName || `${fileId}.mp3`,
        parents: FOLDER_ID ? [FOLDER_ID] : [],
      };
      const media = {
        mimeType: 'audio/mpeg',
        body: fs.createReadStream(filePath),
      };

      const driveFile = await drive.files.create({
        requestBody: fileMetadata,
        media: media,
        fields: 'id, name',
      });
      console.log(`☁️ [GoogleDrive] Uploaded file "${fileName}" (ID: ${driveFile.data?.id}) to Google Drive`);
      return driveFile.data?.id;
    } catch (err) {
      console.warn('⚠️ [GoogleDrive Background Upload Notice]', err.message);
    }
  }

  /**
   * Sets public read permission on uploaded Google Drive file
   */
  static async makePublicStreamable(fileId) {
    if (!fileId || fileId.startsWith('vlt_')) {
      return `/api/v1/songs/stream/${fileId}`;
    }
    try {
      const drive = getDriveClient();
      await drive.permissions.create({
        fileId: fileId,
        requestBody: {
          role: 'reader',
          type: 'anyone',
        },
      });
      return `https://drive.google.com/uc?id=${fileId}&export=download`;
    } catch (error) {
      return `https://drive.google.com/uc?id=${fileId}&export=download`;
    }
  }

  /**
   * Stream audio file directly with Range header support for seeking (0ms latency)
   */
  static async streamAudioFile(fileId, req, res) {
    try {
      // 1. Check if file is stored in Local Media Vault
      const localFilePath = path.join(vaultDir, `${fileId}.mp3`);
      const altLocalPath = path.join(vaultDir, fileId);

      const targetPath = fs.existsSync(localFilePath) ? localFilePath : (fs.existsSync(altLocalPath) ? altLocalPath : null);

      if (targetPath) {
        const stat = fs.statSync(targetPath);
        const fileSize = stat.size;
        const range = req.headers.range;

        if (range) {
          const parts = range.replace(/bytes=/, '').split('-');
          const start = parseInt(parts[0], 10);
          const end = parts[1] ? parseInt(parts[1], 10) : fileSize - 1;
          const chunksize = end - start + 1;
          const file = fs.createReadStream(targetPath, { start, end });
          const head = {
            'Content-Range': `bytes ${start}-${end}/${fileSize}`,
            'Accept-Ranges': 'bytes',
            'Content-Length': chunksize,
            'Content-Type': 'audio/mpeg',
          };
          res.writeHead(206, head);
          file.pipe(res);
          return;
        } else {
          const head = {
            'Content-Length': fileSize,
            'Content-Type': 'audio/mpeg',
            'Accept-Ranges': 'bytes',
          };
          res.writeHead(200, head);
          fs.createReadStream(targetPath).pipe(res);
          return;
        }
      }

      // 2. Fetch from Google Drive API
      const drive = getDriveClient();
      const range = req.headers.range;

      const driveRes = await drive.files.get(
        { fileId, alt: 'media' },
        {
          responseType: 'stream',
          headers: range ? { Range: range } : {},
        }
      );

      res.setHeader('Content-Type', driveRes.headers['content-type'] || 'audio/mpeg');
      res.setHeader('Accept-Ranges', 'bytes');
      if (driveRes.headers['content-range']) {
        res.setHeader('Content-Range', driveRes.headers['content-range']);
        res.status(206);
      }
      if (driveRes.headers['content-length']) {
        res.setHeader('Content-Length', driveRes.headers['content-length']);
      }

      driveRes.data.pipe(res);
    } catch (error) {
      console.warn('[StorageService streamAudioFile Fallback]', error.message);
      res.redirect(`https://drive.google.com/uc?id=${fileId}&export=download`);
    }
  }
}

module.exports = StorageService;
