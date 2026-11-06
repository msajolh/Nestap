# Nestap App · Screen-by-Screen Wireframes

The UX follows the patterns people know from leading smart-home apps:
- the home first, with rooms as filters
- one tap to switch a device, another tap for its full controls
- "If / Then" scene building
- an energy history for metered devices

The visual language is Nestap's own (navy + cyan, Lato, pill buttons, soft glow on active devices). Code lives in `apps/mobile/lib/features/`.

**Status:** ✅ built in the first app commit · 🆕 added in this pass.

| # | Screen | Route | Widget | Status |
|---|--------|-------|--------|--------|
| 1 | Splash | `/splash` | `SplashPage` | ✅ |
| 2 | Welcome (onboarding) | `/welcome` | `WelcomePage` | 🆕 |
| 3 | Sign in: contact / code | `/sign-in` | `SignInPage` | ✅ |
| 4 | Home dashboard | `/home` | `HomeDashboardPage` | ✅ (bell + badge 🆕) |
| 5 | Device control | `/home/devices/:id` | `DeviceDetailPage` | ✅ (schedule, settings, energy entry points 🆕) |
| 6 | Device settings | `/home/devices/:id/settings` | `DeviceSettingsPage` | 🆕 |
| 7 | Schedules (timers) | `/home/devices/:id/timers` | `DeviceTimersPage` | 🆕 |
| 8 | Energy | `/home/devices/:id/energy` | `EnergyPage` | 🆕 |
| 9 | Add device | `/home/add-device` | `AddDevicePage` | ✅ |
| 10 | Notifications | `/home/notifications` | `NotificationsPage` | 🆕 |
| 11 | Scenes and automations | `/scenes` | `ScenesPage` | ✅ (create button 🆕) |
| 12 | Scene / automation editor | `/scenes/new?kind=` | `RuleEditorPage` | 🆕 |
| 13 | Me | `/profile` | `ProfilePage` | ✅ (home management link 🆕) |
| 14 | Home management: rooms + members | `/profile/home` | `HomeManagementPage` | 🆕 |

## Navigation map

```
            ┌──────────┐ first launch ┌─────────┐        ┌─────────┐
  launch ──►│  Splash  │─────────────►│ Welcome │───────►│ Sign in │
            └────┬─────┘              └─────────┘        └────┬────┘
                 │ session found                              │ verified
                 ▼                                            ▼
   ┌─────────────────────────── App shell ──────────────────────────────┐
   │  [Home]                    [Scenes]                 [Me]           │
   │   ├─ Notifications          └─ Editor (scene/auto)   └─ Home mgmt  │
   │   ├─ Add device                                                    │
   │   └─ Device ─┬─ Settings                                           │
   │              ├─ Schedules                                          │
   │              └─ Energy                                             │
   └────────────────────────────────────────────────────────────────────┘
   Phone: bottom bar · Tablet: rail · Desktop: extended rail with logo
```

## Design system (summary)

| Element | Spec |
|---------|------|
| Colors | Brand `#43C6DB`, CTA `#00D3F3` + navy text, navy `#101828`, ink `#030712`, grays from nestap.net |
| Type | Lato. Titles 800–900 weight, body 400, labels 700 |
| Shapes | Pill buttons and chips. Cards 20 px corners. Big control buttons 28 px |
| Elevation | Flat cards with a 1 px outline. Only "on" controls get a cyan glow shadow |
| Motion | 200 ms color and gradient changes on toggles, selection haptic on every toggle |
| Spacing | 4 / 8 / 12 / 16 / 24 / 32 / 48. Page padding 16 phone, 24 tablet, 32 desktop |
| States | Every async screen has loading (spinner), error (icon + message + "Try again") and empty (icon + hint + action) |

---

## 1 · Splash ✅

```
┌──────────────────────────┐
│░░░░░░░░ navy → ink ░░░░░░│
│                          │
│                          │
│       ⌂)) nestap         │  logo 56 px
│                          │
│           ◌              │  cyan spinner
│                          │
│                          │
└──────────────────────────┘
```

Shows only while the stored session is checked. Leaves automatically.

## 2 · Welcome 🆕

