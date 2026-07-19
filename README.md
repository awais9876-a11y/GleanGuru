# Memory Agent (simplified core build)

A Flutter web app: chat with a Qwen (Alibaba Dashscope) AI, and everything
you send/teach it is saved to your **own device's local storage** so it's
remembered next time you open the app in the same browser.

This is a deliberately trimmed-down version of the project for a fast,
low-risk submission: **no accounts, no sign-in, no Firebase, no cloud
database.** Just the core loop — chat in, memory persisted, chat out — with
both deploy targets (Vercel and Alibaba Cloud) fully working.

## What changed from the earlier Firebase-based version

| Before | Now |
|---|---|
| Firebase Auth (email/Google/Apple sign-in) | Removed - no accounts at all |
| Cloud Firestore (`users/{uid}/memories`) | Replaced with on-device `shared_preferences` storage |
| go_router + splash/login/signup/profile screens | Removed - the app is a single chat screen |
| Biometric auth, token manager, encryption engine, offline sync engine | Removed - all of it was either auth-dependent or unused dead code |

**What this means in practice:** your knowledge bank lives in *this specific
browser, on this specific device*. Clearing browser data / using a different
browser / a different device starts a fresh, empty knowledge bank. If you
need it to follow a person across devices later, that's exactly what
Firebase Auth + Firestore give you back — the earlier version of this project
already had that wiring and can be restored from git history / your prior
version whenever multi-device sync becomes a real requirement, without
touching the chat/UI code in this build.

## Project structure

```
lib/            Flutter app (BLoC state management, single screen, no routing)
web/            Flutter web template (index.html, manifest.json)
api/chat.js     Vercel Edge Function - proxies chat requests to Dashscope
server.js       Node/Express server - same proxy, for Docker/Alibaba Cloud
scripts/        Build scripts (Vercel build step installs Flutter itself)
Dockerfile      Multi-stage build: Flutter web build -> Node runtime image
nginx.conf      Reference config for pure static hosting (see note in file)
```

## How the memory bank works

- Every chat turn (`role: user` / `role: assistant`) is written locally via
  `MemoryRepository`, backed by `shared_preferences` (browser `localStorage`
  on web).
- On opening the app, the most recent entries load automatically and the
  conversation picks up where it left off - in that browser, on that device.
- Only the most recent ~30 entries are replayed back to Qwen as context per
  request (`MemoryAgentBloc._contextWindowSize`), to keep request size and
  latency bounded as history grows. Everything is still saved in full; this
  only limits how much of it the model sees on any single turn.
- The trash icon in the app bar permanently deletes everything stored on this
  device - there's no undo.

## Local development

```bash
flutter pub get
flutter run -d chrome
```

To exercise the chat feature locally (talks to real Dashscope), run the Node
server instead so `/api/chat` is available:

```bash
flutter build web
npm install
QWEN_API_KEY=your_key_here node server.js
# open http://localhost:8080
```

### First-time setup: generate `pubspec.lock`

This build doesn't ship a `pubspec.lock` (dependencies changed enough from
the prior version that the old lockfile no longer applies). Generate and
commit one **once**, immediately after unpacking this project, so every
future build (including Vercel/CI) resolves the exact same dependency
versions instead of re-solving from scratch every time:

```bash
flutter pub get          # resolves everything, writes pubspec.lock
git add pubspec.lock
git commit -m "Commit pubspec.lock to freeze dependency resolution"
```

### App icons

`web/manifest.json` and `web/index.html` reference `web/icons/Icon-192.png`,
`web/icons/Icon-512.png`, two maskable variants, and `web/favicon.png`. Those
binary image files aren't part of this text-based rebuild - if you had them
in your previous version of this repo, copy that `web/icons/` folder and
`web/favicon.png` back in. If you don't have them yet, the app still builds
and runs fine without them (the browser just won't show a custom tab icon
until you add them).

## Tests

```bash
flutter pub get
flutter test
```

`test/widget_test.dart` is a minimal smoke test: it boots the app with a
mocked local-storage backend and confirms the empty-state screen renders. It
deliberately never sends a chat message, so it never makes a real network
call.

---

## Deploying to Vercel

1. Push this project to a GitHub repo.
2. Go to https://vercel.com, sign in with GitHub, **Add New → Project →
   Import** this repo.
