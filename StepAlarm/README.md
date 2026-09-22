# Step Alarm — Phase 1

This is the "make it ring" phase. Nothing else has been built yet — no step
counting, no settings, no alarm list. That's intentional per the build brief.

## Why this is source files, not a `.xcodeproj`

This was written on Windows with no Xcode, no macOS, and no physical iPhone
attached. Hand-crafting an Xcode `.pbxproj` file blind is a good way to hand
you a corrupted project, and there's no way to compile-check any of this
from here anyway — AlarmKit and CMPedometer both require a real device per
Apple's own docs, so a simulator wouldn't have proven anything either.
Instead: create the project yourself in Xcode (takes 30 seconds) and drop
these files in.

## Setup

1. On your Mac, open Xcode 26 → **File → New → Project → iOS → App**.
   - Product Name: `StepAlarm`
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Uncheck "Include Tests" if you want, doesn't matter for Phase 1.
2. Set the deployment target to **iOS 26.0** (project settings → General →
   Minimum Deployments).
3. Delete the auto-generated `ContentView.swift` and `StepAlarmApp.swift`
   Xcode created, then drag in the files from this folder's `StepAlarm/`
   subdirectory:
   - `StepAlarmApp.swift`
   - `ContentView.swift`
   - `AlarmScheduler.swift`
   - `AlarmMetadata.swift`
   - `StopIntent.swift`
   - `LiveActivityController.swift`
   - `Theme.swift`, `AlarmStore.swift`, `WalkSession.swift`,
     `WakeUpView.swift`, `AddAlarmView.swift`
4. Add the required permission strings: target → **Info** tab:
   - `NSAlarmKitUsageDescription` → e.g. "Step Alarm needs alarm access
     to wake you up." (Key name should be verified in Xcode's autocomplete —
     it may suggest the exact key if you start typing "Alarm".)
   - `NSMotionUsageDescription` → e.g. "Step Alarm counts your steps to turn
     the alarm off." (needed for the pedometer)
5. **Signing & Capabilities** tab → select your existing Apple Developer
   team. Do not create a new identifier — use what's already provisioned.