```
┌──────────────────────────┐
│ ⌂)) nestap        Skip   │
│                          │
│        ╭────────╮        │
│     ╭──┤  ⏻  ⏻  ├──╮     │  layered gradient discs
│     │  ╰────────╯  │     │  with feature icons
│     ╰──────────────╯     │
│                          │
│  Control every switch    │  title 28/900
│  Lights, sockets and     │
│  curtains, from anywhere │  body, gray-300
│                          │
│        ●  ○  ○           │  page dots (active = cyan pill)
│ ┌──────────────────────┐ │
│ │       Next  →        │ │  cyan pill CTA
│ └──────────────────────┘ │
└──────────────────────────┘
```

- 3 slides: **Control every switch** → **Scenes that set the mood** → **Know your energy**. On the last slide the button reads "Get started".
- Shown once, then remembered (`onboarding.seen`).
- Tablet/desktop: slide art on the left, text and button on the right.

## 3 · Sign in ✅

```
Step 1                           Step 2
┌──────────────────────────┐    ┌──────────────────────────┐
│ ⌂)) nestap               │    │ ⌂)) nestap               │
│                          │    │                          │
│ Welcome home             │    │ Check your messages      │
│ Sign in or create an     │    │ We sent a 6-digit code   │
│ account…                 │    │ to you@example.com.      │
│ ┌──────────────────────┐ │    │ ┌──────────────────────┐ │
│ │@ Email or phone      │ │    │ │🔒 1 2 3 4 5 6        │ │
│ └──────────────────────┘ │    │ └──────────────────────┘ │
│ ┌──────────────────────┐ │    │ ┌──────────────────────┐ │
│ │      Send code       │ │    │ │ Verify and continue  │ │
│ └──────────────────────┘ │    │ └──────────────────────┘ │
│                          │    │  Use a different email   │
└──────────────────────────┘    └──────────────────────────┘
Tablet: [ navy brand panel "The Touch of a Modern Home" | form ]
```

## 4 · Home dashboard ✅ (bell 🆕)

```
┌──────────────────────────┐
│ My Home ▾          🔔²   │  home switcher · notifications badge
│ ╭──────────────────────╮ │
│ │ 4        5/7    1066 W│ │  navy hero summary card
│ │ devices  online using │ │
│ │ on              now   │ │
│ ╰──────────────────────╯ │
│ (All)(Living)(Bedroom)(K…│  room chips, horizontal scroll
│ ┌──────────┐┌──────────┐ │
│ │ ◉    (⏻) ││ ○    (⏻) │ │  ◉ = glowing icon when on
│ │          ││          │ │
│ │Living Rm ││Bedroom Sw│ │
│ │Living·2/3││Bedroom·Of│ │
│ └──────────┘└──────────┘ │
│ ┌──────────┐┌──────────┐ │
│ │ ◉    (⏻) ││ ○     ☁̸  │ │  offline: dimmed + cloud icon
│ │TV Socket ││Garage Sw │ │
│ │Living·86W││Offline   │ │
│ └──────────┘└──────────┘ │
│              [+ Add device]  extended FAB (phone)
├──────────────────────────┤
│  ⌂ Home   ✦ Scenes   ☺ Me│
└──────────────────────────┘
```

- Tap a card → device control. Tap ⏻ → toggles every channel (optimistic, haptic).
- Pull to refresh. Grid columns follow width (max 240 px per card).
- Empty room: "No devices here" + Add device.

## 5 · Device control ✅ (entry points 🆕)

```
Switch (3-gang)                   Socket with metering
┌──────────────────────────┐    ┌──────────────────────────┐
│ ←  Living Room Lights ⏱ ⚙│    │ ←  TV Socket        ⏱ ⚙ │
│ Living Room · 2 of 3 on  │    │ Living Room · 86 W       │
│ ┌──────────┐┌──────────┐ │    │ ┌──────────────────────┐ │
│ │░░  ⏻  ░░││    ⏻     │ │    │ │░░░░░░░  ⏻  ░░░░░░░░░│ │
│ │░Switch 1░││ Switch 2 │ │    │ │░░░░░░  Power ░░░░░░░│ │
│ │░░  On ░░░││   Off    │ │    │ │░░░░░░░  On  ░░░░░░░░│ │
│ └──────────┘└──────────┘ │    │ └──────────────────────┘ │
│ ┌──────────┐             │    │ ┌──────┐┌──────┐┌──────┐ │
│ │░░  ⏻  ░░│             │    │ │Power ││Volt  ││Curr  │ │
│ │░Switch 3░│             │    │ │86.4 W││229.8V││0.38 A│ │
│ └──────────┘             │    │ └──────┘└──────┘└──────┘ │
│ ( All off )( All on    ) │    │ ┌──────────────────────┐ │
│                          │    │ │ ⚡ Energy usage     › │ │ 🆕
└──────────────────────────┘    │ └──────────────────────┘ │
                                └──────────────────────────┘
Light: big button + brightness slider · Curtain: Open / Stop / Close + position slider
⏱ = Schedules 🆕 · ⚙ = Settings 🆕 · Offline: red banner, controls disabled
```

