# ---- Stage 1: Build the Flutter web app -----------------------------------
# Must be Flutter 3.27+: lib/main_entry/theme_config.dart uses CardThemeData,
# which doesn't exist before Flutter 3.27. Pinned to a known-good version so
# local, Vercel, and Docker/Alibaba builds all match and can't drift apart.
FROM ghcr.io/cirruslabs/flutter:3.44.4 AS build

WORKDIR /app

COPY pubspec.yaml ./
RUN flutter pub get

COPY . .
RUN flutter build web --release --source-maps --base-href "/"

# ---- Stage 2: Serve the build + /api/chat with Node -----------------------
FROM node:20-alpine

WORKDIR /app

COPY package.json ./
RUN npm install --omit=dev

COPY server.js ./
COPY --from=build /app/build/web ./build/web

ENV PORT=8080
EXPOSE 8080

CMD ["node", "server.js"]
