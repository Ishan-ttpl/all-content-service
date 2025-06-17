# Stage 1: Builder
FROM node:16.13.2-alpine AS builder

WORKDIR /app

COPY package*.json ./
RUN npm ci

COPY . .
RUN npm run build || echo "No build step defined, skipping"

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

CMD ["node", "dist/index.js"]
