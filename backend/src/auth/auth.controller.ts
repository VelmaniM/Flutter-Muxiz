import { Controller, Post, Body, Get, UseGuards, Req, Query, Res, Headers } from '@nestjs/common';
import { AuthService } from './auth.service';
import { JwtAuthGuard } from './jwt-auth.guard';
import { google } from 'googleapis';
import * as fs from 'fs';
import * as path from 'path';

@Controller('api/v1/auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('register')
  async register(@Body() body: { email: string; password?: string; displayName?: string }) {
    return this.authService.register(body);
  }

  @Post('login')
  async login(@Body() body: { email: string; password?: string }) {
    return this.authService.login(body);
  }

  @Post('google')
  async googleAuth(@Body() body: { email: string; displayName?: string; photoURL?: string }) {
    return this.authService.googleAuth(body);
  }

  @Post('guest')
  async guestAuth(@Body() body: { deviceId?: string }) {
    return this.authService.guestAuth(body.deviceId);
  }

  @Get('verify')
  async verify(@Headers('authorization') authHeader?: string) {
    const token = authHeader ? authHeader.replace('Bearer ', '') : '';
    return this.authService.verifyToken(token);
  }

  @Get('google/login')
  @Get('google/drive')
  async googleDriveLogin(@Res() res: any) {
    const clientId = process.env.GOOGLE_CLIENT_ID || '';
    const clientSecret = process.env.GOOGLE_CLIENT_SECRET || '';
    const redirectUri = process.env.GOOGLE_REDIRECT_URI || 'http://localhost:5001/api/v1/auth/google/callback';

    const oauth2Client = new google.auth.OAuth2(clientId, clientSecret, redirectUri);
    const authUrl = oauth2Client.generateAuthUrl({
      access_type: 'offline',
      prompt: 'consent',
      scope: [
        'https://www.googleapis.com/auth/drive',
        'https://www.googleapis.com/auth/drive.file',
        'https://www.googleapis.com/auth/drive.appdata',
      ],
    });

    return res.redirect(authUrl);
  }

  @Get('google/callback')
  async googleCallback(@Query('code') code: string, @Res() res: any) {
    if (!code) {
      return this.googleDriveLogin(res);
    }
    try {
      const clientId = process.env.GOOGLE_CLIENT_ID || '';
      const clientSecret = process.env.GOOGLE_CLIENT_SECRET || '';
      const redirectUri = process.env.GOOGLE_REDIRECT_URI || 'http://localhost:5001/api/v1/auth/google/callback';

      const oauth2Client = new google.auth.OAuth2(clientId, clientSecret, redirectUri);
      const { tokens } = await oauth2Client.getToken(code);

      if (tokens.refresh_token) {
        const envPath = path.resolve(process.cwd(), '.env');
        if (fs.existsSync(envPath)) {
          let envContent = fs.readFileSync(envPath, 'utf8');
          if (envContent.includes('GOOGLE_DRIVE_REFRESH_TOKEN=')) {
            envContent = envContent.replace(/GOOGLE_DRIVE_REFRESH_TOKEN=.*/g, `GOOGLE_DRIVE_REFRESH_TOKEN=${tokens.refresh_token}`);
          } else {
            envContent += `\nGOOGLE_DRIVE_REFRESH_TOKEN=${tokens.refresh_token}\n`;
          }
          fs.writeFileSync(envPath, envContent, 'utf8');
        }
        process.env.GOOGLE_DRIVE_REFRESH_TOKEN = tokens.refresh_token;
      }

      return res.send(`<html><body style="font-family:system-ui,-apple-system,sans-serif;background:#0B0C10;color:#1DB954;padding:60px 20px;text-align:center;"><div style="background:#181818;max-width:480px;margin:0 auto;padding:40px;border-radius:20px;border:1px solid #1DB954;"><h2>✅ Google Drive Connected Successfully!</h2><p style="color:#FFF;font-size:16px;">Refresh token has been automatically saved to backend .env!</p><p style="color:#888;font-size:14px;margin-top:20px;">You can close this tab and start uploading songs.</p></div></body></html>`);
    } catch (e: any) {
      return res.send(`<html><body style="font-family:system-ui,-apple-system,sans-serif;background:#0B0C10;color:#ff5555;padding:60px 20px;text-align:center;"><div style="background:#181818;max-width:480px;margin:0 auto;padding:40px;border-radius:20px;border:1px solid #ff5555;"><h2>❌ Authorization Failed</h2><p style="color:#FFF;">${e.message}</p></div></body></html>`);
    }
  }

  @UseGuards(JwtAuthGuard)
  @Get('me')
  async getProfile(@Req() req: any) {
    return req.user;
  }
}
