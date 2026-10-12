# Pix

**A tiny pixel robot that lives on your MacBook Pro's Touch Bar.**

[![Website](https://img.shields.io/badge/website-meetpix.app-black?style=flat-square)](https://meetpix.app)
[![Release](https://img.shields.io/github/v/release/eslamalii/pix?style=flat-square)](https://github.com/eslamalii/pix/releases)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg?style=flat-square)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-lightgrey?style=flat-square)](#which-macs)
[![Touch Bar](https://img.shields.io/badge/hardware-Touch%20Bar-orange?style=flat-square)](#which-macs)

![Pix on a MacBook Pro Touch Bar: walking from the window to its desk and back, with a ♥ PET caption beside the clock](media/pix-touch-bar.gif)

Pix lives in a cozy pixel room on your Touch Bar and moves through the day alongside you. It types at its desk while you code, relaxes on the couch when you watch videos, puts on a headset for calls, spins a vinyl record when music plays, and gazes out the window when idle.

It blinks, waters its plant, switches on its desk lamp at dusk, steams when your Mac runs hot, hops when you plug in power, and greets you warmly when you return.

Pix is **free**, **open-source**, **private**, and virtually weightless (~**0.03% CPU**).

---

## Quick Install

### Homebrew (Recommended)

Builds natively on Apple Silicon and Intel with zero security hurdles:

```sh
brew install eslamalii/tap/pix
open $(brew --prefix)/opt/pix/Pix.app
```

> **Tip:** Keep it up to date with `brew upgrade pix`. Pix starts automatically at login (toggleable from the menu bar).

### Direct Download (Apple Silicon)

1. Grab `Pix-1.1.0.zip` from [Releases](https://github.com/eslamalii/pix/releases).
2. Unzip and drag `Pix.app` to `/Applications`.
3. Because Pix is ad-hoc signed, macOS may block the first launch: go to **System Settings → Privacy & Security**, scroll down, click **Open Anyway**, and confirm.

**Requirements:** MacBook Pro with Touch Bar running macOS 14 (Sonoma) or newer.

---

## What Pix Does

### Context-Aware Living Room
Pix senses the active foreground app and naturally moves to the matching spot:

| Spot | Activity / Trigger | What Pix Does |
|---|---|---|
| **The Desk** | Code editors (Xcode, VS Code, Cursor, JetBrains, Terminal…) | Types attentively with code scrolling on dual screens |
| **The Couch** | Video & streaming (YouTube, QuickTime, Netflix, IINA…) | Sits comfortably on the couch watching with you |
| **The Meeting** | Video calls (Zoom, Meet, FaceTime, Slack calls…) | Stays at the desk wearing an audio headset |
| **Music Corner** | Music players (Spotify, Apple Music, Tidal…) | Drops the needle on a turntable that spins to the beat |
| **The Window** | Browsers & general apps | Strolls by the window, with live sky & drifting clouds |

*Misidentified app? Use **Treat ‹app› as…** in the menu bar to assign it permanently.*

### Touch & Interactions
Pix takes over the Touch Bar seamlessly, but keeps standard macOS controls one touch away:

- **Tap Pix:** Reacts according to its current mood.
- **Double-tap Pix:** Pet Pix (`♥`) to cheer it up, even when it's grumpy.
- **Tap Pix 5 times rapidly:** Makes Pix dizzy!
- **Tap anywhere else:** Instantly reveals your standard macOS Control Strip.
- **Tap ✨ or switch apps:** Brings Pix right back.

### Moods, Seasons & Memory
- **Moods:** Cheerful, focused during long coding stretches, sleepy late at night or on low battery, and grumpy if you rapidly scatter across apps.
- **Break reminders:** Takes subtle coffee or stretch breaks every 45 minutes of sustained coding.
- **Seasonal delights:** Snow drifts past the window in winter, with special greetings and hats for Halloween, the holidays, and New Year’s Day.
- **Earned Hats:** Unlock hats just by spending time together—caps, beanies, party hats, flower crowns, and seasonal specials. No microtransactions or accounts.

---

## AI Coding Agent Companion

Turn your Touch Bar into a physical status dashboard for your autonomous coding agents:

![Pix following an AI agent: typing fast, ! ASKING when needed, ★ DONE on completion](media/pix-agent.gif)

When hooked into your AI agent, Pix types twice as fast while the model reasons, waves with **`! ASKING`** when tool approval is requested, hops with **`★ DONE`** when finished, and scratches its head with **`! OOPS`** if an error occurs.

Supports **multiple concurrent agent conversations** simultaneously via session IDs!

Any tool or script can notify Pix via URL scheme:
```sh
open -g "pix://agent/<state>?session=<optional-id>"
# States: working | waiting | done | failed
```

### Claude Code Setup
Add to `~/.claude/settings.json`:

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

### Cursor Setup
Add to `~/.cursor/hooks.json`:

```json
{
  "version": 1,
  "hooks": {
    "beforeSubmitPrompt": [{ "command": "open -g \"pix://agent/working?session=$(plutil -extract conversation_id raw -o - -)\"; echo '{\"continue\":true}'" }],
    "stop": [{ "command": "j=$(cat); s=done; [ \"$(printf %s \"$j\" | plutil -extract status raw -o - -)\" = error ] && s=failed; open -g \"pix://agent/$s?session=$(printf %s \"$j\" | plutil -extract conversation_id raw -o - -)\"" }]
  }
}
```

### Codex Setup
Add to `~/.codex/hooks.json`, then run `/hooks` in Codex to trust:

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

---

## Privacy & Performance

### 100% On-Device & Zero Network Activity
- Pix **never makes network requests**.
- Only tracks the active frontmost app bundle ID (e.g. `com.apple.dt.Xcode`).
- Agent sessions and state tokens exist in transient memory only.
- Local memory (days together, pet count, focus sessions) is stored in standard local `UserDefaults` and can be wiped instantly via **Forget Pix's Memory…**.

### Near-Zero System Impact
Engineered specifically not to drain your battery or heat up your Mac:
- **Capped Frame Rates:** Up to 12 fps on mains power, dropping to 10 fps on battery, and 6 fps in Low Power Mode or under thermal pressure.
- **Completely Sleeps:** When the screen sleeps, the Mac locks, or Pix is hidden, all timers and rendering pipelines halt entirely.
- **Measured Footprint:**

| State | Pix CPU | Pix RAM | TouchBarServer CPU |
|---|---|---|---|
| Typing at the desk | 0.03% | ~50 MB | ~3.9% |
| Window idling | 0.03% | ~44 MB | ~3.5% |
| On battery | 0.02% | ~44 MB | ~3.5% |
| Hidden (baseline) | 0.02% | ~45 MB | ~4.2% |

*(TouchBarServer is the native macOS process responsible for the display; Pix adds zero measurable overhead).*

---

## Customization & Skins

Custom skinning doesn't require compiling code:
1. Open **Skin → Open Skins Folder…** from Pix's menu icon.
2. Create a folder (e.g. `Cyberpunk`) and drop in your customized pixel artwork (`pix-face.png`, `pix-walk.png`, etc.).
3. Select your new skin from the menu.

Sample skins (**Rose**, **Midnight**, and **Mint**) are included in `Skins/` and can be installed via `./scripts/install-skins.sh`.

Have a skin to share? Show it off in [GitHub Discussions](https://github.com/eslamalii/pix/discussions)!

---

## Which Macs

| Model | Compatibility |
|---|---|
| **MacBook Pro 13" (M1, 2020)** | Fully verified & tested |
| **MacBook Pro 13" (M2, 2022)** | Supported |
| **MacBook Pro 16" & 13" (2019, 2020 Intel)** | Supported on macOS 14+ via Homebrew |
| **MacBook Pro 13" & 15" (2016–2019 with Esc on Touch Bar)** | Room centered automatically; physical Esc area left clear |

---

## Building from Source

Requires macOS Command Line Tools with Swift 6+ (`xcode-select --install`).

```sh
# Build, install to /Applications, and run
./scripts/build-app.sh

# Run the complete test suite
./scripts/test.sh

# Build standalone app bundle without installing
./scripts/build-app.sh --bundle
```

For more internal design details and vocabulary, see [`CONTEXT.md`](CONTEXT.md).

---

## License & Community

- **Code:** Licensed under the [MIT License](LICENSE).
- **Artwork & Character:** The character *Pix*, room art, hats, emotes, and app iconography are copyright and reserved. Feel free to build, play, and make personal skins, but custom art cannot be redistributed commercially.
- **Contributions & Issues:** Bug reports and feature ideas are warmly welcome via [GitHub Issues](https://github.com/eslamalii/pix/issues).
