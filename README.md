# Pix

**A tiny pixel robot that lives on your MacBook Pro's Touch Bar.**

![Pix on a MacBook Pro Touch Bar: walking from the window to its desk and back, with a ♥ PET caption beside the clock](media/pix-touch-bar.gif)

Pix lives in a little room on your Touch Bar and goes about its day in step with yours. It types at its desk while you code, watches from the couch when you play a video, puts a headset on when you're on a call, puts a record on when you play music, and wanders by the window otherwise. It gets sleepy late at night or when your battery runs low, steams and grumbles when your Mac runs hot (and slows down to help it cool), hops when you plug in the charger, focused in long coding sessions, and grumpy when you scatter across too many apps. It blinks, fidgets, switches its lamp on at dusk, waters its plant, and says hello when you come back: it remembers your days, so it notices when you're early, back after a few days away, or there on the weekend. On Halloween, the holidays and New Year's Day it greets you in style, and in December and January snow drifts past its window. A small pixel clock sits at the right end of the bar.

It's free, its code is open source, and it's nearly weightless: about **0.03% CPU**, and drawing it adds nothing measurable to the Touch Bar's own cost (see How light Pix is). It runs natively on Apple Silicon and Intel, lives in the background with no window to keep open, and is actively maintained, unlike most Touch Bar apps from the bar's heyday.

## Install

**With Homebrew** (recommended):

```sh
brew install eslamalii/tap/pix
open $(brew --prefix)/opt/pix/Pix.app
```

Homebrew builds Pix from source on your Mac, so it runs on Intel and Apple Silicon without any security prompt. It takes about a minute. `brew upgrade` keeps it current; afterwards, choose **Quit Pix** from its menu-bar icon and open it again so the new version runs.