## 6 · Device settings 🆕

```
┌──────────────────────────┐
│ ←  Device settings       │
│ ╭──────────────────────╮ │
│ │ ◉  Living Room Lights│ │  header card
│ │    Living Room       │ │
│ ╰──────────────────────╯ │
│ ┌──────────────────────┐ │
│ │ ✎ Name     Living R… ›│ │  → rename dialog
│ │ ▣ Room     Living Ro…›│ │  → room bottom sheet
│ │ ⏱ Schedules         ›│ │
│ │ ⚡ Energy            ›│ │  metering devices only
│ └──────────────────────┘ │
│ DEVICE INFO              │
│ ┌──────────────────────┐ │
│ │ Device ID  nd_li… ⧉  │ │  copy to clipboard
│ │ Product    nalite_d6 │ │
│ │ Connection Tuya cloud│ │
│ └──────────────────────┘ │
│ ┌──────────────────────┐ │
│ │    🗑 Remove device   │ │  red outline → confirm dialog
│ └──────────────────────┘ │
└──────────────────────────┘
```

## 7 · Schedules 🆕

```
┌──────────────────────────┐
│ ←  Schedules             │
│ ┌──────────────────────┐ │
│ │ 07:30           [●═] │ │  big time, enable switch
│ │ Weekdays · Turn on   │ │
│ └──────────────────────┘ │  swipe left → delete
│ ┌──────────────────────┐ │
│ │ 23:00           [═○] │ │
│ │ Every day · Turn off │ │
│ └──────────────────────┘ │
│                          │
│           [+ Add schedule]  FAB
└──────────────────────────┘

Add schedule (bottom sheet)
┌──────────────────────────┐
│        ─────             │
│  New schedule            │
│ ┌──────────────────────┐ │
│ │        07:30         │ │  tap → time picker
│ └──────────────────────┘ │
│ (M)(T)(W)(T)(F)(S)(S)    │  day chips; none = once
│ [  Turn on  |  Turn off ]│  segmented
│ ┌──────────────────────┐ │
│ │        Save          │ │
│ └──────────────────────┘ │
└──────────────────────────┘
```

## 8 · Energy 🆕

```
┌──────────────────────────┐
│ ←  Energy · TV Socket    │
│ [ Day | Week | Month ]   │  segmented
│                          │
│ 12.84 kWh                │  total for range (900 weight)
│ This week                │
│ ╭──────────────────────╮ │
│ │ 2.10 kWh · Wed       │ │  selected bar readout
│ │     ▇                │ │
│ │  ▅  █  ▃     ▆       │ │  rounded bars, selected = cyan
│ │  █  █  █  ▂  █  ▄  ▁ │ │  others = cyan 35 %
│ │  M  T  W  T  F  S  S │ │
│ ╰──────────────────────╯ │
│ ┌──────────┐┌──────────┐ │
│ │ Average  ││ Peak     │ │
│ │ 1.83 kWh ││ 2.10 kWh │ │
│ └──────────┘└──────────┘ │
└──────────────────────────┘
```

Tap or drag across bars to inspect them. Day = 24 hourly bars, Week = 7, Month = 30.

## 9 · Add device ✅

```
Form                             Searching               Success
┌──────────────────────────┐  ┌──────────────────┐  ┌──────────────────┐
│ ←  Add device            │  │                  │  │        ✔         │
│ ┌──────────────────────┐ │  │       ◯◌         │  │   Device added   │
│ │👆 Hold any button 5 s │ │  │  Looking for     │  │ It is ready to   │
│ │ until light blinks   │ │  │  your device…    │  │ use.             │
│ └──────────────────────┘ │  │  Keep your phone │  │ ( Open device )  │
│ [▣ Room            ▾]    │  │  close…          │  └──────────────────┘
│ [📶 Wi-Fi (2.4 GHz)  ]    │  │   ( Cancel )     │
│ [🔒 Password       👁]    │  └──────────────────┘
│ ( Start pairing )        │
└──────────────────────────┘
```

