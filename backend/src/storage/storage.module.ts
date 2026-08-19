import { Global, Module, forwardRef } from '@nestjs/common';
import { GoogleDriveService } from './google-drive/google-drive.service';
import { StorageController } from './storage.controller';
import { SongsModule } from '../songs/songs.module';

@Global()
@Module({
  imports: [forwardRef(() => SongsModule)],
  controllers: [StorageController],
  providers: [GoogleDriveService],
  exports: [GoogleDriveService],
})
export class StorageModule {}
