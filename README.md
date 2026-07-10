# GleanGuru (Memory Agent)

A Flutter web app that helps you build your own multimodal knowledge base
over time, with a Qwen (Alibaba Dashscope) powered chat agent.

## Project structure

```
lib/            Flutter app (BLoC state management, go_router navigation)
web/            Flutter web template (index.html, manifest.json, icons)
api/chat.js     Vercel Edge Function - proxies chat requests to Dashscope
server.js       Node/Express server - same proxy, for Docker/Alibaba Cloud
scripts/        Build scripts (Vercel build step installs Flutter itself)
Dockerfile      Multi-stage build: Flutter web build -> Node runtime image
nginx.conf      Reference config for pure static hosting (see note in file)
```

## Why the app previously 404'd on Vercel

Vercel had no idea this was a Flutter project. There was no `buildCommand`
in `vercel.json`, so Vercel never actually ran `flutter build web` — it just
served the raw repo, which has no root `index.html`. On top of that, the
Flutter build itself would have failed for several independent reasons even
if Vercel had tried to run it:

- `lib/main.dart` (the required entry point) didn't exist.
- `pubspec.yaml` declared an asset folder (`assets/images/`) that didn't
  exist anywhere in the repo — `flutter build` fails hard on this.
- Several packages were imported in code but missing from `pubspec.yaml`
  (`dio`, `connectivity_plus`, `firebase_messaging`, `flutter_secure_storage`,
  `get_it`, `jwt_decoder`).
- `encryption_engine.dart` and `token_manager.dart` each declared their own
  `IOSOptions` / `AndroidOptions` / `KeychainAccessibility` classes with the
  same names as the real ones already provided by the `flutter_secure_storage`
  package they import — a guaranteed name-collision compile error.
- `sync_engine.dart` referenced `LocalDatabase` without importing it, and
  used an `ApiClient` interface that had no relationship to the concrete
  `ApiClient` class in `api_client.dart` (same name, two unrelated types).
- `Icons.brain` isn't a real Material icon (used in `app.dart` and
  `login_screen.dart`).
- `biometric_service.dart` called `LocalAuthentication.isDeviceLockedOut()`,
  a method that doesn't exist in the `local_auth` package.
- No concrete `AuthService` implementation existed anywhere, so nothing
  could actually be wired up in a `main.dart` even once one was added.

All of the above are fixed in this branch. See the pull request description
for the full list of changes.

## Deploying to Vercel

1. Import the repo in Vercel as normal (framework preset: **Other**).
2. Set the environment variable `QWEN_API_KEY` (Project Settings ->
   Environment Variables) to your Dashscope API key.
3. Optionally set `DASHSCOPE_ENDPOINT` if you use the Mainland China
   endpoint instead of the international one (see `.env.example`).
4. Deploy. `vercel.json` now defines:
   - `installCommand`: `npm install` (only needed for `server.js`'s
     dependency, harmless on Vercel)
   - `buildCommand`: `bash scripts/vercel-build.sh` — this clones the
     Flutter SDK (stable channel) into the build container and runs
     `flutter build web --release`
   - `outputDirectory`: `build/web`
   - a SPA rewrite so client-side routes (`/home`, `/profile`, ...) don't
     404 on refresh, while `/api/*` still reaches `api/chat.js`

First builds will take a few minutes longer than a typical Vercel deploy
because Flutter itself has to be installed in the build container — this is
expected and normal for Flutter-on-Vercel deployments.

## Deploying to Alibaba Cloud (or any Docker host)

```bash
docker build -t glean-guru .
docker run -p 8080:8080 \
  -e QWEN_API_KEY=your_key_here \
  -e DASHSCOPE_ENDPOINT=https://dashscope.aliyuncs.com/api/v1 \
  glean-guru
```

The image builds the Flutter web app in stage 1, then serves it from a
small Node/Express server (`server.js`) that also implements `POST
/api/chat` — the same contract as the Vercel edge function — so the chat
feature works identically on both platforms without any client-side code
differences.

