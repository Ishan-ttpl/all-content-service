# Stage 1: Builder
FROM node:16.13.2-alpine AS builder

WORKDIR /app

COPY package*.json ./
RUN npm ci

COPY . .
# CRITICAL CHANGE 1: Remove the `|| echo ...` to ensure the build step fails the Docker build if it truly fails.
# This makes sure the `dist` folder is actually created or you get an error during build.
RUN npm run build 

# Stage 2: Runtime
FROM node:16.13.2-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force

# Copy built app
COPY --from=builder /app/dist ./dist

# Optional: Copy other runtime assets if needed
# COPY --from=builder /app/src ./src

ARG PORT=3000
EXPOSE $PORT

# CRITICAL CHANGE 2: Point to 'dist/main.js' as the entry point.
# This is the standard output for NestJS applications.
CMD ["node", "dist/main.js"]
