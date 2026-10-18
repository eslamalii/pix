# Changelog

All notable changes to this project are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- **Pix refills its mug:** Pix starts the day with an empty mug, walks to the cabinet and pours a fresh one, then sips it three times before it needs the next refill. An empty mug doesn't steam. Pix only drinks coffee from 06:00 to 17:00; in the evening it leaves the mug alone.

### Changed

- **Pix no longer repeats itself:** it never plays the same idle Fidget twice in a row.

- **A more detailed Room:** every Prop is drawn with more detail, down to the smallest ones. Spine bands, a leaning book and a bookend on the shelves; a night sky over the mountains in the print; tufted cushions and a throw pillow on the couch; drawers, a cable and a lit edge on the desk; casters on the chair; a camera, glare and power light on the monitors; keys on the keyboard; crema in the mug; a switch and weighted base on the lamp; record sleeves, knobs and a two-way speaker in the music corner; latches on the window; a flower on the cactus; and a bookmark in the books by the window. Every working Prop keeps its size, so the code, steam, light, record and sky still line up, and your own drawings in `Art/props` still replace them.

## [1.1.3] - 2026-10-14

### Changed

- **The Routine owns timing:** Pix's timing and idle decisions live entirely in the Routine. The view runs a single wake timer, with the Routine setting wake deadlines and managing Fidget timing.
- **Stroll driven by Routine:** pausing before turning, looking around, and stretching or standing at the ends of the window are now driven directly by Routine steps and wake deadlines rather than view-side timers.
- **Strongly-typed Fidgets:** Fidgets are now type-safe enum cases, mapping directly to body sheets or Errands (such as watering the plant) and validated by art-drift tests.
- **Unified walk performer:** walks between Spots (with Room scrolling), Errand walks to and from Props, and Stroll walks are performed by a single unified routine in the view with consistent frame-rate capping.

## [1.1.1] - 2026-10-13

### Fixed

- **Pix follows you across time zones:** after a flight, Pix gets sleepy, greets you, celebrates Occasions and switches its lamp by the new local time, without a restart. Before, only the Clock and the sky moved.

### Changed

- **Strolling at the window:** after a tap or an agent's news interrupts it, Pix carries on to the end of the window it was walking to instead of turning back to the farther one, and a change of Mood no longer stops it mid-walk.

## [1.1.0] - 2026-10-12

### Added

- **Several agents at once:** each conversation's hooks can send its anonymous ID (`pix://agent/<state>?session=<id>`), and Pix follows each one. It cheers **★ DONE** for each conversation that finishes and keeps typing while any are still working; each one counts as stopped after its own 10 quiet minutes. Links without an ID count as one conversation, so existing setups keep working.
- **! OOPS:** `pix://agent/failed` makes Pix scratch its head when a turn fails (a rate limit, an outage) instead of typing on for 10 minutes.

### Changed

- **Claude Code setup:** sends each conversation's ID, shows **! ASKING** only for notifications that ask you something (not sign-in or quota notices), goes back to typing once you approve a tool, and reports failed turns.
- **Codex setup:** moves from `notify` to Codex's hooks, so Pix types along and asks too, not only cheers when it's done. Run `/hooks` in Codex to trust them.
- **Cursor setup:** sends each conversation's ID, and a conversation that ends in an error shows **! OOPS**.

## [1.0.0] - 2026-10-12

Pix's first release: a tiny pixel robot that lives on your MacBook Pro's Touch Bar.

### Added

- **A Room on the Touch Bar:** Pix goes to the Spot that fits the app in front: the desk for coding, the same seat with a headset for a call, the couch for a video, the music corner for music, and the window otherwise. **Treat ‹app› as** fixes a wrong guess, and **Its Own Touch Bar** keeps Pix out of the way of apps whose Touch Bar you rely on.
- **Moods:** content, focused in long coding sessions, sleepy late at night or on a low battery, cheerful, and grumpy when you scatter across too many apps. Pix steams when your Mac runs hot and hops when you plug in the charger.
- **Touch:** tap Pix and it reacts to its Mood, double-tap for a Pet, tap five times for dizzy, and tap anywhere else for your normal Touch Bar. ✨ in the Control Strip brings Pix back.
- **A life of its own:** Pix blinks, fidgets, takes coffee and stretch Breaks in long coding sessions, switches its lamp on at dusk, waters its plant, and snow drifts past its window in December and January.
- **Memory:** Pix greets you when you arrive and notices when you're early, back after a few days away, or there on the weekend. It celebrates Halloween, the holidays and New Year's Day. **Forget Pix's Memory…** clears it.
- **Focus with Pix for 25 minutes:** Pix works beside you at its desk, then stretches with **★ DONE**.
- **Hats** earned by time together: days, Pets, Focus sessions and Occasions. Pix takes its hat off for a call.
- **Your AI agent on the Touch Bar:** through `pix://agent/working`, `waiting` and `done`, Pix types along while your agent works, waves with **! ASKING** when it needs you, and hops with **★ DONE** when it's finished. There are hook recipes for Claude Code, Codex and Cursor.
- **Skins:** a folder of redrawn art dresses Pix up without a rebuild.
- A pixel **Clock** and **Caption** in the Status corner, a menu-bar icon, **Hide Pix**, **Start at Login**, and an app icon.
- Light on the Mac: about 0.03% CPU, at most 12 frames a second (fewer on battery or when hot), and nothing animates while nobody's looking.
