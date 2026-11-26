# AGENTS.md — Velokity: Space Nonogram

## Product
- All-ages logic puzzle game. Mascot: Velokity, a cute astronaut cat — 2D, but it must feel alive like 3D.
- Modes: Nonogram main levels grouped in planet albums + "Rasi Bintang" daily puzzle (Star Battle, 1 star: one star per row, per column and per color region; stars never touch, not even diagonally).
- 3 lives per puzzle, no energy system. Soft currency: Coins. (Stars currency arrives in v1.1.)
- Release order: web portals first (CrazyGames, Playgama, itch.io), Android later.

## Tech (do not change without asking)
- Godot 4.7.x stable, GDScript only (C# cannot export to web). Renderer: Compatibility.
- Base resolution 720x1280 portrait, stretch mode canvas_items, aspect expand. On wide desktop screens keep the board centered with decorative space background on the sides (portals require the game to be playable on desktop landscape).
- Web export: single-threaded (thread support off). Initial download must stay <= 50 MB; aim <= 20 MB.
- Android later: target API 36.
- Autoloads: Events (signal bus), Save (Bridge Storage when available, otherwise user://save.json, versioned with migrations), Settings, Audio, Economy, Ads (interface + FakeAds), Analytics (local stub only, no personal data).
- All UI text through translations: res://i18n/strings.csv (key,en,id). A saved language choice takes priority, then the Bridge platform language when available, then the device language. Fallback en.
- Folders: scenes/, scripts/, ui/, art/ (generated), audio/ (generated), data/levels/, data/daily/, i18n/, tests/, tools/ (Python 3 stdlib only), docs/.

## Assets & legal
- Free and original only. Draw art in code (Polygon2D, Line2D, shaders, procedural textures) or as text pixel grids converted by tools/. No downloaded art, fonts or sounds unless the license is CC0/OFL/MIT and it is recorded in docs/CREDITS.md.
- Sounds: generate procedurally with a Python sfxr-style tool (tools/sfx.py).
- Forbidden: gambling, slot or casino themes and Zeus/Olympus imagery; paid random rewards; near-miss or "loss disguised as win" tricks; exchanging coins for real money; sexualized content; any promotion of or link to trading/crypto apps.
- Randomness only for visuals (combo effect theme). Rewards and multipliers depend on player performance.

## Feel ("alive")
- Velokity is a 2D cut-out rig (separate parts + Skeleton2D/AnimationPlayer or tweens): breathing idle, random blinks, eyes follow the pointer, spring secondary motion on ears/tail/helmet antenna, squash & stretch, 8 expressions (happy, proud, surprised, sad, thinking, sleeping, dancing, cheering).
- Juice: cells bounce when filled, lines glow when correct, small shake on a mistake, 3-layer parallax starfield, CPUParticles2D only (web-safe).
- Celebration tiers 1–4 (see ROADMAP T07). Calm Mode setting reduces shake, flashes and vibration and shortens animations. Never more than 3 flashes per second. Anything >= 2 s is skippable after 1 s.

## Monetization rules (behind Ads/Economy interfaces)
- Rewarded: continue after all 3 lives are lost (once per puzzle), hint, 2x coins after a level.
- Interstitial: request once when the player leaves a win/lose result. Bridge owns pacing with a minimum delay of 90 s. FakeAds keeps level 10+, the first two minutes free of interstitials, and a 90 s cooldown.
- Banner: bottom of the gameplay screen only. Hide it when the browser is under 600 CSS px wide or in portrait. Otherwise keep controls clear of the banner using its measured height. No-Ads/payers (later): no interstitial or banner.
- Web uses the Playgama Bridge Godot 4 plugin after initialization. Respect platform pause, audio, and tab visibility. Native development and tests use FakeAds. Hide rewarded controls on unsupported hosts. Grant a reward only if Bridge reported the rewarded state.

## Quality gates (every PR; run them yourself)
1. `godot --headless --import` finishes without errors.
2. `godot --headless -s res://tests/run_tests.gd` — all tests pass. Write tests for every rule (clues, solver, lives, save, economy, daily selection, Star Battle validator).
3. `python3 tools/check_levels.py` — every nonogram and daily puzzle has exactly one solution.
4. Web export with preset "Web" succeeds; report the total size.
5. No secrets, no paid dependencies, no new warnings.

## Workflow
- Start every task by reading AGENTS.md, ROADMAP.md and HANDOFF.md. Read other files selectively; do not re-read the whole repo.
- Do ROADMAP tasks in order and tick a checkbox only when its acceptance criteria are met.
- Small, clear commits.
- Do not try to open pull requests through the GitHub API. Push the work to a branch named codex/<task-id>-<short-name> and end your reply with the exact branch name; Oz opens and merges the PR after Claude's review.
- Before finishing, or when close to your limits, update HANDOFF.md: state, what works, what is broken, exact commands, next 3 steps.
- Never weaken CI checks or delete tests to make them pass.
