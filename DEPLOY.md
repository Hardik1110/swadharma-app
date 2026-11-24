# Deploying Swadharma for the client

The app needs a server (accounts, chat relay, wallet, call set-up). To let the client try it on their
own phone without installing anything on a computer, host the server online and build the Android app
pointing at it.

```
client's phone  ──https/wss──▶  hosted server (this repo's /server)  ──▶  Agora (calls)
```

## 1. Before you deploy

**Agora (calls).** Create a project in the Agora console and choose **Testing mode: App ID only**.
Copy its *App ID*. This never expires and allows many calls at once.
If your project is in *Secured mode* instead (certificate enabled), either create a testing-mode one or set
`AGORA_APP_CERTIFICATE` too (the server then signs a token per call).

**Environment variables the server reads**

| Variable | Needed | Meaning |
|---|---|---|
| `AGORA_APP_ID` | for calls | Agora App ID. Without it, chat works and calls are switched off |
| `AGORA_APP_CERTIFICATE` | secured Agora projects only | server signs call tokens |
| `PORT` | set by the host | |
| `DATA_FILE` | no | JSON database file (default in the Docker image: `/app/data/db.json`) |
| `ENABLE_CONSOLE` | no | `false` hides the browser astrologer console (it has no login) |
| `DEV_MODE` | no | `false` stops returning the OTP in API responses (then you need Firebase SMS) |
| `FIREBASE_PROJECT_ID` | for real SMS | customers sign in with Firebase SMS; see `README.md` |
| `ASTROLOGER_LOGIN` | no | `firebase` makes astrologers use Firebase SMS too. Default: astrologers keep the on-screen demo code, which on a **public** server lets anyone sign in as a demo astrologer. Use `firebase` there |

Leave `DEV_MODE` and `FIREBASE_PROJECT_ID` unset for a demo: the login code is shown on screen.

## 2a. Render (easiest; free; needs the code on GitHub)

1. Put this folder in a GitHub repository (`git init`, commit, push).
2. Sign up at render.com, then **New + → Blueprint**, pick the repository. It reads `render.yaml`.
3. When asked, enter `AGORA_APP_ID` (and leave `AGORA_APP_CERTIFICATE` empty for a testing-mode project).
4. Wait for the deploy. Open `https://<your-service>.onrender.com/health`. It should show `{"ok":true}`.

## 2b. Fly.io (no GitHub needed; asks for a card)

```bash
brew install flyctl && fly auth login
cd server
fly launch --no-deploy --copy-config        # keep the existing fly.toml; pick any app name
fly secrets set AGORA_APP_ID=<your-app-id>
fly deploy
```
Your address is `https://<app-name>.fly.dev`.

## 2c. Anywhere with Docker

```bash
docker build -t swadharma-api ./server
docker run -p 8080:8080 -e AGORA_APP_ID=<id> swadharma-api
```
Put it behind HTTPS (any host's load balancer does this). The app switches to `wss://` automatically.

## 3. Build the Android app for the client

```bash
tool/build_release.sh https://<your-service>.onrender.com
```
Send `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` (about 95 MB; works on almost every Android phone
since 2017). On the phone: open the file and allow "install unknown apps" when asked.

The app also has **Server: …** at the bottom of the login screen, so the address can be changed on the phone
later without rebuilding.

**iPhone:** an installable iPhone app needs a paid Apple Developer account (TestFlight). Without one, send
the source code and a screen recording; the app runs on the iOS simulator (`flutter run`).

## 4. Check it works before sending

1. Open the APK on a phone **on mobile data** (proves the server is reachable from anywhere).
2. Sign up with any number; the code appears on screen. You get ₹100.
3. Open Tara Mehta, tap Chat, send a message, get a reply (the built-in bot answers when no astrologer is online).
4. On a second phone: **I'm an astrologer** → tap `Tara · 9100000002`. Request a chat from the first phone and accept it
   on the second: now two real people are talking, and the customer's wallet counts down.
5. Calls: on the astrologer side use the app (or `https://<server>/console` → *Join with demo clip*).

## 5. Things to know about a free host

* **Cold start.** Free instances sleep when idle. The first request can take up to a minute. Open `/health` in a
  browser a minute before the client starts.
* **Data resets.** The database file lives on the container's disk, which is wiped on restart/redeploy.
  Astrologers reload from the built-in data; customer accounts have to be created again.
* **Demo login.** With `DEV_MODE` on, the login code is returned by the API so no SMS is needed. Fine for a demo,
  not for production (use Firebase SMS: see `README.md`).
* **Browser console.** `/console` and the astrologer WebSocket by id have no login. Set `ENABLE_CONSOLE=false`
  if you don't want strangers able to accept requests. The in-app astrologer login is unaffected.
* **Secrets.** Never commit an Agora certificate or token. Enter them as environment variables on the host.

## Testing on your own phone, before any of this

* **Same Wi-Fi.** The phone's **Wi-Fi must be on and on the same network as your computer** (mobile data cannot
  reach a computer's local address). Then in the app: *Server: …* → type your computer's address
  (for example `192.168.1.20`) → *Test connection*.
* **USB cable (Android).** No Wi-Fi needed:
  ```bash
  adb reverse tcp:8787 tcp:8787
  flutter run -d <phone-id> --dart-define=API_BASE_URL=http://localhost:8787
  ```
