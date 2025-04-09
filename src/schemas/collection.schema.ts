import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document, now } from 'mongoose';
import { v4 as uuidv4 } from 'uuid';
import { IsOptional, IsString } from 'class-validator';

@Schema({ collection: 'collection' })
export class collection {
  @Prop({ default: uuidv4, index: true })
  collectionId: string;

  @Prop({ type: String, required: true })
  @IsString()
  name: string;

  @Prop({ type: String, required: false })
  @IsOptional()
  synopsis: string;

  @Prop({ type: String, required: false })
  @IsOptional()
  type_of_learner: string;

  @Prop({ type: Number, required: false })
  @IsOptional()
  reading_level: number;

  @Prop({ required: false })
  @IsOptional()
  categories: [string];

  @Prop({ required: false })
  @IsOptional()
  content_tags: [string];

  @Prop({ type: Number, required: false })
  @IsOptional()
  paragraphCount: number;

  @Prop({ type: String, required: false })
  @IsOptional()
  title: string;

  @Prop({ type: String, required: false })
  @IsOptional()
  @IsString()
  description: string;

  @Prop({ type: String, required: true })
  @IsString()
  category: string;

  @Prop({ type: String, required: false })
  @IsOptional()
  @IsString()
  author: string;

  @Prop({ type: String, required: false })
  @IsOptional()
  @IsString()
  publisher: string;

  @Prop({ type: String, required: false })
  @IsOptional()
  @IsString()
  edition: string;

  @Prop({ type: String, required: false })
  @IsOptional()
  @IsString()
  imagePath: string;

  @Prop({ type: String, required: true, index: true })
  @IsString()
  language: string;

  @Prop({ type: String, required: false })
  @IsOptional()
  @IsString()
  difficultyLevel: string;

  @Prop({ type: String, required: true })
  @IsString()
  status: string;

  @Prop({ type: String, required: false })
  @IsOptional()
  @IsString()
  ageGroup: string;

  @Prop({ type: String, required: false })
  @IsOptional()
  @IsString()
  flaggedBy: string;

  @Prop({ type: String, required: false })
  @IsOptional()
  @IsString()
  lastFlaggedOn: string;

  @Prop({ type: String, required: false })
  @IsOptional()
  @IsString()
  flagReasons: string;

  @Prop({ type: String, required: false })
  @IsOptional()
  @IsString()
  reviewer: string;

  @Prop({ type: String, required: false })
  @IsOptional()
  @IsString()
  reviewStatus: string;

  @Prop({ required: true })
  tags: [string];

  @Prop({ default: now(), index: true })
  createdAt: Date;

  @Prop({ default: now() })
  updatedAt: Date;
}

export type collectionDocument = collection & Document;

export const collectionDbSchema = SchemaFactory.createForClass(collection);