## 10 · Notifications 🆕

```
┌──────────────────────────┐
│ ←  Notifications  Mark all read
│ TODAY                    │
│ ┌──────────────────────┐ │
│ │ ⚠  Water Heater    ● │ │  alarm = red badge; ● unread
│ │    Overload — turned │ │
│ │    off.       10:42  │ │
│ ├──────────────────────┤ │
│ │ ☁̸  Garage Switch   ● │ │
│ │    went offline 09:15│ │
│ └──────────────────────┘ │
│ EARLIER                  │
│ ┌──────────────────────┐ │
│ │ ✦  Good Morning ran  │ │
│ │    Yesterday 07:00   │ │
│ └──────────────────────┘ │
└──────────────────────────┘
```

Tap → marks it read. Empty state: "You're all caught up".

## 11 · Scenes and automations ✅ (create 🆕)

```
┌──────────────────────────┐
│ Scenes              [+]  │  + → Scene / Automation menu
│ Tap-to-run               │
│ ┌──────────┐┌──────────┐ │
│ │ ☀        ││ ⇥        │ │  colored cards, tap runs
│ │Good      ││Leave Home│ │  (spinner while running)
│ │Morning   ││          │ │
│ └──────────┘└──────────┘ │
│ Automations              │
│ ┌──────────────────────┐ │
│ │ ⟳ Lights on at sunset│ │
│ │   Every day…    [●═] │ │
│ ├──────────────────────┤ │
│ │ ⟳ Heater off 11 PM   │ │
│ │   Every day…    [═○] │ │
│ └──────────────────────┘ │
└──────────────────────────┘
```

## 12 · Scene / automation editor 🆕

```
┌──────────────────────────┐
│ ✕  New automation   Save │
│ [ Name                 ] │
│ ● ● ● ● ●  ☀ ⇥ 🎬 🛏 ⌂   │  color + icon pickers (scenes)
│                          │
│ IF  (Any ▾)              │  automations only
│ ┌──────────────────────┐ │
│ │ ⏰ 18:30 · Weekdays ✕ │ │
│ │ ◉ Hall PIR is On   ✕ │ │
│ │ + Add condition      │ │
│ └──────────────────────┘ │
│ THEN                     │
│ ┌──────────────────────┐ │
│ │ ◉ Living Lights · On ✕│ │
│ │ ⌛ Wait 5 min       ✕ │ │
│ │ ◉ Living Lights · Off✕│ │
│ │ + Add action         │ │
│ └──────────────────────┘ │
└──────────────────────────┘
Add condition sheet: [⏰ Schedule] [◉ When a device changes]
Add action sheet:    [◉ Control a device] [⌛ Delay]
Device picker → action list (Turn on / Turn off / Open / Close)
```

Validation: a name, at least one action, and for automations at least one condition. Problems show inline. Save stays enabled.

## 13 · Me ✅ (home management 🆕)

```
┌──────────────────────────┐
│ Me                       │
│ ╭──────────────────────╮ │
│ │ (DU) Demo User       │ │
│ │      demo@nestap.net │ │
│ ╰──────────────────────╯ │
│ ┌──────────────────────┐ │
│ │ ⌂ Home management   ›│ │ 🆕
│ │ Appearance           │ │
│ │ [System|Light|Dark]  │ │
│ │ 🔔 Notifications    ›│ │
│ │ ⓘ About Nestap      ›│ │
│ └──────────────────────┘ │
│ ( ⇥ Sign out )           │
└──────────────────────────┘
```

## 14 · Home management 🆕

```
┌──────────────────────────┐
│ ←  My Home               │
│ ROOMS             + Add  │
│ ┌──────────────────────┐ │
│ │ ▣ Living Room  3 dev ⋮│ │  ⋮ → Rename / Delete
│ │ ▣ Bedroom      1 dev ⋮│ │
│ │ ▣ Kitchen      1 dev ⋮│ │
│ └──────────────────────┘ │
│ MEMBERS                  │
│ ┌──────────────────────┐ │
│ │ (DU) Demo User  Owner│ │
│ │ (RA) Rahim     Member│ │
│ └──────────────────────┘ │
│ ( 👤+ Invite member )     │ → sheet with code K7Q2-9XZD [Copy]
└──────────────────────────┘
```
