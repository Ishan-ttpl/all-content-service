import { NestFactory } from '@nestjs/core';
import {
  FastifyAdapter,
  NestFastifyApplication,
} from '@nestjs/platform-fastify';
import { AppModule } from './app.module';
import { ValidationPipe } from '@nestjs/common';
import { SwaggerModule, DocumentBuilder } from '@nestjs/swagger';
import { AppClusterService } from './app-cluster.service';
import compression from '@fastify/compress';

async function bootstrap() {
  const app = await NestFactory.create<NestFastifyApplication>(
    AppModule,
    new FastifyAdapter(),
  );

  await app.register(compression,{
    global: true,
    zlibOptions: {
      level: 6,
    },
    threshold: 512,
    encodings: ['gzip', 'deflate']
  });

  app.useGlobalPipes(new ValidationPipe());
  app.setGlobalPrefix('v1');
  app.enableCors({
    origin: ['*'],
    methods: ['GET', 'POST', 'HEAD', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    credentials: false,
  });

  const config = new DocumentBuilder()
    .setTitle('ALL Content Service')
    .setDescription(
      'All content service includes Storys , word, sentences texts to practice',
    )
    .setVersion('v1')
    .addServer(process.env.SERVER_URL, 'ALL Content Service Server APIs')
    .build();

  const document = SwaggerModule.createDocument(app, config);
  SwaggerModule.setup('api', app, document);

  await app.listen(3008, '0.0.0.0');
}
AppClusterService.clusterize(bootstrap);