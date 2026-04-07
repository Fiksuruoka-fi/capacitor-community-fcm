# FCM Plugin: refreshToken Analysis — Fork vs Community

## Context

The app uses `@capacitor-community/fcm` via a fork (`Fiksuruoka-fi/capacitor-community-fcm#fix-refresh`) to handle FCM token management on iOS and Android. This document analyzes the bug in the community plugin, the fork's fix, and the recommended improvement.

## How `refreshToken` is used

Two call sites in `stores/auth.ts`:

1. **Sign-in** (line ~241): `removeAndRefreshFcmToken()` — removes old token from Firestore, calls `FCM.refreshToken()` to rotate the native FCM token, saves the new token to Firestore
2. **Sign-out** (line ~601): `removeCurrentFcmTokenFromFirestore()` + `createNewFcmToken()` — same pattern with explicit steps

**Purpose**: When a user signs in/out, the FCM token is rotated so push notifications don't leak to the wrong user.

---

## The Bug in Community Plugin (master)

```swift
@objc func refreshToken(_ call: CAPPluginCall) {
    // Bug 1: guard inverted — returns on SUCCESS, never resolves the call
    FirebaseMessaging.Messaging.messaging().deleteData { error in
        guard let error = error else {
            print("Delete FCMToken successful!")
            return   // <-- exits on success, call is never resolved
        }
        call.reject("Delete FCMToken failed", error.localizedDescription)
    }

    // Bug 2: NOT nested — runs immediately in parallel with deleteData
    Messaging.messaging().token { token, error in ... }
}
```

**Two bugs:**
1. **Race condition**: `token()` runs in parallel with `deleteData()`, not after it completes. The new token may be fetched before the old one is deleted, returning the same token.
2. **Broad API**: `deleteData` deletes all Messaging data, not just the token.

**Additional issue in Plugin.m**: `refreshToken` is registered twice in the `CAP_PLUGIN` macro.

## The Fork's Fix (fix-refresh branch)

```swift
@objc func refreshToken(_ call: CAPPluginCall) {
    Installations.installations().delete { error in
        if let error = error { call.reject(...); return }
        Messaging.messaging().token { token, error in ... }
    }
}
```

**Fixes the sequencing** (properly nested). But uses `Installations.installations().delete` which:
- Deletes the entire Firebase Installation ID, not just the FCM token
- Can affect Analytics/Crashlytics correlation
- Is heavier than necessary

## The Applied Fix (this branch)

```swift
@objc func refreshToken(_ call: CAPPluginCall) {
    Messaging.messaging().deleteToken { error in
        if let error = error {
            call.reject("Failed to delete FCM token", error.localizedDescription)
            return
        }
        Messaging.messaging().token { token, error in
            if let error = error {
                call.reject("Failed to get FCM registration token", error.localizedDescription)
            } else if let token = token {
                self.fcmToken = token
                call.resolve(["token": token])
            }
        }
    }
}
```

**Why this is the right fix:**
- `deleteToken` is the Firebase-recommended API for token rotation
- Only invalidates the current FCM token — does not touch Installation ID
- Preserves Analytics/Crashlytics installation correlation
- Properly nested: delete completes → then fetch new token
- Matches the existing Android implementation pattern exactly

## Comparison

| Aspect | Community (master) | Fork (fix-refresh) | This fix |
|---|---|---|---|
| iOS sequencing | ✗ Broken (race condition) | ✓ Correct (nested) | ✓ Correct (nested) |
| iOS delete API | `deleteData` (broad) | `Installations.delete` (heaviest) | `deleteToken` (targeted) |
| Android | ✓ Correct | ✓ Correct (identical) | No change needed |
| Side effects | Token may not rotate | Nukes Installation ID | Only rotates FCM token |
| Plugin.m | Duplicate registration | Duplicate registration | Fixed |

## Android — No Changes Needed

Both versions already use the correct pattern:

```java
FirebaseMessaging.getInstance().deleteToken()
    .addOnCompleteListener(result -> {
        FirebaseMessaging.getInstance().getToken()  // nested, correct
            .addOnCompleteListener(...)
    })
```

## Verification Steps

After updating the fork's iOS code:
1. Build the iOS app
2. Sign in → verify FCM token in Firestore has `customer_uid` set
3. Sign out → verify old token doc deleted, new token doc created with `null` uid
4. Sign in as different user → verify new token doc has the new user's uid
5. Confirm the token string actually changes between rotations

## Recommendation

Use this fix in the fork. Optionally, PR it upstream to `capacitor-community/fcm` so the community plugin can be used without a fork.
