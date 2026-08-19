import {
  Controller,
  Post,
  Body,
  UploadedFile,
  UseInterceptors,
  BadRequestException,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { UploadsService } from './uploads.service';

@Controller('api/v1/uploads')
export class UploadsController {
  constructor(private readonly uploadsService: UploadsService) {}

  @Post('song')
  @UseInterceptors(FileInterceptor('file'))
  async uploadSong(@UploadedFile() file: Express.Multer.File) {
    if (!file) {
      throw new BadRequestException('No audio file provided');
    }

    return this.uploadsService.processAndUploadSong(
      file.buffer,
      file.originalname,
      file.mimetype,
    );
  }

  @Post('avatar')
  @UseInterceptors(FileInterceptor('file'))
  async uploadAvatar(
    @UploadedFile() file: Express.Multer.File,
    @Body('userId') userId?: string,
    @Body('displayName') displayName?: string,
  ) {
    if (!file) {
      throw new BadRequestException('No image file provided');
    }

    return this.uploadsService.uploadUserAvatar(
      file.buffer,
      file.originalname,
      file.mimetype,
      userId,
      displayName,
    );
  }

  @Post('profile')
  async updateProfile(
    @Body('userId') userId: string,
    @Body('displayName') displayName: string,
  ) {
    if (!displayName || !displayName.trim()) {
      throw new BadRequestException('DisplayName is required');
    }

    return this.uploadsService.updateUserProfile(userId, displayName.trim());
  }
}
