# ONYX voice room: naye features

Replace these files in `user_app/lib/`:
- voice_room_page.dart (updated)
- voice_rooms_page.dart (updated: gift cleanup only)
- voice_extras.dart (NEW)

Nothing else changed. Subject / class selection files are untouched.
No new packages needed.

## Features
1. Speaking ring: glow and ripple around the avatar of whoever is talking.
2. Members list: tap the LIVE bar, see Owner / Admin / On seat / Listening. Owner can make or remove admin.
3. Gifts: gift button next to chat box. Pick person, x1/x10/x99, pick gift. Full-screen animation for everyone in the room. Receiver gets a charm badge on the seat.
4. Gift data is cleaned up automatically when the room closes.

## Firebase Realtime DB rules to add
Put these next to your existing "voiceRooms" / "voiceChat" rules:

```json
"voiceGifts": {
  "$room": {
    ".read": "auth != null",
    "$id": {
      ".write": "auth != null && !data.exists() && newData.child('from').val() === auth.uid",
      ".validate": "newData.hasChildren(['from','to','g','n','ts'])"
    }
  }
}
```

Inside "voiceRooms" -> "$room" add (charm points):

```json
"charm": {
  "$uid": { ".write": "auth != null", ".validate": "newData.isNumber()" }
}
```

If the "charm" rule is missing, gifts still play; only the badge count will not update.

## Notes
- Speaking ring on other people's seats works once they also update to this version.
- Gifts are free for now. A coin balance can be added next.
- Not compiled here (no Flutter SDK in my environment). Run `flutter pub get && flutter run` and send me any error.