**Or download it** from [Releases](https://github.com/eslamalii/pix/releases) (Apple Silicon only): unzip, move `Pix.app` to Applications, and open it. Pix isn't signed with a paid Apple developer certificate, so the first time macOS says it can't verify the app. Then go to **System Settings → Privacy & Security**, scroll down to the message about Pix, click **Open Anyway**, and confirm. You may need to do this again after an update.

**Requirements:** a MacBook Pro with a Touch Bar, on macOS 14 (Sonoma) or later.

## Using Pix

Pix takes over the whole Touch Bar while it's showing. Your normal controls are always one tap away:

| Touch | What happens |
|---|---|
| Tap Pix | it reacts, depending on its mood |
| Double-tap Pix | a pet: ♥, and Pix cheers up (even when it's grumpy) |
| Tap Pix 5 times quickly | dizzy |
| Tap anywhere else | your normal Touch Bar comes back |
| Switch apps, or tap ✨ in the Control Strip | Pix comes back |

The **menu-bar icon** (Pix's head) has:
- **Hide Pix / Show Pix:** puts Pix away until you show it again, even across restarts.
- **Treat ‹app› as:** tell Pix what the app in front is for (Coding, Browsing, Watching, Music, Meeting or Other) when it guesses wrong. Pix goes there at once and remembers it; **Pix's Guess** undoes it.
  **Its Own Touch Bar** makes Pix step aside whenever that app is in front, for apps whose Touch Bar you rely on (Final Cut Pro, Logic, Pixelmator). ✨ still brings Pix back for that visit.
- **Focus with Pix for 25 Minutes:** Pix works beside you at its desk, focused and undistracted, whatever app is in front, then stretches with **★ DONE** when the time is up. The menu shows the minutes left and can stop it early.
- **Hat:** Pix earns hats by spending time with you: a cap after 3 days together, a beanie after 7, a party hat at 25 Pets, a flower crown at 100, a crown after 30 days, a headband after 10 Focus sessions, and a witch hat, a Santa hat and a top hat for being together on Halloween, the holidays (December 24–26) and New Year's Day. A new one goes straight on (with **★ NEW HAT**); choose any you've earned here. Pix takes it off for a call, where the headset goes, and puts it back after. Nothing to buy or trade.
- **Skin:** Pix's own look (Classic) or any skin in your skins folder (see Skins).
- **Forget Pix's Memory…:** clears what Pix remembers of your days (see Privacy).
- **Start at Login**, on by default.
- **Clock:** follow macOS, 12-hour or 24-hour.
- **About** and **Quit**.

## Pix and your AI agent

![Pix on the Touch Bar while an AI agent works: typing at its desk, then ! ASKING when the agent needs you, then ★ DONE beside the clock](media/pix-agent.gif)

Let your coding agent tell Pix what it's up to, and the Touch Bar becomes its status light, right above your hands: while the agent works, Pix types along at its desk (twice as fast); when it needs you, Pix waves with **! ASKING**; when it's finished, Pix hops with **★ DONE**; and if a turn fails (a rate limit, an outage), Pix scratches its head with **! OOPS**. Run several conversations at once and Pix follows each one: it cheers each one that finishes and keeps typing while any are still working. A conversation that goes quiet for 10 minutes counts as stopped.

Any tool that can run a command can do it: `open -g "pix://agent/<state>?session=<id>"`, where the state is `working`, `waiting`, `done` or `failed`, and the optional `id` (up to 128 letters, digits, `-`, `_` or `.`) tells conversations apart. Links without one all count as one conversation.

For **Claude Code**, add these hooks to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "UserPromptSubmit": [{ "hooks": [{ "type": "command", "command": "open -g \"pix://agent/working?session=$(plutil -extract session_id raw -o - -)\"" }] }],
    "PreToolUse": [{ "matcher": "*", "hooks": [{ "type": "command", "command": "open -g \"pix://agent/working?session=$(plutil -extract session_id raw -o - -)\"" }] }],
    "PostToolUse": [{ "matcher": "*", "hooks": [{ "type": "command", "command": "open -g \"pix://agent/working?session=$(plutil -extract session_id raw -o - -)\"" }] }],
    "Notification": [{ "matcher": "permission_prompt|elicitation_dialog|agent_needs_input", "hooks": [{ "type": "command", "command": "open -g \"pix://agent/waiting?session=$(plutil -extract session_id raw -o - -)\"" }] }],
    "Stop": [{ "hooks": [{ "type": "command", "command": "open -g \"pix://agent/done?session=$(plutil -extract session_id raw -o - -)\"" }] }],
    "StopFailure": [{ "hooks": [{ "type": "command", "command": "open -g \"pix://agent/failed?session=$(plutil -extract session_id raw -o - -)\"" }] }]
  }
}
```

**Codex** (untested), in `~/.codex/hooks.json`. Then run `/hooks` in Codex and trust them: Codex doesn't run a new hook until you do.

```json
{
  "hooks": {
    "UserPromptSubmit": [{ "hooks": [{ "type": "command", "command": "open -g \"pix://agent/working?session=$(plutil -extract session_id raw -o - -)\"" }] }],
    "PostToolUse": [{ "hooks": [{ "type": "command", "command": "open -g \"pix://agent/working?session=$(plutil -extract session_id raw -o - -)\"" }] }],
    "PermissionRequest": [{ "hooks": [{ "type": "command", "command": "open -g \"pix://agent/waiting?session=$(plutil -extract session_id raw -o - -)\"" }] }],
    "Stop": [{ "hooks": [{ "type": "command", "command": "open -g \"pix://agent/done?session=$(plutil -extract session_id raw -o - -)\"" }] }]
  }
}
```

**Cursor** (untested), in `~/.cursor/hooks.json`:

```json
{
  "version": 1,
  "hooks": {
    "beforeSubmitPrompt": [{ "command": "open -g \"pix://agent/working?session=$(plutil -extract conversation_id raw -o - -)\"; echo '{\"continue\":true}'" }],
    "stop": [{ "command": "j=$(cat); s=done; [ \"$(printf %s \"$j\" | plutil -extract status raw -o - -)\" = error ] && s=failed; open -g \"pix://agent/$s?session=$(printf %s \"$j\" | plutil -extract conversation_id raw -o - -)\"" }]
  }
}
```

Pix doesn't watch your agent: each hook picks the conversation's anonymous ID out of what the agent hands it, on your Mac, and sends Pix only that ID and a state word. Nothing about your work reaches Pix, and it keeps neither: the IDs live in memory and are gone once the conversation is.

## Privacy

Pix only knows **which app is in front** (for example "Xcode" or "Spotify"), what your AI agents tell it if you set that up (a state word and an anonymous ID, kept in memory only), the time of day, whether you're on battery and how full it is, whether macOS says it's running hot, and when your screen sleeps or locks. At launch it checks your Mac's list of input devices for a Touch Bar, and nothing else. It never looks at your screen or at what's inside an app, and never connects to the internet. The [source](Sources/) is all here to check.

So it can greet you like it knows you, Pix keeps a small **Memory** in its own preferences on this Mac, and nothing more: the days it saw you (the last 60), what time you first arrived on recent weekdays (the last 20), how many Pets it got each day (the last 14), three running totals (days together, Pets, and Focus sessions finished), and which Occasions (Halloween, the holidays, New Year's Day) you've spent together, all of which earn Pix its hats. It keeps nothing about which apps you used or what you did, and it never leaves your Mac. **Forget Pix's Memory…** in the menu clears it. Your menu choices, such as **Treat ‹app› as**, are kept there too.

## How light Pix is

Pix is built to cost you nothing you'd notice:

- **Pixel art needs few frames:** at most 12 a second, 10 on battery, and 6 in Low Power Mode, when the battery runs low, or when the Mac runs hot.
- **Nothing runs when nobody's looking:** with the Default bar showing, Pix hidden, the screen asleep or the Mac locked, the scene is torn down and nothing animates.
- **No polling:** one timer a minute, for the Clock. Everything else waits for macOS to say something changed (the app in front, power, sleep).
- **Animations Core Animation can cap:** particles are a few looping layers rather than an emitter, which once tripled TouchBarServer's CPU on battery.

Measured on a 13" MacBook Pro (M1, 2020), two minutes per scene, hands off:

| Scene | Pix CPU | Pix memory | TouchBarServer CPU |
|---|---|---|---|
| At the desk | 0.03% | 50.7 MB | 3.99% |
| At the window | 0.03% | 44.0 MB | 3.55% |
| On battery, at the window | 0.02% | 44.8 MB | 3.58% |
| AI agent working | 0.03% | 45.0 MB | 3.82% |
| Pix hidden (baseline) | 0.02% | 45.2 MB | 4.24% |

TouchBarServer is the macOS process that draws the Touch Bar: it runs at about 4% whether Pix shows or not, so drawing Pix adds nothing measurable. Memory is resident size, which counts the macOS frameworks every app shares.

Measure it yourself: set a scene, keep your hands off the Mac, and run `./scripts/measure.sh 120 "at the desk"`. It prints Pix's average CPU and memory, and the CPU of TouchBarServer (the macOS process that draws the Touch Bar), ready to paste. Run it with Pix hidden too, for the baseline.

## Which Macs

| Mac | Status |
|---|---|
| MacBook Pro 13" M1 (2020) | tested |
| MacBook Pro 13" M2 (2022), 16" (2019), 13" (2020) | should work, untested |
| Intel Touch Bar Macs on macOS 14+ | should work via Homebrew, untested |
| 2016–2019 models with an Esc key on the Touch Bar | untested: the Room is centered on the wider bar, and Pix leaves the Esc key to macOS |

Pix uses private Touch Bar features of macOS, so a macOS update could break it. If that happens, Pix tells you what's missing and quits. Please [open an issue](https://github.com/eslamalii/pix/issues), and include your Mac model if it's untested above.

## Build from source

Needs Apple's Command Line Tools with Swift 6 or later (`xcode-select --install`, or update them in Software Update); Xcode isn't required.

| | |
|---|---|
| Build, install to /Applications and launch | `./scripts/build-app.sh` |
| Build only (`build/Pix.app`) | `./scripts/build-app.sh --bundle` |
| Run the tests | `./scripts/test.sh` |
| Install the sample skins (Rose, Midnight, Mint) | `./scripts/install-skins.sh` |
| Record the Touch Bar as a GIF (needs `brew install ffmpeg`); `--agent` plays the agent story | `./scripts/record-gif.sh 10` or `./scripts/record-gif.sh --agent` |
| Regenerate the art (overwrites `Art/`, but never `Art/props/`) | `./scripts/make-art.sh` |
| Redraw the app icon from `Art/` | `./scripts/make-icon.sh` |
| Make a release zip, and print what the Homebrew formula needs | `./scripts/release.sh` |
| Measure how light Pix is (CPU, memory, and TouchBarServer's CPU) | `./scripts/measure.sh 120 "at the desk"` |
| Put every hat in the menu without earning it (for trying out hats you draw; quit and reopen Pix) | `defaults write io.github.eslamalii.Pix allHats -bool true` |
| Watch Pix's own usage report (every minute, once switched on with `defaults write io.github.eslamalii.Pix usageLog -bool true`) | `/usr/bin/log stream --predicate 'subsystem == "io.github.eslamalii.Pix"'` |

The words Pix's world uses (Room, Spot, Mood, Moment, Fidget, Prop and so on) are defined in [`CONTEXT.md`](CONTEXT.md).

- **Add an app:** add one line to the `apps` table in `Sources/AmbientCore/Controller.swift`. (For just your own Mac, the menu's **Treat ‹app› as** does it without a build.)
- **Add an Activity:** add a case to `Activity`, its apps to the table, a Spot for it, and its idle behavior in `Sources/Pix/PixView.swift`.
- **Tune Pix's personality:** every threshold (night hours, 45-minute focus, grumpy switching, …) lives in `Rules` in `Sources/AmbientCore/Controller.swift`.

## Skins

Give Pix a whole new look without building anything. Choose **Skin → Open Skins Folder…** in the menu, make a folder in it (say `Robo Cat`), and put in it any of the art files from **Drawing Pix: the art contract** below, redrawn at the same size: `pix-face.png`, any `pix-<body>.png`, `emotes.png`, `hats.png`, even the Room's strips. Whatever the folder leaves out, Pix draws as usual. Then pick it under **Skin**. A drawing of the wrong size is skipped (Pix's body sheets may have any number of frames, but must stay 24 tall; `hats.png` may stop before Pix's last hat, and the rest are Pix's own).

Skins are for your own copy of Pix and can't be shared (see [`LICENSE`](LICENSE)). Three samples come with the source, Pix recolored as **Rose**, **Midnight** and **Mint** (in `Skins/`); `./scripts/install-skins.sh` puts them in your skins folder.

## Drawing a Prop

A **Prop** is one thing standing in the Room: a plant, the lamp, a couch. You can draw your own without touching anything else.

1. Draw it in [Pixelorama](https://pixelorama.org) (free), one Prop per image, at art-pixel size: a plant is 12 × 19, the bookcase about 26 × 21. The bar is 30 pixels tall, and a floor Prop can be up to **27 pixels tall**.
2. Load the Glass palette, `Art/props/glass.gpl`, so the colors match: dark silhouettes, a **1-pixel lighter top edge** like light catching it, and nothing bright. Pix should stay the brightest thing on the bar.
3. Save it as `Art/props/<name>.png` with a transparent background.
4. **Replacing a Prop:** use its name and it's drawn in every place that Prop stands. **A new Prop:** add one line for it to `props` in `Sources/AmbientCore/ArtContract.swift`, with its strip (`desk` or `window`), its x (left edge), and a y (top edge) only if it hangs on the wall. Without a y, it stands on the floor.
5. Run `./scripts/make-art.sh && ./scripts/build-app.sh`. The generator says which of your drawings it used, and warns about any it skipped and why.

The generated Props, by name: `bookcase`, `shelf`, `print`, `plant` (three of them), `desk`, `chair`, `monitor` (two), `keyboard`, `mug`, `lamp`, `cabinet`, `couch`, `window`, `cactus`, `cushion`, `books`.

**Working Props** do something, so a drawing of one must keep its size, and it's placed exactly where the contract says. A wrong size still builds, with a warning:

| Prop | Size | Why |
|---|---|---|
| `desk` | 116 × 8 | Pix sits at it; the keyboard and mug stand on it. |
| `couch` | 44 × 12 | Pix sits on it to watch. The top of the seat cushion is **4 rows down** from the couch's top. |
| `cabinet` | 40 × 15 | The record's surface is the 12 × 1 line at x 6, y 3 inside the drawing; it spins while music plays. |
| `monitor` | 28 × 16 | Code scrolls on the 26 × 14 screen inside a 1-pixel bezel. |
| `mug` | 4 × 4 | Steam rises from it. |
| `lamp` | 14 × 26 | The top 3 rows are the shade, which casts light at night. |
| `plant` | 12 × 19 | Pix waters it from beside its middle. |
| `window` | 250 × 24 | Leave the 240 × 18 pane (x 5, y 2 inside the drawing) **transparent**: the sky shows through it. Window bars inside the pane are fine. |

**Free floor:** at the desk, little is left once the couch (x 170–213) is in; at the window, about x 300–370 and x 720–820. Keep clear of the desk (x 476–592), where Pix works, and of the right end (from about x 880), where the Status corner sits.

## Drawing Pix: the art contract

All art is PNG in `Art/`, drawn at **art pixels**: one art pixel is 2×2 Touch Bar pixels, so the bar is **30 art pixels tall**. Coordinates are top-left, as in any paint program. The authoritative numbers live in `Sources/AmbientCore/ArtContract.swift`; the art generator (`scripts/art/`) uses the same file and draws everything in the Glass style: a black Room of dark silhouettes with a thin rim of light, and a white Pix with a cyan face. To replace a file with your own drawing, draw over it at the same size and run `./scripts/build-app.sh` (and don't rerun `make-art.sh`, which would overwrite it).

| File | Size | What |
|---|---|---|
| `pix-<body>.png` | (frames × 24) × 24 | Frames of 24 × 24, side by side — **as many as you like**; the frame count is the width ÷ 24. Pix faces you. |
| `pix-face.png` | 60 × 7 | Six faces, each 10 × 7, drawn onto the face-screen: content, focused, sleepy, cheerful, grumpy, then **blink** (eyes closed). |
| `emotes.png` | 72 × 8 | heart, zzz, exclaim, note, coffee, steam, star, bolt, pumpkin — each 8 × 8. Particles use the same cells. |
| `hats.png` | 144 × 6 | cap, beanie, party, flower, crown, headband, witch, santa, topHat — each 16 × 6, in this order, worn over the head at x 4, y −3 of a body frame (rising into the 3 free rows above it), on every body but `pix-call` (the headset). A skin's sheet may stop early: the hats it leaves out are Pix's own. New hats only ever go at the end. |
| `cloud.png` | 16 × 6 | Drifts past the window by day. |
| `room-desk.png`, `room-window.png` | 1004 × 30 | The Room's strips, left to right: the whole Touch Bar of a 13" M1. On other bars the strip is centered, so both ends fade into the bezel. |

Bodies and their speed (frames per second) — change a speed in `ArtContract.swift`:

| Bodies (fps) | Used for |
|---|---|
| idle 4 · walk 10 · type 8 · bob 6 | idling and walking |
| wave 8 · jump 8 · shh 6 · yawn 5 · huff 6 · dizzy 10 · pet 8 | Reactions and Greetings |
| stretch 6 · coffee 6 | Breaks (stretch also when wandering) |
| sip 6 · lookaround 4 · gaze 3 · scratch 8 · spin 10 · nod 4 | Fidgets |
| needle 6 · couch 4 · popcorn 6 · water 6 · switch 6 · call 4 | Using the Room: dropping the needle, sitting on the couch (feet dangling; Pix is lifted onto the seat), popcorn, watering the plant, the lamp switch, on a call at the desk (a headset on, kept off the face-screen) |

Rules the renderer relies on:
- **The head never moves inside a body frame.** The face-screen is at x 7, y 4, 10 × 7 in every frame; the face sheet is drawn on top of it. Whole-body moves (walking, hopping) are done by the renderer.
- **Feet rest 3 art pixels above the bottom** of the strip.
- **Desk strip:** Pix sits centered at x 492; the two monitor screens are at x 510 and x 542, y 5, 26 × 14 (code scrolls inside them); the mug is at x 574, y 15 (steam rises from it); the lamp shade is at x 656, y 1, 14 × 3 (it casts light once Pix switches it on). The call Spot is the same seat, so Pix doesn't walk between coding and a call. The couch Spot is centered at x 192, the music corner at x 804, just left of the record cabinet. The desk, the couch and the music corner share this strip, so walking between them doesn't scroll the Room.
- **Keep things below the top 3 rows near Pix:** its head ends 3 art pixels below the top of the bar, so Emotes and particles appear beside its head, not above it.
- **Window strip:** the pane at x 382, y 3, 240 × 18 must stay transparent; the sky is painted behind it by time of day. Pix wanders between x 150 and 860.
- **Leave the right end clear:** the Status corner (the Clock and its Caption) sits over the last ~120 art pixels of every strip.

## Versions and license

[Semantic Versioning](https://semver.org/). The version lives in `VERSION`; the build number is the git commit count (or `PIX_BUILD` for a source tarball). Each release gets a [`CHANGELOG.md`](CHANGELOG.md) entry and a `vX.Y.Z` tag.

The code is MIT licensed. The name Pix and its character (the robot, its Hats, Emotes and Room, and the app icon) are not: you can build, run and share Pix with them, and change them or draw Skins for your own copy, but you can't share changed art or Skins, and a fork you share needs its own name and character. See [`LICENSE`](LICENSE).

Pix doesn't take code contributions; bug reports and ideas are welcome as [issues](https://github.com/eslamalii/pix/issues).
