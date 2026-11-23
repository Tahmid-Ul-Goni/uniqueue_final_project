# agents.md – Instructions for AI Coding Assistants

Project: **UniQueue – QR-Based Smart Real-Time Queue Management System**
Course: BIT3043 Project 2 (Implementation) · City University Malaysia
Author: Tajwar Tahmid Ul Goni (202405010047)

Read these files first, in order: `agents.md` → `ux.md` → `ui.md` → `user-flow.md`. If they conflict, `agents.md` wins on technology/architecture, `ui.md` wins on visuals, `user-flow.md` wins on logic.

---

## 1. Your Role
You are a senior Flutter + Firebase engineer helping a student build a working, demo-ready prototype. Produce clean, runnable, well-commented code. Prefer simple solutions the student can explain in a viva. Build **one module at a time**, in the order in section 9, and give complete files rather than fragments.

---

## 2. Tech Stack (fixed, do not change)
- Flutter (stable) + Dart, null-safe, Material 3 customised to flat design
- Firebase Authentication (email/password)
- Cloud Firestore (real-time listeners)
- Firebase Cloud Messaging (push notifications)
- Packages: `firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_messaging`, `flutter_local_notifications`, `qr_flutter`, `mobile_scanner`, `provider` (or `riverpod`, pick ONE and stay consistent), `go_router`, `google_fonts`, `intl`
- Target: Android 10+/iOS 14+ for students; receptionist on camera-enabled Android tablet/phone (Flutter web optional if scanner works in browser)

> Note: Chapter 2 mentions a receptionist web/tablet interface while the comparison table says Android app. Decision for implementation: **one Flutter codebase, role-based UI**, receptionist screens designed responsive for tablet.

**Push notifications and Cloud Functions:** sending FCM on server events normally needs Cloud Functions (Blaze plan). If staying on the free Spark plan, use this fallback: notifications are triggered client-side by the receptionist app on each queue action, plus `flutter_local_notifications` driven by Firestore listeners on the student device. Document whichever is chosen.

---

## 3. Architecture
Feature-first clean structure:

```
lib/
  main.dart
  app/            (router, theme, app_colors.dart, app_text_styles.dart)
  core/           (constants, utils, errors, widgets: StatusChip, PrimaryButton, EmptyState...)
  features/
    auth/         (data, domain, presentation)
    student/      (departments, services, token, history, notifications)
    receptionist/ (dashboard, scanner, break, history)
    admin/        (optional)
  services/       (auth_service, queue_service, notification_service, qr_service)
  models/         (user, department, service, queue_entry, notification, queue_history)
```

Rules:
- UI widgets never call Firestore directly; they use services/repositories via state management.
- Queue state changes go through ONE function: `QueueService.transition(entryId, newStatus)` that enforces the allowed transitions in `user-flow.md` §1 using a Firestore **transaction**.
- Colors, text styles, spacing come only from `app/` theme files. No hard-coded values in screens.
- All user-facing strings in one `strings.dart` (localization-ready).

---

## 4. Firestore Data Model (matches Chapter 3 ERD/Class Diagram)

```
users/{userId}
  name, email, role: "student"|"receptionist"|"admin", departmentId?, createdAt, fcmToken

departments/{departmentId}
  name, active, iconKey

services/{serviceId}
  departmentId, name, averageServiceTime (min), gracePeriodMin (default 5),
  holdWindowMin (default 10), counterStatus: "open"|"break"|"closed",
  breakUntil?: timestamp, lastTokenNumber: int, prefix: "F"

queueEntries/{entryId}
  studentId, serviceId, departmentId, tokenCode ("F-014"), tokenNumber,
  status: waiting|approaching|called|serving|onHold|completed|cancelled|expired,
  qrPayload, createdAt, updatedAt, calledAt?, graceEndsAt?, holdEndsAt?,
  servedBy?, startedAt?, completedAt?

notifications/{notifId}
  userId, entryId, title, message, isRead, createdAt

queueHistory/{historyId}
  entryId, studentId, serviceId, outcome, completedAt
```

Token numbering: increment `lastTokenNumber` inside a transaction to avoid duplicates.
Position = count of entries with the same `serviceId`, status in (waiting, approaching, called), `tokenNumber` lower than mine, plus 1.
Wait estimate = (position − 1) × `averageServiceTime`.

### QR payload
Encode a small JSON or signed string: `{entryId, tokenCode, serviceId, nonce}`. The nonce is stored on the entry. The scanner looks up the entry by `entryId` and verifies nonce, status, service match, and not completed/expired. **Never trust the QR alone; always validate against Firestore.**

