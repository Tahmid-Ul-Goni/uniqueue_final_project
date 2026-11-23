# UniQueue – UX Guidelines (ux.md)

Project 2 (Implementation) · BIT3043 · City University Malaysia
Stack: Flutter (Dart) + Firebase (Auth, Firestore, FCM) + `qr_flutter` + `mobile_scanner`

> Purpose: tell any AI tool or developer HOW the product should *behave and feel*.
> Companion files: `ui.md` (visuals), `user-flow.md` (screens/paths), `agents.md` (build rules).

---

## 1. UX Goals (from Project 1 objectives)

| Problem (Ch.1) | UX answer |
|---|---|
| Students wait physically, unsure of turn | Remote token + live position + estimated wait + push notification |
| Manual, error-prone staff work | One-tap scan → Serve → Complete; queue advances automatically |
| Late arrivals / breaks disrupt queue | Clear On Hold + grace period + Break mode, visible to both roles |

Success = a student gets a token in **≤ 3 taps**; a receptionist serves a student in **≤ 2 taps after scan**.

---

## 2. The Five HCI Rules Applied

Based on Shneiderman's Golden Rules and Nielsen's Heuristics, condensed into five rules. Every screen must pass all five.

### Rule 1 – Consistency
- Same status names everywhere: **Waiting, Approaching, Serving, On Hold, Completed, Cancelled, Expired**.
- Same color + icon + label per status on every screen and notification.
- Primary action is always bottom, full-width, same style. Back is always top-left.
- Same terms for both roles ("Token", not "ticket/number/slip").

### Rule 2 – Visibility of System Status & Feedback
- Student always sees: token number, position, status, estimated wait, last-updated indicator.
- Every tap gets feedback within 100 ms (pressed state), every network action shows a loader, then a success/error message.
- Real-time updates via Firestore listeners; no manual refresh needed.
- Offline banner: "You're offline. Queue info may be outdated."
- Notifications fire at: token created, **5 away**, **next**, **your turn**, put On Hold, grace period ending, queue paused (break), cancelled.

### Rule 3 – Error Prevention & Easy Recovery
- Confirm destructive actions only (Cancel token, Complete service, Start break). Never confirm harmless ones.
- One active token per student per service (block duplicates, explain why).
- QR scan results are explicit: **Valid / Invalid / Expired / Already used / Not your department**, each with a plain-language reason and next step.
- Undo available for Hold → Resume and accidental Complete (10 s snackbar "Undo").
- Error text format: *what happened + what to do next* (never raw error codes).

### Rule 4 – Simplicity & Recognition over Recall
- One main task per screen. Max 5 bottom-nav items for students, 3 for receptionist.
- Show options as cards with icons + labels; no hidden gestures required.
- Pre-fill and remember: last department, logged-in role.
- Short, plain English. No jargon (say "Hold", not "suspend entry").

### Rule 5 – User Control & Accessibility
- Students can cancel their token any time while Waiting/Approaching/On Hold.
- Receptionist can hold, resume, skip, or pause the queue any time.
- Accessibility: contrast ≥ 4.5:1, touch targets ≥ 48×48 dp, text scales to 200%, status never conveyed by color alone, semantic labels for screen readers, QR code has high-contrast white quiet zone.
- Support English now; keep strings in a localization file so Bahasa Melayu can be added.

---

## 3. Role-Based Experience

| Role | Device | Home | Core job |
|---|---|---|---|
| Student | Android/iOS phone | Active token or department list | Join, track, arrive, present QR |
| Receptionist | Tablet / phone / desktop browser with camera | Live queue dashboard | Scan, serve, complete, hold, break |
| Admin (optional/stretch) | Browser | Departments & users | Manage services and accounts |

After login, route automatically by `role` field in Firestore. Users never choose their role.

---

## 4. Queue Rules the UX Must Make Clear

- **Grace period:** when a student is called ("Approaching → your turn"), they have a countdown (default 5 min, configurable per service). Show the timer on both sides.
- **On Hold:** if the grace period ends or staff places a hold, the student keeps their place for a limited window (default 10 min) and sees a "Resume / I'm here" prompt. After that → Expired.
- **Break mode:** receptionist taps "Start break" with duration; students in that department see "Counter on break, back at HH:MM", wait estimates shift, and no one is penalised.
- **Estimated wait** = people ahead × `averageServiceTime` of the service; label it "about", never as a promise.

---

## 5. Microcopy Examples

| Situation | Text |
|---|---|
| Token created | "You're in the queue. Token F-014. About 12 min." |
| 5 away | "5 people ahead. Start heading to Finance Office." |
| Your turn | "It's your turn at Counter 2. Show your QR within 5 minutes." |
| On hold | "You're on hold. Tap Resume when you arrive." |
| Break | "Counter on break until 2:30 PM. Your place is safe." |
| Invalid QR | "This token isn't valid. Ask the student to open the latest token." |
| Offline | "No connection. Showing last known queue." |

---

## 6. Empty, Loading, and Error States (required for every list/screen)

- **Loading:** skeleton blocks (flat grey), not spinners alone.
- **Empty:** icon + one sentence + one action (e.g. "No history yet. Get your first token.").
- **Error:** message + Retry button.

---

## 7. Privacy & Trust

- Show only first name and token code on receptionist's public/TV views.
- Collect minimum data (name, university email, role).
- Tell users why notification permission is needed before the system prompt appears.

---

## 8. UX Acceptance Checklist

- [ ] Student gets a token in ≤ 3 taps from home
- [ ] Status is visible without scrolling on token screen
- [ ] Every action has feedback (loading → result)
- [ ] All 7 statuses use identical color/icon/label everywhere
- [ ] Invalid/duplicate/expired QR handled with clear message
- [ ] Offline and empty states exist
- [ ] Contrast and touch-target rules pass
- [ ] Works at 360 dp width and on a 10" tablet
