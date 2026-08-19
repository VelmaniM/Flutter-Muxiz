# Multi-stage production build for NestJS Backend with Prisma OpenSSL support
FROM node:20-slim AS builder

WORKDIR /app

RUN apt-get update -y && apt-get install -y openssl

# Copy backend dependencies
COPY backend/package*.json ./
COPY backend/prisma ./prisma/
RUN npm ci

# Generate Prisma Client
RUN npx prisma generate

# Copy backend source and build
COPY backend/ ./
RUN npm run build

# Production Runner stage
FROM node:20-slim AS runner

WORKDIR /app

RUN apt-get update -y && apt-get install -y openssl ca-certificates && rm -rf /var/lib/apt/lists/*

ENV NODE_ENV=production
ENV PORT=5001

# Copy built artifacts and production dependencies
COPY backend/package*.json ./
COPY backend/prisma ./prisma/
RUN npm ci --only=production && npx prisma generate

COPY --from=builder /app/dist ./dist

EXPOSE 5001

CMD ["node", "dist/src/main"]
