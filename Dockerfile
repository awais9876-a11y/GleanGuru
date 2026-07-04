# ---- Stage 1: Build the Flutter web app -----------------------------------
FROM ghcr.io/cirruslabs/flutter:3.19.0 AS build

WORKDIR /app

# Copy dependency definitions first for better layer caching
COPY pubspec.yaml ./
RUN flutter pub get

# Copy source code and build
COPY . .
RUN flutter build web --release --base-href "/"

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