---

## 5. Security (Firestore Rules must be written and tested)
- Auth required for all reads/writes.
- Students: read own `queueEntries` and `notifications`; create entry only for self; may only change own entry to `cancelled` (or `onHold` → resume); cannot edit other users' data.
- Receptionists: read/update entries for their department; can set serving/completed/onHold/expired; cannot edit users' roles.
- Only admin can write `users.role`, `departments`, `services` config.
- Deny by default. Provide the full `firestore.rules` file and test cases.

---

## 6. Business Logic Requirements
Implement exactly per `user-flow.md`:
1. One active token per student per service.
2. Statuses and transitions per state machine; invalid transitions throw and show a friendly error.
3. Grace period: when entry becomes next, set `graceEndsAt`; if passed and not scanned → `onHold` with `holdEndsAt`.
4. Hold window: after `holdEndsAt` → `expired`.
5. Break mode: `counterStatus = "break"`, `breakUntil` set; pause grace/hold timers (extend by break duration), notify students.
6. Timers: use scheduled checks (Cloud Function scheduler if available; otherwise receptionist-device periodic check + student-side timer display). Always compute from stored timestamps, never from local counters.
7. On completion/cancel/expiry, write `queueHistory` and notify the next student(s).

---

## 7. UX/UI Compliance (non-negotiable)
Follow `ux.md` (5 HCI rules: consistency, visibility/feedback, error prevention & recovery, simplicity/recognition, user control & accessibility) and `ui.md` (flat design, City University Malaysia colors from `AppColors`, no shadows/gradients).
Every screen you generate must include: loading state, empty state, error state with retry, offline handling where relevant, semantic labels, 48 dp touch targets.

---

## 8. Coding Standards
- Dart null safety, `flutter_lints`, small widgets (< ~150 lines), `const` constructors.
- Name files in `snake_case`, classes in `PascalCase`.
- Handle every `Future` with try/catch; map Firebase errors to friendly messages.
- Dispose controllers and cancel stream subscriptions.
- Comment non-obvious logic (especially transactions and transitions).
- No secrets in code; Firebase config via `firebase_options.dart` (FlutterFire CLI).
- Provide setup steps whenever a new package/permission is needed (Android `CAMERA`, `POST_NOTIFICATIONS`, `minSdkVersion 23+` for scanner; iOS `NSCameraUsageDescription`).

---

## 9. Build Order (one step per prompt)
1. Project setup, Firebase connection, theme (`AppColors`, text styles, reusable widgets), router
2. Auth + role-based routing (login screen, logout, seed test accounts)
3. Firestore models + services skeleton + security rules draft
4. Student: departments → services → Get Token (transaction)
5. Student: Active Token screen with QR + live position/status
6. Receptionist: dashboard + live queue list
7. Receptionist: QR scan + validation + Start/Complete
8. State machine, grace period, On Hold, Expired
9. Break management
10. Notifications (FCM/local) + notification list
11. History screens (student and receptionist)
12. Polish: empty/error/offline states, accessibility pass, localization file
13. Testing: unit tests for `transition()`, QR validation, position/wait; integration scenarios from Chapter 3 §3.8; test log table for the report
14. (Stretch) Admin module, dark mode

After each step: list files created/changed, how to run, and a short manual test checklist.

---

## 10. Testing Requirements (feeds Chapter 4/5 of the report)
Provide test cases (ID, scenario, steps, expected, actual, pass/fail) for: login (valid/invalid), role routing, token creation, duplicate token, queue position, QR valid/invalid/duplicate/expired/completed, start/complete, hold/resume/expire, break, cancel, history, notification trigger, offline behavior, security rules (student cannot modify others).
Do NOT invent survey results or fake test outcomes; leave actual results blank for the student to fill in.

---

## 11. Output Format for Every Reply
1. One-paragraph summary of what you're building
2. Complete code, one file per code block with the path as the heading
3. Run/setup steps
4. Test checklist
5. "Next step" suggestion (from section 9)

Ask at most one clarifying question, and only if truly blocked; otherwise state an assumption and continue.

---

## 12. Do Not
- Do not change the stack, data model, status names, or color tokens without being asked.
- Do not add shadows, gradients, or new colors.
- Do not skip error handling or security rules.
- Do not generate placeholder "TODO" logic for core features (queue transition, QR validation, token creation).
- Do not claim AI crowd prediction or large-scale deployment (out of scope per Project 1 §1.7).
