# Changelog

All notable changes to this project are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [Semantic Versioning](https://semver.org/).

## [1.3.0] - 2026-10-27

### Added

- **Pix takes care of the plants:** each of the Room's three plants gets thirsty on its own, three to six hours after it was last watered, and droops until Pix waters it. Pix only tends the plants on the part of the Room it is in: the two at the desk from the desk, the one by the window while strolling. It goes at the next idle moment, nearest plant first, never while focused or sleepy, and never from the call, the couch or the music corner. The plants keep their thirst between launches, so after a weekend away you find them drooping and watch Pix go round and water them. A skin that draws its own Room can add its own `plant-thirsty.png`.

- **Pix has a life while you're away:** when you come back after being away (the screen asleep or locked, or Pix not running) and Pix says hello, you first catch it for a couple of seconds doing what it was up to: dozing on the couch if you were gone for a couple of hours or it is night, making the morning's coffee between 06:00 and 10:00, or gazing out of the window otherwise. After the coffee the mug is full and steaming, and Pix carries it to the desk. Pix remembers when you were last there, so quitting it on Friday evening and starting it on Monday morning counts as a long absence too. Nothing new is drawn for this: it uses Pix's existing couch, pour and gaze animations.

### Changed

- **Watering is no longer a random idle Fidget:** Pix used to water the one plant nearest the desk now and then, whether it needed it or not, and never touched the other two. It now waters a plant only when it is thirsty.

- **Pix's head in the Control Strip:** the button that brings Pix back shows Pix's head, the same as in the menu bar, instead of ✨.

- **Lighter while your Agents work:** Pix used to save when you were last there on every message from an Agent's hooks. It now saves it at most every half minute, which cuts the CPU each message costs by about two thirds.

### Fixed

- **No more ghost Pix mid-walk:** tapping Pix while it strolled at the window, or switching apps while it walked between Spots, flashed a fading copy of Pix for a quarter of a second at the spot it was walking to. It happened whenever Zs, hearts or steam appeared or vanished during a walk.

- **Pix's hello is no longer lost to the next thing that happens:** when an Agent's hook started Pix, or the Mac was already hot at launch, Pix opened straight into ASKING or HOT and never said hello or showed what it was up to while you were away. A Moment that arrives while Pix is greeting you also used to cut the Greeting short. Pix now always greets you first, then plays the latest thing that happened meanwhile.

- **Pix types along as soon as an Agent starts:** at the desk, Pix kept typing at its old speed until something else changed when an Agent started or stopped working. It now switches at once, without putting off its next Fidget.

- **The Pix button stays in the Control Strip:** the collapsed Control Strip has room for one app's button, and whichever app claims it last gets it. An app that claimed it after Pix started left you without a way back to Pix there. Pix now claims it again each time it hands you the normal Touch Bar.

- **The clock and captions stay clear:** while Pix walked between Spots, the Room scrolled through the clock and the caption beside it. They now sit on the bar's black.

- **The desk monitors stay full of code:** part of each monitor went blank as its code scrolled, until the loop started over.

- **Every loop slows down together:** when Pix lowers its frame rate (on battery, in Low Power Mode or when the Mac runs hot), Halloween's flickering lights, and Pix's walk, bob and blink during a Stroll, kept the old rate. Everything that loops in the Room now takes the new one at once.

- **A day together counts once after flying west:** crossing the date line westwards goes back to a date Pix has already seen, and Pix counted that day a second time towards the hats earned by days together.

## [1.2.0] - 2026-10-18

### Added

- **Halloween in the Room:** from October 24 through November 1, jack-o'-lanterns sit in the corner and on the windowsill, candles stand on the bookcase and the shelf, bunting hangs over the couch, a spider dangles from the shelf, a ghost hangs from the lamp, a broom leans by the records, a black cat rests by the candles, a bubbling cauldron steams on the floor, a candy bowl and mini pumpkin sit by the desk, cobwebs fill the window and monitor corners, and a haunted house takes the print's place. From dusk the faces and flames flicker, and at night an orange moon rises in the window as bats flap across it.

- **Pix refills its mug:** Pix starts the day with an empty mug, takes its mug to the cabinet, pours a fresh one and brings it back, then sips it three times before it needs the next refill. An empty mug doesn't steam. Pix only drinks coffee from 06:00 to 17:00; in the evening it leaves the mug alone.

- **Universal binary for Apple Silicon and Intel:** prebuilt releases and the one-liner installer run natively on both Apple Silicon and Intel MacBook Pros out of the box with a single universal binary.

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
