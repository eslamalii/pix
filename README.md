# Pix

**A tiny pixel robot that lives on your MacBook Pro's Touch Bar.**

[![Website](https://img.shields.io/badge/website-meetpix.app-black?style=flat-square)](https://meetpix.app)
[![Release](https://img.shields.io/github/v/release/eslamalii/pix?style=flat-square)](https://github.com/eslamalii/pix/releases)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg?style=flat-square)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-lightgrey?style=flat-square)](#which-macs)

![Pix on a MacBook Pro Touch Bar: walking from the window to its desk and back, with a ♥ PET caption beside the clock](media/pix-touch-bar.gif)

Pix lives in a cozy pixel room on your Touch Bar and moves through the day in rhythm with yours. It types at its desk while you code, sits on the couch when you watch videos, puts on a headset for calls, drops a vinyl needle when music plays, and gazes out the window when idle.

It blinks, waters its plant, turns on its desk lamp at dusk, steams when your Mac runs hot, hops when you plug in power, and greets you warmly when you return.

Free, open source, 100% private, and featherlight (~**0.03% CPU**).

---

## Install

```sh
brew install eslamalii/tap/pix
open $(brew --prefix)/opt/pix/Pix.app
```

> **Requires:** MacBook Pro with Touch Bar running macOS 14 (Sonoma) or newer. Starts automatically at login (toggleable from the menu bar).

---

## What Pix Does

### Context-Aware Living Room
Pix senses the active app and moves to match:

| Spot | Activity | What Pix Does |
|---|---|---|
| **The Desk** | Coding (Xcode, VS Code, Cursor, Terminal…) | Types attentively with code scrolling on dual screens |
| **The Couch** | Video (YouTube, QuickTime, Netflix, IINA…) | Relaxes on the couch watching with you |
| **The Meeting** | Calls (Zoom, Meet, FaceTime, Slack…) | Stays at the desk wearing an audio headset |
| **Music Corner** | Music (Spotify, Apple Music, Tidal…) | Spins a vinyl record that grooves to the tune |
| **The Window** | Browsing & general apps | Strolls by the window, with live sky & drifting clouds |

*Wrong guess? Use **Treat ‹app› as…** in the menu bar to assign any app permanently.*

### Touch & Interactions
- **Tap Pix:** Reacts based on its mood.
- **Double-tap Pix:** Pet Pix (`♥`) to cheer it up, even when it's grumpy.
- **Tap Pix 5 times rapidly:** Makes Pix dizzy!
- **Tap anywhere else:** Instantly brings back your standard macOS Touch Bar.
- **Tap ✨ or switch apps:** Brings Pix right back.

### Moods, Seasons & Memory
- **Moods:** Cheerful, focused during long coding sprints, sleepy late at night or on low battery, and grumpy if you rapidly scatter across apps.
- **Breaks:** Subtle coffee or stretch pauses every 45 minutes of continuous coding.
- **Seasonal delights:** Drifting winter snow, with special greetings and hats for Halloween, the holidays, and New Year’s Day.
- **Earned Hats:** Unlock caps, beanies, party hats, flower crowns, and seasonal specials just by spending time together. No microtransactions or accounts.

---

## AI Coding Agent Companion

Turn your Touch Bar into a physical status dashboard for your AI coding agents:

![Pix following an AI agent: typing fast, ! ASKING when needed, ★ DONE on completion](media/pix-agent.gif)

Pix types twice as fast while the model works, waves with **`! ASKING`** when tool approval is needed, hops with **`★ DONE`** when finished, and scratches its head with **`! OOPS`** if a turn fails.

Supports **multiple concurrent agent conversations** simultaneously!

Any tool or script can notify Pix via URL scheme:
```sh
open -g "pix://agent/<state>?session=<optional-id>"
# States: working | waiting | done | failed
```

<details>
<summary><strong>Claude Code Setup</strong> (click to expand)</summary>

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
</details>

<details>
<summary><strong>Cursor Setup</strong> (click to expand)</summary>

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
</details>

<details>
<summary><strong>Codex Setup</strong> (click to expand)</summary>

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
</details>

---

## Privacy & Performance

- **100% On-Device:** Pix **never connects to the internet**. No analytics, no telemetry.
- **Zero Inspection:** Only detects frontmost app bundle ID (e.g. `com.apple.dt.Xcode`). Never reads screen or keystrokes.
- **Featherlight:** Sleeps completely when display turns off or Pix is hidden.
- **Measured CPU:** ~0.03% (Pix adds no measurable overhead to native TouchBarServer).

---

## Customization & Skins

Make your own look without recompiling:
1. Open **Skin → Open Skins Folder…** from Pix's menu icon.
2. Drop in your custom pixel art (`pix-face.png`, `pix-walk.png`, etc.).
3. Pick your skin from the menu.

Sample skins (**Rose**, **Midnight**, and **Mint**) are included in `Skins/` (`./scripts/install-skins.sh`).

---

## Which Macs

| Model | Compatibility |
|---|---|
| **MacBook Pro 13" (M1, 2020)** | Tested & verified |
| **MacBook Pro 13" (M2, 2022)** | Supported |
| **MacBook Pro 16" & 13" (2019, 2020 Intel)** | Supported via Homebrew |
| **MacBook Pro 13" & 15" (2016–2019 with Esc on bar)** | Room centered automatically |

---

## License & Community

- **Code:** [MIT License](LICENSE).
- **Artwork & Character:** Copyright & reserved. Free to play, build, and make personal skins; no commercial redistribution of the art.
- **Issues & Ideas:** Welcomed via [GitHub Issues](https://github.com/eslamalii/pix/issues).
