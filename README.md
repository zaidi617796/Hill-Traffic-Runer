# Daily Brain Workout

A daily puzzle break — a small suite of fun mini-games for Android. Play the
short Today's Workout, or enjoy any game in Free Play, and beat your own best
score.

**This build** — six playable games:

- **Sequence Memory** — watch the pattern of lights, then repeat it. How long
  can you go?
- **Number Slide** — the classic 3×3 sliding puzzle. Every puzzle is solvable,
  no rigged boards.
- **Color Word Clash** — the word says one colour, the ink is another. Tap the
  ink colour against the clock.
- **Odd One Out** — every tile looks the same, except one. Find it before the
  bar runs out.
- **Path Memory** — watch a path light up across the grid, then retrace it
  step by step.
- **Tube Sort** — pour the colours between test tubes until every tube
  holds a single colour. Every puzzle is generated solvable; your best is
  fewest moves, then fastest time.
- Memory Tiles and Spot the Difference are listed in the app as
  **Coming soon**.

Design notes:

- Dark stage, bright pieces — easy on the eyes, works fully offline.
- No lives, no energy. Timers appear only in the games that are about speed
  (Color Word Clash, Odd One Out). Soft fail, one-tap retry.
- Personal bests for every game; your day streak lives quietly on the
  My Progress screen, never pushed on the home screen.
- Ads, when they arrive in a later phase, will only appear at natural breaks —
  never in the middle of a game.

Built with Godot 4.3. GitHub Actions builds a debug-signed test APK on every
push to `main` (artifact: `DailyBrainWorkout-test-apk`).
