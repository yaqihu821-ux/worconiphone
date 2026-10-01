# Worcon iPhone

Worcon's native SwiftUI iPhone app. It supports streamed chat, local conversation history, model selection, and a minimal Groq proxy. The app does not contain a Groq API key or invent model replies when the service is unavailable.

## Open in Xcode

Open `Worcon.xcodeproj` in Xcode. The iOS app target is configured for iOS 26 or later. Choose your iPhone as the run destination and use your own Apple development team for signing if Xcode asks. This repository is separate from the original Worcon web prototype.

For local Wi-Fi development, see [backend/README.md](backend/README.md). For use away from the Mac, deploy the backend to an HTTPS host as described in [backend/DEPLOY.md](backend/DEPLOY.md). Keep all API keys and access tokens out of Git.