Push the image to Alibaba Cloud Container Registry (ACR) and run it on
ECS, ACK (Kubernetes), or Serverless App Engine (SAE); all three just need
the `QWEN_API_KEY` environment variable set on the container/service.

If you'd rather host purely static files (e.g. via OSS + CDN) instead of a
container, `nginx.conf` is kept as a reference config for that — but note
it has no `/api/chat` route, so you'd need to provide that separately (e.g.
Alibaba Function Compute) for the chat feature to work.

### Automated static deploy via GitHub Actions (`.github/workflows/alibabacloud.yml`)

This repo also includes a workflow that automatically builds and syncs the
static web build to an Alibaba Cloud OSS bucket on every push to `main`.
This is a **separate, pure-static deployment path** from the Docker
instructions above — same tradeoff applies: `/api/chat` will not work
through this path, since OSS is object storage with no server-side code
execution.

Required GitHub Secrets (repo → Settings → Secrets and variables → Actions):

| Secret | Value |
|---|---|
| `ALIBABA_ACCESS_KEY_ID` | From Alibaba Cloud RAM console |
| `ALIBABA_ACCESS_KEY_SECRET` | From Alibaba Cloud RAM console |
| `ALIBABA_OSS_REGION` | Your bucket's region code, e.g. `oss-us-west-1` or `oss-cn-hangzhou` — find this on your bucket's overview page in the OSS console |
| `ALIBABA_OSS_BUCKET` | Your actual bucket name (no `oss://` prefix) |

The workflow also configures the bucket's static website hosting (index
and error document both set to `index.html`), which is required for
client-side routes (`/home`, `/profile`, handled by `go_router`) to work
on refresh or direct link — without it, OSS returns a raw XML error
instead of your app for any URL that isn't the bucket root.

## Local development

```bash
flutter pub get
flutter run -d chrome
```

### Important: commit `pubspec.lock`

This repo does not currently have a committed `pubspec.lock`. Without it,
every build (including on Vercel) re-resolves the entire dependency graph
from scratch against whatever the newest published versions happen to be
at that moment — which means a build that works today can fail tomorrow
for reasons completely unrelated to any code change, purely because an
upstream package (most commonly the Firebase family) published a new
release with a different internal version requirement.

Fix this once, permanently:

```bash
flutter pub get          # resolves everything, writes pubspec.lock
git add pubspec.lock
git commit -m "Commit pubspec.lock to freeze dependency resolution"
git push
```

If you don't have Flutter installed locally, open the repo in a GitHub
Codespace (free tier is sufficient), install Flutter there, run the
commands above, and push. After this, Vercel builds install the exact
locked versions every time instead of re-solving, and this class of
"version solving failed" error stops recurring.

To exercise the chat feature locally, run the Node server instead so
`/api/chat` is available:

```bash
flutter build web
npm install
QWEN_API_KEY=your_key_here node server.js
# open http://localhost:8080
```

## Firebase setup (required for sign-in features)

This app expects a Firebase project for email/Google/Apple sign-in
(`lib/core/auth/firebase_auth_service.dart`, wired up in `lib/main.dart`).
`Firebase.initializeApp()` is wrapped in a try/catch so the app still boots
without one, but sign-in will not work until you:

1. Create a Firebase project and register a Web app.
2. Add the Firebase Web SDK config (see FlutterFire docs) so
   `Firebase.initializeApp()` can find your project config on web.
3. Enable the Email/Password, Google, and Apple sign-in providers you want
   to use in the Firebase console.

## Tests

```bash
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs   # generates test/unit/auth_bloc_test.mocks.dart
flutter test test/unit
```

`test/integration/app_flow_test.dart` uses the `integration_test` package
and is intended to be run on a device/emulator or via `flutter drive`,
not as a plain unit test.
