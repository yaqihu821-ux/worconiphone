# Worcon online backend

The iPhone app calls this service over HTTPS. This directory contains only the
minimal chat proxy and no database. Conversation history remains on the iPhone.

## Host requirements

- Node.js 20 or newer, a public HTTPS URL, and environment variables.
- Run `npm start` in this directory. The process listens on `0.0.0.0` and the
  host-provided `PORT`.
- Set `NODE_ENV=production`, `GROQ_API_KEY`, and a separate, long, random
  `WORCON_ACCESS_TOKEN` in the host's private environment settings. Do not put
  their values in Git, the iPhone app source, or a URL. The service refuses to
  start in production without the access token.

## iPhone setup after deployment

In Worcon Settings, set the service address to the HTTPS URL, enter the
`WORCON_ACCESS_TOKEN` into **线上连接口令**, tap **保存口令**, and then **检查连接**.
The app stores this access token in iPhone Keychain. The Groq API key stays
only on the backend. Rotate the access token on the host and iPhone if it is
exposed.

## Checks

- `GET /health` with `Authorization: Bearer <access token>` returns
  `status: ok` and `groqConfigured: true` when the service and Groq key are set.
- An unauthenticated health or chat request returns HTTP 401.
- `POST /v1/chat/completions` accepts the model IDs in `server.mjs` and streams
  text events. The server limits body size, message count, rate, and Groq time.
  It does not log message bodies or provider response contents.

For a free Render web service, upload this project to a repository first.
Set **Root Directory** to `backend` when the Xcode project is at the repository
root, **Build Command** to `npm install`, and **Start
Command** to `npm start`. Render provides the `PORT` and HTTPS URL. Its free
service can sleep after 15 minutes idle, so the first request may be slow.
Uploading the project and creating the service are separate actions.
