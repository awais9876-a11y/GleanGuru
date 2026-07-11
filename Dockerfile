# ---- Stage 1: Build the Flutter web app -----------------------------------
# IMPORTANT: this must be Flutter 3.27+ (bumped from the previous pin of
# 3.19.0). lib/main_entry/theme_config.dart uses CardThemeData, which does
# not exist before Flutter 3.27 (ThemeData.cardTheme was CardTheme-typed
# before that release) - building this repo with Flutter 3.19.0 fails with
# "Error: Type 'CardThemeData' not found" / "isn't a type". The verified
# working build (see build_log.txt) used Flutter 3.44.4 on the stable
# channel; pin to that exact version so local, Vercel, and Docker/Alibaba
# builds all use the same Flutter version and can't drift apart again.
FROM ghcr.io/cirruslabs/flutter:3.44.4 AS build

WORKDIR /app

# Copy dependency definitions first for better layer caching
COPY pubspec.yaml ./
RUN flutter pub get

# Copy source code and build
COPY . .
RUN flutter build web --release --source-maps --base-href "/"

# ---- Stage 2: Serve the build + /api/chat with Node -----------------------
# We use a small Node/Express server (server.js) instead of plain Nginx so
# that the same POST /api/chat proxy used on Vercel (api/chat.js) is also
# available when this image is deployed to Alibaba Cloud (Container
# Registry + ECS / ACK / SAE) or any other Docker host.
FROM node:20-alpine

WORKDIR /app

COPY package.json ./
RUN npm install --omit=dev

COPY server.js ./
COPY --from=build /app/build/web ./build/web

ENV PORT=8080
EXPOSE 8080

CMD ["node", "server.js"]
