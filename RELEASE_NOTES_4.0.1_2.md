# Hestia 4.0.1_2

This maintenance release republishes the client builds with the current production server and recent call fixes.

## Fixed

- Reset stale saved local server values such as `localhost:3000` to `wss://hestiachat.site/ws`.
- Keep the official client from falling back to a local development server.
- Play the Android incoming call ringtone through the notification channel while the screen is locked.
- Show the signed-in nickname in the chat list so users can see which account is active.

## Notes

- Existing users on `4.0.0+1` should be offered this update after `latest.json` is deployed.
- If a server `data.json` is edited manually while Node/PM2 is running, the running process can write its in-memory state back to disk. Stop PM2 before clearing or replacing `data.json`.
