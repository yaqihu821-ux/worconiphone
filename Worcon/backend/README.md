# Worcon local development backend

This is a local-only development proxy. It keeps the Groq API key in the backend process environment; it is never read from or sent by the iPhone app. Do not expose this service to the public internet or use it on public Wi-Fi.

## Start

1. Connect the Mac and iPhone to the same trusted Wi-Fi.
2. In Terminal, go to this repository's `backend` directory and run `./start.command`.
3. Enter the Groq key at the hidden prompt. It is kept only in that running process environment and is not written to a file. Keep Terminal open while chatting.
4. Find the Mac local hostname with `scutil --get LocalHostName`. In Worcon Settings, enter `http://<hostname>.local:8787`, replacing `<hostname>` with that value, then tap “检查连接”.
5. On the iPhone, approve the local network permission prompt if it appears.

The server offers `/health` and `POST /v1/chat/completions`. It allows only the model IDs listed in `server.mjs`, limits requests to 64 KiB, 24 messages and 8,000 characters per message, applies a per-IP limit of 20 requests per minute, times out Groq requests after 60 seconds, streams only response text, sets Groq `store: false`, and does not log message bodies or provider response contents.

Closing the Terminal process stops the backend. For an online deployment, use [DEPLOY.md](DEPLOY.md) and set a separate access token.
