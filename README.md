# Koom

Koom is a civic communication app for Android and iOS. It helps people connect with communities, organizations, and public institutions through official groups, public posts, requests, voting, comments, invitations, and QR-based group access.

The current mobile build includes Russian/Kyrgyz language switching, light/dark mode, group invite codes with QR, public request publication tools, voting, comments, status updates, and photo attachments.

## Mobile clients

### Flutter client

The root project is the original Flutter mobile app.

### Expo Go test client

A lightweight Expo/React Native test client is available in `expo-client/`.

Use it when you want to quickly test KOOM through Expo Go without building the Flutter app:

```bash
cd expo-client
npm install
cp .env.example .env
npm run start:tunnel
```

Set `EXPO_PUBLIC_API_BASE_URL` in `expo-client/.env` to a backend URL that your phone can reach.

Examples:

```bash
# Android emulator
EXPO_PUBLIC_API_BASE_URL=http://10.0.2.2:8080

# iOS simulator
EXPO_PUBLIC_API_BASE_URL=http://localhost:8080

# Real phone on same Wi-Fi as backend computer
EXPO_PUBLIC_API_BASE_URL=http://192.168.1.25:8080

# Public tunnel or deployed backend
EXPO_PUBLIC_API_BASE_URL=https://your-domain.example.com
```

Important: on a real phone, `localhost` means the phone itself. Use your computer's LAN IP address or a public HTTPS tunnel.