6. Build target: your physical iPhone (not simulator — AlarmKit and
   CMPedometer don't work there). Run.

## Setup — Live Activity validation (added per the design spec)

The design spec's Screen 3 needs a live step counter on the Lock Screen
without unlocking. That requires a **Widget Extension** target — Live
Activity UI can't live in the main app target.

7. **File → New → Target → Widget Extension.** Name it `StepAlarmWidget`.
   When Xcode asks, check "Include Live Activity" (or if it scaffolds a
   `TestAppAttributes.swift` / default widget files, delete those — we
   have our own).
8. Drag in from this folder's `StepAlarmWidget/` subdirectory:
   - `StepAlarmWidgetLiveActivity.swift`
   - `StepAlarmWidgetBundle.swift` (Xcode's template likely already made
     one of these — delete the template's version, keep this one)
9. Drag in `Shared/StepAlarmActivityAttributes.swift` and **check both
   target membership boxes** (StepAlarm app AND StepAlarmWidget extension)
   in the File Inspector on the right. This is the easy step to miss — if
   you skip it, expect "cannot find type in scope" or a silent runtime
   mismatch instead of a clean build error.
10. On the **main app target** (not the widget target): **Info** tab → add
    `NSSupportsLiveActivities` = **YES**. Without this, `Activity.request`
    throws immediately.
11. Also on the main app target: **Signing & Capabilities**, make sure the
    widget extension target is signed with the same team.

## A note on how AlarmKit actually renders the alert

The brief describes Phase 1 as needing "Full-screen alert UI with one Stop
button." With AlarmKit, you don't draw that screen yourself — the system
renders a Clock-app-style full-screen alert based on the
`AlarmPresentation.Alert` you configure (title + stop button), and it draws
over the lock screen / whatever app is foregrounded, independent of your
app's UI. `AlarmScheduler.swift` configures that presentation; there's no
separate SwiftUI view for the ringing state in this codebase.

## Confidence flag

I don't have a Mac in this environment to compile against the real AlarmKit
SDK, so I can't guarantee every type/method name here is exactly right —
this is a very new framework (iOS 26 / WWDC 2025) with limited footprint in
what I was trained on. The architecture is right: authorize once, build an
`AlarmAttributes`/`AlarmPresentation.Alert`, call
`AlarmManager.shared.schedule(id:configuration:)`, silence via an
in-process `LiveActivityIntent`. If Xcode's autocomplete disagrees with an
exact name (e.g. whether `AlarmConfiguration` nests under `AlarmManager`),
trust Xcode — jump to definition on `AlarmManager` and adjust. Apple's
official AlarmKit sample project and the WWDC25 "Wake up to the AlarmKit
API" session are the ground truth if anything doesn't compile.

## Phase 1 gate — all four must pass on a real iPhone

Tap "Set alarm 2 minutes from now," then within that window:

1. Lock the phone — alarm still rings at T+2min.
2. Force-quit the app from the app switcher — alarm still rings.
3. Turn on Silent mode — alarm still rings audibly.
4. Turn on a Focus mode — alarm still rings.

If any of these fail, that's the signal something fell back to a
notification-style path instead of a true AlarmKit-scheduled alarm — fix it
before moving to Phase 2 (step counting). Don't build UI or settings yet.

Once all four pass, let me know and I'll build Phase 2 (standalone
CMPedometer step counter screen).

## The hard technical question — validate this now too, not after Phase 1

The design spec calls for a live-updating step counter directly on the
Lock Screen, without unlocking or opening the app, driven by a Live
Activity attached to the alarm. This is the single riskiest unknown in
the whole project, and it needs a real-device answer before any of the
black/white/red UI gets built. There are two separate things to prove,
tested separately on purpose so a failure tells you which half broke:

**Test A — "counter-only."** Tap "Test A" in the app, then **lock the
phone immediately.** Watch the Lock Screen for the full 30 seconds.
- If the number visibly counts 1, 2, 3... up to 15 once per second: the
  core mechanism works.
- If it appears but freezes the moment you lock the phone: the update
  loop is getting suspended in the background. That means the real
  implementation must drive updates from CMPedometer's own step-delivery
  callback (which is designed to wake a suspended app for a physical
  event) instead of a timer loop — a fixable, known pattern, just
  different code than what's here now.
- If no Live Activity appears on the Lock Screen at all: check that
  `NSSupportsLiveActivities` is set, and that Settings → StepAlarm → Live
  Activities is enabled.

**Test B — "alarm + Live Activity together."** Tap "Test B." This
schedules the real AlarmKit test alarm for 30 seconds out AND starts the
same counter. Lock the phone. When the alarm fires:
- Does the live counter stay visible / update while the AlarmKit alert is
  ringing, or does AlarmKit's own full-screen alert cover it entirely?
- Does anything visually conflict or glitch?

**If both come back positive:** the design as written (live count on
Lock Screen, no unlock needed) is buildable — proceed with Phase 2/3 as
planned, feeding real CMPedometer data into this same Live Activity
mechanism instead of the timer loop.

**If it doesn't work:** the spec's own documented fallback applies — the
alarm screen shows a single "start walking" prompt, tapping it opens the
app, and the counter runs there instead of on the Lock Screen. Tell me
which result you got and I'll build whichever path is real.

### Confidence flag on this part specifically

Plain ActivityKit Live Activities updating ~once/sec from an in-process
loop is well-documented, stable API since iOS 16.1 — I'm confident in
`StepAlarmWidgetLiveActivity.swift` and the ActivityKit calls themselves.
What I'm genuinely unsure about is the *AlarmKit* side: whether an
AlarmKit-fired alarm is itself backed by a Live Activity you attach
custom content to, or whether (as built here) it's a fully independent
Live Activity that merely happens to fire alongside the alarm. Test B is
designed to surface that difference empirically, because I can't verify
it by reading documentation alone.

## How the app works now (walk to dismiss)

1. **+** adds an alarm: time, steps to dismiss (1–30), repeat days. Alarms are
   saved; the toggle schedules/cancels the real AlarmKit alarm; tap a row to
   edit; **Edit** shows delete buttons.
2. When it rings, the system alert has **Stop** and **Walk**.
   - **Walk** opens the app on the Wake Up screen. Real steps are counted
     (CMPedometer); reaching the goal silences the alarm.
   - **Stop** silences it, but it **rings again 20 seconds later** until the
     steps are done.
3. If the app is opened while an alarm is ringing, it jumps straight to the
   Wake Up screen.

### Quick test plan (real iPhone)

1. Tests → "Try the Wake Up screen" — steps count up by themselves, the alarm
   closes at 15.
2. Tests → "Ring a 15-step alarm in 15 seconds", lock the phone.
3. When it rings: tap **Stop** → it should ring again after ~20s.
4. Tap **Walk**, walk 15 steps → alarm stops, screen says "You're up!".
5. Add a real alarm 2 minutes ahead with 10 steps and repeat days; toggle it
   off/on; delete it with Edit.

Not built: the Lock Screen Live Activity is still only the Test A/B demo —
it does not show your real step count during an alarm.
