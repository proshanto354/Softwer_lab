# Shomman - Elder Protection and Support System

Mobile app + REST API that lets elderly people and trusted reporters (family, neighbors,
social workers, volunteers) report elder neglect privately, and lets social welfare officers
verify, prioritise, visit and track cases.

```
shomman/
  app/          Flutter mobile app  (Firebase Auth, FCM, Storage)
  backend/      Node.js + Express API  (MySQL, firebase-admin)
  storage.rules Firebase Storage security rules
```

## Why there is a backend
The proposal uses MySQL as the database. A mobile app must never connect to MySQL directly
(the DB password would ship inside the APK). So the Flutter app talks to a small Node.js API,
which verifies the Firebase login token and reads/writes MySQL.

Flow: `Flutter -> Firebase Auth (login) -> ID token -> Node API -> MySQL`.
Evidence photos/audio go from Flutter straight to Firebase Storage; only the URL is saved in MySQL.

## Feature map (from the proposal)
| Proposal feature | Where |
|---|---|
| Registration & login | `login_screen.dart`, `profile_setup_screen.dart`, `routes/auth.js` |
| Elder profile management | `elders_screen.dart`, `routes/elders.js` |
| Anonymous complaint | `complaint_form_screen.dart` (switch), officers never see reporter (`services/complaints.js`) |
| Photo + audio evidence | `complaint_form_screen.dart`, `storage_service.dart` |
| SOS help request | `sos_screen.dart`, `routes/sos.js`, SOS tab in admin |
| Complaint tracking | `my_complaints_screen.dart`, `complaint_detail_screen.dart` |
| Monthly wellbeing form | `wellbeing_screen.dart`, `routes/wellbeing.js` (auto-flags worrying answers) |
| Dashboard, verification, risk level, visit scheduling, status updates | `admin_home.dart`, `complaint_detail_screen.dart`, `routes/admin.js` |
| Reports & analytics | Analytics tab, `GET /api/admin/analytics` |
| Push notifications (FCM) | `push_service.dart`, `services/notify.js` (sent on every status change) |
| Awareness | `awareness_screen.dart` |

## 1. Database
```bash
mysql -u root -p < backend/schema.sql
```

## 2. Firebase
1. Create a project at https://console.firebase.google.com
2. Enable **Authentication -> Email/Password**.
3. Enable **Storage**, then paste `storage.rules` into Storage -> Rules.
4. Add an **Android app** (package name = the one you use in step 4 below), download `google-services.json`
   into `app/android/app/`.
5. Project settings -> Service accounts -> **Generate new private key** -> save as
   `backend/serviceAccountKey.json`.

## 3. Backend
```bash
cd backend
npm install
cp .env.example .env      # edit DB password
npm start                 # http://localhost:3000/health
```

### Create your first officer/admin
Officers and admins cannot self-register. Sign up in the app first, then promote yourself:
```sql
UPDATE users SET role = 'admin' WHERE email = 'you@example.com';
```
An admin can then promote others with `PATCH /api/admin/users/:id/role` `{ "role": "officer" }`.

## 4. Flutter app
```bash
flutter create --org com.shomman --project-name shomman shomman_app
cd shomman_app
# copy app/lib/ and app/pubspec.yaml from this project over the generated ones
flutter pub get
```
Then:
- Put `google-services.json` in `android/app/` and add the Google services Gradle plugin
  (follow the "Add Firebase SDK" step in the Firebase console; or run `flutterfire configure`).
- Set `minSdkVersion 23` in `android/app/build.gradle`.
- Add to `android/app/src/main/AndroidManifest.xml` (inside `<manifest>`):
  ```xml
  <uses-permission android:name="android.permission.INTERNET"/>
  <uses-permission android:name="android.permission.RECORD_AUDIO"/>
  <uses-permission android:name="android.permission.CAMERA"/>
  <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
  <queries><intent><action android:name="android.intent.action.DIAL"/><data android:scheme="tel"/></intent></queries>
  ```
  and `android:usesCleartextTraffic="true"` on `<application>` while testing against `http://` (remove for production; use HTTPS).
- Edit `lib/config.dart` -> `apiBaseUrl` (`10.0.2.2` for the Android emulator, your PC's LAN IP for a real phone).
- `flutter run`

For iOS, add camera/microphone/photo usage descriptions to `Info.plist` and set up APNs for push.

## Privacy & security notes
- Anonymous complaints: the reporter is stored (so they can track their case and receive push
  notifications) but the officer-facing API strips name, phone and role.
- Every API call verifies the Firebase token; ownership is checked on every elder/complaint access.
- Evidence URLs from Firebase Storage are long unguessable links but not truly private. For production,
  serve evidence through the backend with short-lived signed URLs.
- Case timeline notes are visible to the reporter - officers should not write internal-only remarks there.
- Before real use with real elderly people's data, get a security review and check Bangladesh data-protection
  requirements with your institution.

## Ideas for the "Future scope" section
Location-based SOS (`geolocator` + lat/lng columns on `sos_requests`), Bangla localisation (`flutter_localizations`),
phone-number login (Firebase Phone Auth), AI risk scoring on `wellbeing_checks` + complaints, video calls.
