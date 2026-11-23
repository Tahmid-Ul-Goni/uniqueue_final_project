# UniQueue – UI Design System (ui.md)

Style: **Flat design** · Brand: **City University Malaysia** · Framework: Flutter (Material 3, heavily customised)

---

## 1. Flat Design Rules

- No drop shadows, no gradients, no glossy/3D effects, no textures.
- Separate surfaces with **solid fills and 1 px borders**, not elevation. Set `elevation: 0` and `shadowColor: transparent` on all widgets.
- Simple geometric icons (outlined, 2 px stroke, one icon family: Material Symbols Rounded or Lucide).
- Generous whitespace, strong typographic hierarchy.
- Motion is minimal: 150–250 ms fades/slides only, no bounce.

---

## 2. Color Palette (City University Malaysia branding)

> **Verify before final submission:** these hex values are based on the university's blue-and-red identity. Check them against the official logo or brand guideline from the university and edit ONLY the values below. The whole app reads from this one token file (`app_colors.dart`).

### Brand
| Token | Hex | Use |
|---|---|---|
| `primary` | `#0A2A66` | App bars, primary buttons, active nav, headings |
| `primaryDark` | `#071D49` | Pressed state |
| `primarySoft` | `#E6ECF7` | Selected chips, soft backgrounds |
| `accent` | `#D32F2F` | Small highlights, badges, key CTA accents (use sparingly) |

### Neutrals
| Token | Hex | Use |
|---|---|---|
| `background` | `#F5F7FA` | Screen background |
| `surface` | `#FFFFFF` | Cards, sheets |
| `border` | `#D9DEE7` | 1 px card/input borders |
| `textPrimary` | `#12202F` | Body, titles |
| `textSecondary` | `#5B6776` | Captions, hints |
| `disabled` | `#B8C0CC` | Disabled controls |

### Status colors (always paired with icon + text label)
| Status | Fill | Text/Icon | Icon |
|---|---|---|---|
| Waiting | `#E6ECF7` | `#0A2A66` | `schedule` |
| Approaching | `#FFF3CD` | `#7A5600` | `notifications_active` |
| Serving | `#DDF3E4` | `#14683A` | `support_agent` |
| On Hold | `#FFE6D0` | `#9A4A00` | `pause_circle` |
| Completed | `#E9ECEF` | `#3F4A56` | `check_circle` |
| Cancelled | `#FBE0E0` | `#9B1C1C` | `cancel` |
| Expired | `#EDE7F6` | `#4A2C82` | `timer_off` |

Feedback: success `#14683A`, warning `#9A4A00`, error `#B3261E`, info `#0A2A66`.
All text/background pairs must meet WCAG AA (4.5:1).

---

## 3. Typography

Font: **Inter** (fallback: Roboto). Use `google_fonts` or bundle the font.

| Style | Size / Weight | Use |
|---|---|---|
| Display | 32 / 700 | Token number (e.g. F-014) |
| H1 | 24 / 700 | Screen titles |
| H2 | 20 / 600 | Section headers |
| Body L | 16 / 400 | Main text |
| Body M | 14 / 400 | Secondary text |
| Label | 12 / 600 | Chips, badges, nav labels |

Line height 1.4–1.5. Never go below 12 sp. Respect system font scaling.

---

## 4. Spacing, Shape, Grid

- 8 dp spacing scale: 4, 8, 12, 16, 24, 32, 48.
- Screen side padding: 16 dp (phone), 24 dp (tablet).
- Radius: cards 12, buttons 10, chips 999 (pill), inputs 10, bottom sheets 16 (top only).
- Border: 1 px `border` on cards and inputs. Focus border 2 px `primary`.
- Minimum touch target 48×48 dp.
- Tablet receptionist layout: 2 panes (queue list left 40%, current service right 60%).

---

## 5. Components

**Buttons**
- Primary: solid `primary`, white text, height 52, full width, radius 10.
- Secondary: white fill, 1 px `primary` border, `primary` text.
- Destructive: solid `error` or outlined error for lower emphasis.
- Disabled: `disabled` fill, white text. Show loading as an inline small spinner inside button.

**Cards:** `surface` fill, 1 px border, 16 padding, no shadow.

**Status chip:** pill, status fill color, icon (16 dp) + label. Used identically in lists, token screen, history.

**Inputs:** label above field, 1 px border, helper/error text below, error uses red border + message + icon.

