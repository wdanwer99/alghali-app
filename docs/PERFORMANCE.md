# Performance on a low-end phone (M7)

PLAN §2 M7 asks for profiling on a low-end Android emulator: Android 8, 2 GB. Measured
2026-10-15 with `pnpm perf:e2e` (profile builds, against alghali-dev; the buyer as a guest,
the partner as the demo shop owner, reading only).

**The phone:** an Android 8.0 emulator (API 26, x86_64) with 2 GB of memory, 2 processor cores
and a 720 × 1280 screen. It draws with SwiftShader, which uses the processor instead of a
graphics chip, so drawing times here are a worst case: real phones, even cheap ones, draw with
a graphics chip.

**What was done:** each app is started cold, then the test scrolls its main screens up and down
the way a thumb flings them — the buyer's home, the street with its shops and the search
results for "لمبات" with their photos; the partner's shop home, orders and stock with photos.

## Results

| | Buyer | Partner |
|---|---|---|
| First frame after a cold start | 0.9 s | 0.6–1.2 s (0.8 s typical) |
| Frames measured while scrolling | 1,726 | 1,634 |
| **App work per frame** (Dart: build and layout), average / 90% of frames / 99% / worst | 0.6 / 1.0 / 4.3 / 14.5 ms | 0.8 / 1.5 / 4.2 / 17.3 ms |
| Frames over the 16.7 ms budget for app work | 0 | 1 |
| **Drawing per frame** (raster), average / 90% / 99% / worst | 10.9 / 17.2 / 30.6 / 142 ms | 10.2 / 17.1 / 24.1 / 171 ms |
| Frames over the 16.7 ms budget for drawing | 327 (19%) | 277 (17%) |
| Memory in use after scrolling (PSS) | 109–119 MB | 97–117 MB |
| Download size (release APK, per processor type) | about 22–25 MB | 22.2 MB (32-bit), 24.3 MB (64-bit) |

## What it means

- **The apps start in about a second** and use about a twentieth of a 2 GB phone's memory, so
  Android won't close other apps to make room for them, or close ours as soon as the phone is
  busy.
- **The apps' own work is far inside the budget**: about 1 ms of the 16.7 ms each frame has,
  with almost no frame over it. Screens, lists and state are not what limits smoothness.
- **Drawing is what costs**, about 10 ms a frame, and during fast flings about one frame in
  six takes longer than 16.7 ms on this software-drawn emulator. On a real phone the graphics
  chip does this work; on the cheapest chips a fast fling may still stutter now and then. The
  worst single frames (0.14–0.17 s) come when a screen first opens and its photos are decoded.
- **What keeps drawing cheap**, and should stay that way: list photos are small thumbnails
  (160 px, D-126) decoded at the size they are shown (`cacheWidth`); M7 did the same for the
  partner app's job photos and photo-request tiles, which decoded 1600 px photos into 72 px
  tiles. No blur effects, few shadows, and the street strip is a single painter.

## Repeat it

```sh
# an emulator or phone connected; for the low-end case, an Android 8 (API 26) x86_64 image
# with hw.ramSize=2048 and hw.cpu.ncore=2, started with -gpu swiftshader_indirect
pnpm perf:e2e -- -d emulator-5554                 # both apps
pnpm perf:e2e -- -d emulator-5554 --only partner  # one app
```

Numbers move by about ±20% between runs on an emulator (the start-up most); compare runs on the
same machine, and look at real phones before reading much into a small change.
