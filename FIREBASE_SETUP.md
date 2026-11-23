# Firebase setup for UniQueue

## Connected project

- Firebase project: `uniqueue-8bd80`
- Android application ID and iOS bundle ID: `com.cityuniversity.uniqueue`
- FlutterFire config: `lib/firebase_options.dart`
- Firestore default database: `asia-southeast1` (Singapore), deletion protection enabled
- Firestore rules and indexes: deployed

The generated Firebase client config is safe to keep in the app. Never share your Google password, access token, or a service-account private key.

## 1. Enable sign-in and provision starter data

Open the [UniQueue Firebase Console](https://console.firebase.google.com/project/uniqueue-8bd80/overview). Under **Authentication / Sign-in method**, enable **Email/Password** if it is not already enabled.

Create your first administrator account under **Authentication / Users**, copy its UID, and create a matching `users/{uid}` profile document in Firestore. This one-time bootstrap is manual because a client app must not grant itself administrator rights.

```json
{
  "name": "UniQueue Administrator",
  "email": "admin@city.edu.my",
  "role": "admin"
}
```

Sign into UniQueue with this account. Use its admin screen to create departments and queue services. Students can use **Create a student account** on the login screen; the app creates their Auth account and student profile together. For receptionists, first create the Auth account in Firebase Console, then use **Add user profile** in UniQueue and enter the account UID and department.

For a quick presentation demo, the admin screen can add a sample **Finance Office (Demo)** department and **Fee Enquiry (Demo)** service. Add your actual campus departments/services from the same screen before using the app with real users.

Account passwords stay in Firebase Authentication. Email/Password must be enabled before student sign-up will work.

## 2. Reconfigure Firebase apps (only if needed)

From this project folder, with Firebase CLI and FlutterFire CLI installed and the Firebase CLI signed in, run:

```powershell
flutterfire configure --project=uniqueue-8bd80 --platforms=android,ios
```

The app initializes Firebase from `DefaultFirebaseOptions.currentPlatform` in `lib/firebase_options.dart`. Web is not configured.

## 3. Redeploy Firestore rules and indexes

The current rules and indexes are deployed. To deploy changes from this workspace:

```powershell
firebase deploy --project=uniqueue-8bd80 --only firestore:rules,firestore:indexes
```

The rules deny access by default. Do not switch Firestore to test mode.

## 4. Run the app

```powershell
flutter pub get
flutter run
```

Use an Android emulator/device with Google Play services or an iOS simulator/device. Android's minimum API is 24; iOS targets version 15 or later.

## Push notifications

The app writes in-app notifications to Firestore. Cloud Function source under `functions/` sends FCM push notifications from a trusted server. Deploying Cloud Functions requires the Firebase Blaze plan and a linked billing account; usage beyond no-cost quotas may be billed. Push is not deployed or enabled yet. Do not upgrade billing unless you want server push. See [Firebase pricing plans](https://firebase.google.com/docs/projects/billing/firebase-pricing-plans) and [Cloud Functions setup](https://firebase.google.com/docs/functions/get-started).

If you choose to deploy server push, install dependencies and deploy:

```powershell
npm --prefix functions install
firebase deploy --project=uniqueue-8bd80 --only functions
```

For iOS push delivery, add an APNs authentication key in Firebase and enable Push Notifications in the Runner target's Xcode capabilities.