**Bottom navigation (student):** Home · Services · Token · Alerts · History. Active = `primary` icon + label with `primarySoft` pill indicator. (Receptionist: Queue · Scan · History.)

**Department card:** icon tile (primarySoft), name, "N waiting · about X min", chevron.

**Queue list item (receptionist):** token code (bold), student first name, service, status chip, waiting time. Swipe not required; use trailing overflow menu (Hold, Skip, Cancel).

**Dialogs/sheets:** flat, title + one-sentence body + two buttons (cancel left, confirm right).

**Snackbar:** dark `#12202F`, white text, optional action (Undo). 4 s.

**Banner:** full-width strip under app bar: offline (grey), break (orange), paused queue (blue).

**Skeleton loader:** flat `#E9ECEF` rounded blocks, no shimmer gradient (use opacity pulse).

---

## 6. Screen Specs

### 6.1 Login
- University logo top-centre, "UniQueue" H1, tagline "Skip the line, not your class."
- Email, password (show/hide), Login button, "Forgot password?" link.
- Inline validation, error banner on failure.

### 6.2 Student Home
- Greeting + name. If active token exists: large **Active Token card** at top (token code, status chip, position, wait). Otherwise: "No active token" prompt.
- Below: department cards grid (2 columns phone).

### 6.3 Service Selection
- Search bar, list of services under department headers, each showing queue size and counter status (Open / On break / Closed). Button **Get Token** on selection sheet.

### 6.4 Active Token (most important screen)
- Top: department + service.
- Centre: **QR code** (min 240 dp, white background, 16 dp quiet zone) with token code under it in Display style.
- Status chip + position "3rd in line" + "About 9 min" + progress bar (flat, `primary` on `primarySoft`).
- Contextual banner (grace period timer, hold notice, break notice).
- Actions: Cancel token (secondary/destructive), Need help.
- "Last updated just now" label.

### 6.5 Notifications
- List grouped by Today / Earlier; each item: icon, title, time, unread dot.

### 6.6 History
- List: date, service, token, final status chip, completion time; filter chips (All, Completed, Cancelled, Expired).

### 6.7 Receptionist Dashboard
- App bar: counter name + Break toggle.
- Top card: **Now Serving** (token, student first name, elapsed time, Complete button, Hold button).
- Main: Scan QR primary button (big, fixed bottom on phone, top-right on tablet).
- Queue list below with status chips; On Hold section collapsible.

### 6.8 QR Scan
- Full-screen camera, square frame guide, flashlight toggle, helper text "Align QR inside the frame".
- Result sheet slides up: ✔ Valid (student, service, **Start Service**) or ✖ error with reason and **Scan again**.

### 6.9 Break Sheet
- Duration options (10 / 15 / 30 / 60 min / custom), notice "Students will be told", Confirm.

---

## 7. Iconography & Illustration
- Outlined icons only. Empty states use a simple flat icon in `primarySoft` circle, no illustrations with gradients.
- University logo only on login, splash, and About.

---

## 8. Dark Mode
Optional/stretch. If built: background `#0E1624`, surface `#162133`, border `#26344A`, primary text `#E8EDF5`, brand `#6F93E6`. Keep flat rules.

---

## 9. Flutter Implementation Notes

```dart
// app_colors.dart – single source of truth
class AppColors {
  static const primary = Color(0xFF0A2A66);
  static const primaryDark = Color(0xFF071D49);
  static const primarySoft = Color(0xFFE6ECF7);
  static const accent = Color(0xFFD32F2F);
  static const background = Color(0xFFF5F7FA);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFD9DEE7);
  static const textPrimary = Color(0xFF12202F);
  static const textSecondary = Color(0xFF5B6776);
}
```
- Build `ThemeData` with `useMaterial3: true`, `elevation: 0`, `splashFactory: NoSplash.splashFactory` or subtle ink, card `shape` with 1 px border.
- Create reusable widgets: `StatusChip`, `PrimaryButton`, `QueueCard`, `DepartmentCard`, `TokenQrCard`, `AppBanner`, `EmptyState`, `SkeletonBox`.
- Never hard-code colors in screens; always use `AppColors` / theme.

---

## 10. UI Acceptance Checklist
- [ ] No shadows or gradients anywhere
- [ ] Only tokens from section 2 used
- [ ] Status chip identical on all screens
- [ ] Contrast AA, touch targets ≥ 48 dp
- [ ] QR ≥ 240 dp with white quiet zone
- [ ] Looks correct at 360 dp phone and 10" tablet