3. Framework preset: **Other**.
4. Project Settings → Environment Variables, add:
   - `QWEN_API_KEY` = your Dashscope API key (**required** - see below for
     how to get one)
   - `DASHSCOPE_ENDPOINT` = only set this if your key is from the Mainland
     China Dashscope console: `https://dashscope.aliyuncs.com/api/v1`
5. Deploy. `vercel.json` already defines the build (`scripts/vercel-build.sh`
   installs Flutter inside the build container, then runs
   `flutter build web --release`) - the first build takes a few minutes
   longer than a typical Vercel deploy because of that Flutter install; this
   is expected.
6. Once deployed, open the URL, send a chat message, and confirm you get a
   reply. If you see "Missing QWEN_API_KEY environment variable" in the
   response, go back to step 4.

## Deploying to Alibaba Cloud

Two independent paths - pick based on whether you need chat to work:

### Path A — Docker container (chat works)

```bash
docker build -t glean-guru .
docker run -d -p 8080:8080 \
  -e QWEN_API_KEY=your_key_here \
  -e DASHSCOPE_ENDPOINT=https://dashscope.aliyuncs.com/api/v1 \
  glean-guru
```

To run this on Alibaba Cloud itself instead of locally:
1. Alibaba Cloud console → **Container Registry (ACR)** → create a Personal
   Instance (free tier is fine) → create a namespace + image repository.
2. Build, tag, and push:
   ```bash
   docker build -t glean-guru .
   docker tag glean-guru registry.<region>.aliyuncs.com/<namespace>/glean-guru:latest
   docker login registry.<region>.aliyuncs.com
   docker push registry.<region>.aliyuncs.com/<namespace>/glean-guru:latest
   ```
3. Run it on **ECS** (a VM you `docker run` on directly), **ACK** (managed
   Kubernetes, only worth it if you already run k8s), or **SAE** (Serverless
   App Engine - simplest managed option, point it at the ACR image, no VM to
   manage). Set `QWEN_API_KEY` as an environment variable on whichever
   compute service you pick.
4. Open a security-group rule for port 8080 (or put a Server Load Balancer /
   Alibaba CDN with an HTTPS cert in front of it - recommended for anything
   public, since the raw container serves plain HTTP).

### Path B — Static OSS + CDN (chat will NOT work)

Already automated by `.github/workflows/alibabacloud.yml`:
1. Alibaba Cloud console → **Object Storage Service (OSS)** → Create Bucket.
   Note the exact **region code** (e.g. `oss-us-west-1`) shown on the
   bucket's overview page, and the exact **bucket name**.
2. Console → **RAM** → Users → create a user with programmatic access,
   attach an OSS read/write policy scoped to this bucket. Save the
   AccessKey ID/Secret (the secret is shown only once).
3. GitHub repo → **Settings → Secrets and variables → Actions**, add:
   `ALIBABA_ACCESS_KEY_ID`, `ALIBABA_ACCESS_KEY_SECRET`,
   `ALIBABA_OSS_REGION`, `ALIBABA_OSS_BUCKET`.
4. Push to `main`. The workflow builds the Flutter web app, configures the
   bucket for static-website hosting via `oss-website-config.xml` (so
   refreshing the page doesn't 404), and syncs `build/web/` to the bucket.
5. Optionally front it with **Alibaba CDN** for a custom domain + HTTPS (the
   raw OSS website endpoint is HTTP-only by default).

Remember: this path is pure static hosting. `/api/chat` will return a 404
here — there's no server to run it. Use Path A if you want chat to work on
Alibaba Cloud.

## Getting a Dashscope (Qwen) API key

Needed for **both** deploy paths above:
1. Go to https://dashscope.console.aliyun.com (or the Mainland China console
   if that's where your Alibaba account is registered).
2. **API-KEY management** → create a new key.
3. Put that value in `QWEN_API_KEY` wherever you deployed (Vercel env var, or
   your Docker container's `-e QWEN_API_KEY=...`). It should never appear in
   any client-side code — `api/chat.js` and `server.js` both keep it
   server-side only, which is why the Flutter client only ever calls its own
   `/api/chat`, never Dashscope directly.
4. If the key was issued through the Mainland China console specifically,
   also set `DASHSCOPE_ENDPOINT=https://dashscope.aliyuncs.com/api/v1`;
   otherwise leave it unset (defaults to the international endpoint).
