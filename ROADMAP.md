# ROADMAP — Velokity: Space Nonogram v1.0 (web)
Deadline: v1.0 submitted to portals by 9 Dec 2026.

- [x] T01 Foundation: Godot project with the AGENTS.md settings, folder structure, autoloads, translations (en/id), main menu placeholder, tests/run_tests.gd (own minimal runner, no plugins), tools/ skeleton, export_presets.cfg (Web; Android placeholder without keystore), GitHub Actions workflow on push/PR: cache Godot + export templates -> import -> tests -> check_levels -> web export -> size report -> upload web build artifact.
- [x] T02 Nonogram core: level JSON (id, size, solution rows, reveal palette, planet, title en/id); clue calculation; board UI (tap to fill, X-mode toggle, drag to fill along a line); line check + auto-cross finished lines; 3 lives; win (colored reveal) / lose; hint (reveals one correct cell); Python line solver + uniqueness check; tools/build_levels.py converts text pixel grids (art/levels_src/*.txt) into data/levels/; 60 levels: 20x 5x5, 20x 8x8, 20x 10x10 across planets Moon, Mars, Saturn.
- [x] T03 Rasi Bintang daily: Python generator + validator + unique-solution solver, sizes 6–9, difficulty rises Monday->Sunday, 120 puzzles in data/daily/, selection by local date, streak + 7-day reward calendar, same 3-lives rule.
- [x] T04 Game flow & save: main menu, planet list (Moon, Mars, Saturn + locked teasers), level select, game screen, win/lose screens, settings (sound, music, vibration, Calm Mode, language), coin economy (earn; spend on hints/continue), save/load with versioning.
- [x] T05 QA screenshots: QA query param (?qa=menu|game|win|daily) active only in QA builds; CI job serves the web build and uses headless Chromium (Playwright, SwiftShader WebGL2) to save screenshots as artifacts; PR template.
- [x] T06 Velokity mascot: code-drawn 2D cut-out rig with every "Feel" item, 8 expressions, reactions to fill/mistake/combo/win; 3-layer parallax starfield.
- [x] T07 Combo & Bonus Round: combo = 3+ correct lines in a row without a mistake -> effect theme picked at random from the unlocked pool (player level 1: Shooting Star, Comet; 5: Supernova; 10: Meteor Shower; 15: Warp; 20: Aurora; 30: Black Hole) + coin multiplier x2..x5 by combo length; 1 badge per flawless level, 4 badges -> Bonus Round (3 quick 5x5 puzzles, rising multiplier). Celebration tiers: 1 small (correct line, ~0.3 s), 2 medium (combo, ~1 s), 3 big (flawless level/3 stars/4th badge, ~2 s), 4 max (Bonus Round, album complete, 7-day streak, level up, event, 3–4 s). Calm Mode versions.
- [x] T08 Meta: planet albums (20 pictures each), costumes (helmet, suit, jetpack, accessory) from album rewards/achievements/coin shop, player level XP, achievements, daily login calendar.
- [x] T09 Monetization (web): Playgama Bridge Godot 4 plugin behind the Ads interface with the AGENTS.md rules, "Traktir Velokity" button (URL from config), itch.io-friendly build, IAP hooks stubbed for later.
- [x] T10 Audio & polish: ship v1.0 with the current 60 levels. Apply T09 review fixes, generate procedural SFX and two short seamless music loops (menu and puzzle), stay under 3 MB of audio, honor first input, audio settings and ad mute, update docs/CREDITS.md, and add an audio smoke test.
- [ ] T11 Release kit: performance and size pass, bug bash, icon, portal thumbnails, store texts en/id (title, short + long description), docs/privacy.md, docs/RELEASE.md (steps for Oz per portal), Android export preset ready for later, final HANDOFF.md.
  - Applied the T10 QC follow-up and implemented the release kit, browser playthrough, and CI capture for store videos. Raw Web export 41.09 MB. The 393×851 touch profile on software rendering still misses the frame-time target. Verify a physical mid-range phone before closing T11.
- [ ] T11b Portal compliance: make Web QA deterministic, implement Playgama required SDK steps, and deploy green main Web builds to GitHub Pages.
  - Fixed run #25, added browser and SDK regression checks, and wired Pages deployment. Verify the first green main deployment after merge.
- [ ] T12 Feel & Shop v1.1
  - [ ] 1. Queue saves in order so rapid actions persist the latest snapshot. Test with slow storage.
  - [ ] 2. Raise procedural audio levels and add saved Music and Effects volume sliders.
  - [ ] 3. Add visual-only fill streak escalation, persistent peak state, and a win recovery animation.
  - [ ] 4. Add an animated space backdrop, Calm Mode support, and automatic reduction under sustained load.
  - [ ] 5. Expand the direct-purchase shop with cats, skins, and costumes in four rarity tiers. Migrate existing saves.
  - [ ] Capture the four new QA routes in CI and commit screenshots under 300 KB each.
- [ ] T13 Content v1.1: grow to 300 nonograms and 365 daily puzzles. Add 12x12 and 15x15 boards with zoom/pan and tune the difficulty curve.
- [ ] T14 Small twists: add a new small mechanic every 10–15 levels.
