import { Module } from '@nestjs/common';
import { ProductsModule } from '../products/products.module';
import { AiHttpClient } from './ai-http.client';
import { AiController } from './ai.controller';
import { AiService } from './ai.service';

@Module({
  imports: [ProductsModule],
  controllers: [AiController],
  providers: [AiHttpClient, AiService],
  exports: [AiHttpClient, AiService],
})
export class AiModule {}
