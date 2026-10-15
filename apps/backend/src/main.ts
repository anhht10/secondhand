import { Logger, ValidationPipe } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { NestFactory } from '@nestjs/core';
import { NestExpressApplication } from '@nestjs/platform-express';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import helmet from 'helmet';
import * as path from 'path';
import { AppModule } from './app.module';

async function bootstrap(): Promise<void> {
  const logger = new Logger('Bootstrap');
  const app = await NestFactory.create<NestExpressApplication>(AppModule);

  const configService = app.get(ConfigService);
  const port = configService.get<number>('port') ?? 5000;
  const apiPrefix = configService.get<string>('apiPrefix') ?? 'api/v1';
  const corsOrigin = configService.get<string>('corsOrigin') ?? '*';

  // Security headers (allow cross-origin resource loading for uploaded product images)
  app.use(
    helmet({
      crossOriginResourcePolicy: { policy: 'cross-origin' },
    }),
  );

  // Serve local development uploaded images under /uploads
  app.useStaticAssets(path.join(process.cwd(), 'uploads'), {
    prefix: '/uploads/',
  });

  // CORS configuration for Flutter mobile & web clients
  app.enableCors({
    origin:
      corsOrigin === '*' ? true : corsOrigin.split(',').map((o) => o.trim()),
    methods: ['GET', 'HEAD', 'PUT', 'PATCH', 'POST', 'DELETE', 'OPTIONS'],
    credentials: true,
  });

  // Global API version prefix (/api/v1)
  app.setGlobalPrefix(apiPrefix);

  // Global DTO validation pipe
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
      transformOptions: {
        enableImplicitConversion: false,
      },
    }),
  );

  // Swagger / OpenAPI documentation at /api/docs
  const swaggerConfig = new DocumentBuilder()
    .setTitle('ReMarket API')
    .setDescription(
      'ReMarket Second-Hand Marketplace — Production-Ready Backend REST API (Authentication, Wishlist, Users, Categories, Products, Upload, Messaging, Reports, Health)',
    )
    .setVersion('1.0.0')
    .addServer(`http://localhost:${port}`, 'Local Development Server')
    .addBearerAuth(
      {
        type: 'http',
        scheme: 'bearer',
        bearerFormat: 'JWT',
        description:
          'Provide the JWT accessToken issued by /api/v1/auth/login or /api/v1/auth/register',
      },
      'bearer',
    )
    .build();

  const document = SwaggerModule.createDocument(app, swaggerConfig);
  SwaggerModule.setup('api/docs', app, document, {
    swaggerOptions: {
      persistAuthorization: true,
    },
  });

  await app.listen(port);
  logger.log(
    `ReMarket Backend running on http://localhost:${port}/${apiPrefix}`,
  );
  logger.log(
    `Swagger OpenAPI Docs available at http://localhost:${port}/api/docs`,
  );
}

void bootstrap();
