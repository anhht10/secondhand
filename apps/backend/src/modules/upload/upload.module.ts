import { Module } from '@nestjs/common';
import { STORAGE_PROVIDER_TOKEN } from '../../common/interfaces/storage-provider.interface';
import { LocalStorageProvider } from './providers/local-storage.provider';
import { UploadController } from './upload.controller';
import { UploadService } from './upload.service';

@Module({
  controllers: [UploadController],
  providers: [
    LocalStorageProvider,
    {
      provide: STORAGE_PROVIDER_TOKEN,
      useExisting: LocalStorageProvider,
    },
    UploadService,
  ],
  exports: [UploadService, STORAGE_PROVIDER_TOKEN],
})
export class UploadModule {}
