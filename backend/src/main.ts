import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { Logger, ValidationPipe } from '@nestjs/common';

import { json, urlencoded } from 'express';

async function bootstrap() {
  const logger = new Logger('MuxizBootstrap');
  const app = await NestFactory.create(AppModule);

  // Increase payload limit for audio files (150MB)
  app.use(json({ limit: '150mb' }));
  app.use(urlencoded({ limit: '150mb', extended: true }));

  // Enable CORS for Flutter mobile, web, and local clients
  app.enableCors({
    origin: '*',
    methods: 'GET,HEAD,PUT,PATCH,POST,DELETE,OPTIONS',
    credentials: true,
  });

  // Enable automatic validation
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      transform: true,
      forbidNonWhitelisted: false,
    }),
  );

  const port = process.env.PORT || 5001;
  await app.listen(port, '0.0.0.0');

  logger.log(`🚀 Muxiz Music Backend running on: http://localhost:${port}`);
  logger.log(`🎵 API Base URL: http://localhost:${port}/api/v1`);
}

bootstrap();
