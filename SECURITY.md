# Security Policy

## Supported Version

The `main` branch is the active development branch for MobileChat.

## Reporting a Vulnerability

Do not create a public GitHub issue for security vulnerabilities.

Send a private report to the project owner with:

- Vulnerability summary
- Affected screen, API call, or storage area
- Steps to reproduce
- Expected impact
- Suggested fix, if known

## Client Security Requirements

Before production release, the Flutter app must keep these controls enabled:

- Store tokens only in secure storage
- Do not log access tokens or refresh tokens
- Use HTTPS API URLs in production
- Use phone verification only; do not expose legacy email/password auth UI
- Clear local session on refresh-token failure
- Keep dependencies updated
- Run `flutter analyze` and `flutter test` in CI
- Avoid committing secrets, API keys, or signing credentials

## Production Checklist

1. Point `API_BASE_URL` to an HTTPS production endpoint.
2. Verify phone login flow on Android and iOS.
3. Verify session refresh after access token expiry.
4. Verify logout clears secure storage.
5. Verify WebSocket reconnect behavior.
6. Verify invite accept/decline behavior.
7. Run Flutter CI before release.
