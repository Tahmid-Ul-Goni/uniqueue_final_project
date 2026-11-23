## UniQueue

Flutter app for the City University Malaysia QR-based queue system. It includes Firebase email/password sign-in and student self-registration, student token creation and live queue position, receptionist queue controls and QR scanning, history, in-app notifications, an admin setup dashboard, Firestore security rules, and Cloud Function source for push delivery.

The app is connected to Firebase project `uniqueue-8bd80`. Android and iOS are registered, and Firestore is set up in Singapore with the project's rules and indexes deployed. Follow [FIREBASE_SETUP.md](FIREBASE_SETUP.md) to enable Email/Password authentication if needed and seed the first administrator profile. That admin can then create departments, services, and profiles for Firebase Auth users. Do not share account passwords or service-account keys.

The Markdown product requirements are in `agents.md`, `ux.md`, `ui.md`, and `user-flow.md`.
