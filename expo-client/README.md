# KOOM Expo Go Client

This is a lightweight Expo/React Native client for testing the existing Koom Server API through Expo Go.

The existing root mobile app is Flutter. Expo Go cannot run Flutter code, so this folder contains a separate Expo client that talks to the same backend endpoints.

## What works now

- phone auth request: `POST /api/auth/request-code`
- phone auth verification: `POST /api/auth/verify-code`
- group list: `GET /api/groups`
- public group creation: `POST /api/groups`
- group messages: `GET /api/groups/:groupId/messages`
- send message: `POST /api/groups/:groupId/messages`

## Start with Expo Go

```bash
cd expo-client
npm install
cp .env.example .env
npm run start:tunnel
```

Then scan the QR code with Expo Go.

## Backend URL

Set `EXPO_PUBLIC_API_BASE_URL` in `.env`.

Examples:

```bash
# Android emulator
EXPO_PUBLIC_API_BASE_URL=http://10.0.2.2:8080

# iOS simulator
EXPO_PUBLIC_API_BASE_URL=http://localhost:8080

# Real phone on the same Wi-Fi as your computer
EXPO_PUBLIC_API_BASE_URL=http://192.168.1.25:8080

# Public HTTPS tunnel or deployed backend
EXPO_PUBLIC_API_BASE_URL=https://your-domain.example.com
```

For a real phone, `localhost` means the phone itself, not your computer. Use your computer's LAN IP address or a public tunnel.

## Server requirements

The server must be running and reachable from the phone.

For local development, run the server with a development configuration, PostgreSQL, and a JWT secret of at least 32 characters. The server already exposes the API endpoints used by this client.

## Important limitation

This Expo client is an MVP test client. It does not replace the Flutter app yet. It exists so KOOM can be tested quickly through Expo Go while keeping the current Flutter client untouched.
