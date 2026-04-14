# Tailscale Trusted Network Authentication

**Feature:** Trusted Network Auth (Tailscale CGNAT range)
**Priority:** high
**Type:** integration

## Prerequisites
- Alfred server running on CachyOS PC
- iOS device on the same Tailscale network
- Tailscale installed and connected on both devices

## Test Steps
1. Connect the iOS device to the Tailscale VPN.
2. Configure the app's server settings to point to the server's Tailscale IP (100.x.y.z).
3. Open the app and verify WebSocket connection succeeds.
4. Send a message and verify a response is received.
5. Navigate to Settings and attempt to save integration credentials.
6. Try the device registration endpoint (push notifications toggle).
7. Disconnect from Tailscale on the iOS device.
8. Attempt to connect to the server using the Tailscale IP.

## Expected Result
- Steps 2-4: WebSocket connection succeeds. The `/ws` endpoint does not have the trusted network guard, so it works from any network.
- Steps 5-6: Credential and device registration endpoints are guarded by `require_trusted_network`. Requests from Tailscale IPs (100.64.0.0/10 CGNAT range) pass the check.
- Steps 7-8: Without Tailscale, the Tailscale IP is unreachable, so connections fail at the network level (not at the auth level).

## Notes
- `require_trusted_network` accepts: 127.0.0.1, ::1, "testclient" (Starlette), and any IP in 100.64.0.0/10.
- This replaces the old `require_localhost` dependency, which only allowed 127.0.0.1 and ::1. The iOS app could never reach those endpoints before.
- The WebSocket endpoint itself does NOT use this dependency — it is open. Only credential management and device registration endpoints are guarded.
- Edge case: if the server is behind a reverse proxy, the client IP may be the proxy's IP, not the Tailscale IP. Ensure no proxy is stripping the original client IP.
