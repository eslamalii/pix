# Pix

A pixel-art Character that lives inside the laptop and shows up on the Touch Bar, going about its life in step with what the user is doing, so the user feels connected to the machine.

## Language

### The world

**Pix**:
The Character's name, and the name of the app it lives in.

**Character**:
The one small creature that lives inside the laptop: a tiny robot whose face is a screen. It has a personality and is never a tool or an assistant.
_Avoid_: avatar, mascot, bot, buddy

**Room**:
The single continuous place the Character lives in. It is wider than the Touch Bar, so the Bar shows one part of it at a time.
_Avoid_: scene (for the whole place), world, level, background

**Spot**:
The place in the Room that belongs to one Activity: the desk for coding, the same seat with a headset on for a meeting, the couch for watching, the music corner for music, the window for everything else. The Character goes to the Spot of the current Activity. Several Spots can share one stretch of the Room.
_Avoid_: station, area, zone, room (for one part)

**Prop**:
One thing that stands in the Room, such as a plant, the lamp, the bookcase or a couch. Some Props do something (code scrolls on the monitors, the lamp gives light once the Character switches it on, the record spins while music plays); most are just there.
_Avoid_: object, item, decoration, furniture

**Occasion Prop**:
A Prop that stands in the Room only in an Occasion season, such as Halloween's jack-o'-lanterns, bunting and the ghost hanging from the lamp. Some glow from dusk; one can hang over a Prop and cover it for the season, as the haunted print covers the print.
_Avoid_: decoration, seasonal item

### What the user is doing

**Activity**:
What the user is doing right now, decided only by the app in front, never by what's inside it: coding, browsing, watching (a video app, not a video in a browser), music, a meeting (a video-call app, not a call in a browser), or other.
_Avoid_: mode, context, task

**Default bar**:
The macOS Touch Bar that Pix hands back when the user needs their controls.
_Avoid_: system bar, normal bar, native bar

**Session**:
How long the user has been continuously in one Activity. Short trips to another Activity don't break it; staying away for a while ends it.
_Avoid_: streak, run, uptime

### The Character's inner life

**Mood**:
The Character's current emotional state: content, focused, sleepy, cheerful or grumpy. It colors how the Character idles and reacts, but never decides where it is (the Activity does).
_Avoid_: emotion, state, feeling

**Focus session**:
25 minutes the user chose to focus, from the menu. The Character works at the desk beside them, focused, and celebrates when it's over. It never interrupts the user, and no Break interrupts it.
_Avoid_: pomodoro, timer, sprint

**Break**:
A short pause the Character takes on its own during a long coding Session, such as a coffee or a stretch.
_Avoid_: rest, pause, idle

**Emote**:
A small symbol that pops up beside the Character's head to show a feeling (♥ 💤 ❗ ♪ ☕). Emotes are the closest the Character comes to words: the Character never speaks.
_Avoid_: icon, bubble, speech

### Between the user and the Character

**Reaction**:
What the Character does when the user taps it, colored by its Mood.
_Avoid_: response, interaction, animation

**Moment**:
Anything the Character does once, in answer to the user or their day, and then goes back to what it was doing: a Reaction, a Break or a Greeting. Arriving at a Spot (sitting down at the desk, dropping the needle in the music corner) is not a Moment; it's part of going there.
_Avoid_: event, action, one-shot

**Look**:
How the Character appears: for a Moment (its body, Emote, Caption and what plays alongside) or at rest at a Spot (its body, how fast it plays, whether a screen lights its face, the particles off its head). Looks are drawn only from the art contract.
_Avoid_: animation, sprite (those are the art)

**Greeting**:
The Moment when the Character notices the user arriving: when it starts up, or when the user is back after being away for a while.
_Avoid_: welcome, hello, wake-up

**Fidget**:
A small thing the Character does on its own while idling, now and then (looking around, refilling the mug) or at a time of day (switching the lamp on at dusk). Unlike a Moment, it answers nothing the user did.
_Avoid_: idle animation, tic, flourish

**Errand**:
A trip to a Prop: the Character walks to the Prop, uses it (waters a plant, switches the lamp, refills the mug at the coffee machine) and walks back to its Spot. It happens as a Fidget, as Care, or at a time of day (the lamp at dusk). A Moment or an app switch can cut it short.
_Avoid_: task, trip, chore

**Need**:
Something a Prop lacks that comes on with time until the Character sees to it, such as a plant going thirsty. A Need shows in the Room (a thirsty plant droops), keeps while the Character is away, and never grows worse or does harm: it only waits for the Character. Only the Character answers it; the user never owes the Room anything.
_Avoid_: want, decay, neglect; and need for the Character's own wants, which will get their own word

**Care**:
The Errand that answers a Need: the Character notices a thirsty plant and waters it. It happens when a Fidget would, from a Spot where the Character is free to leave.
_Avoid_: chore, upkeep, maintenance

**Stroll**:
How the Character idles at the window: it walks from one end of the window to the other, stops at each end to look around, and stretches at the right end before walking back. A Fidget or a Moment can interrupt it; a Fidget waits for the current walk to finish.
_Avoid_: wander, pace, patrol

**Routine**:
What the Character does next with its body in the Room: going to a Spot, idling there (the Stroll, at the window), Fidgets, Errands and Moments. It follows from the Activity, the Mood, the Moments and the time of day.
_Avoid_: behavior, AI, state, schedule

**Pet**:
A double-tap on the Character. It makes the Character happier.
_Avoid_: stroke, like

**Memory**:
What the Character remembers of the user's days, kept only on the laptop: which days it saw them, when they usually arrive, how many Pets it got, how many Focus sessions they finished together, and which Occasions they shared. It shows in the day's first Greeting (back, early, weekend, or cheerful after a day of Pets) and in the Hats the Character earns.
_Avoid_: history, tracking, analytics, profile

**Occasion**:
A day of the year the Character celebrates in the day's first Greeting: Halloween, the holidays (December 24–26) and New Year's Day.
_Avoid_: holiday (for all of them), event, season

**Occasion season**:
The days around an Occasion when its Occasion Props stand in the Room: for Halloween, October 24 through November 1, so a user who misses the day itself still finds the Room dressed. (An Occasion is the one day; its season is the stretch around it.)
_Avoid_: holiday period, event window

**Hat**:
Something the Character wears on its head, earned by time spent with the user (days together, Pets, Focus sessions finished, Occasions shared), never bought or traded. The Character puts a new one on itself; after that, the user chooses which to wear. It takes the Hat off only when what it's doing can't be done in one (the headset for a call), and puts it back after.
_Avoid_: cosmetic, item, reward, unlock

**Agent**:
One conversation with the user's AI coding agent: two Claude Code windows are two Agents, and the tool itself (Claude Code, Cursor, Codex) is only the Agent's tool. Through hooks the user sets up, an Agent tells the Character that it's working, waiting for the user, done, or failed, known only by an anonymous ID it sends along; messages without an ID all count as one nameless Agent. The Character types along while any Agent works and tells the user when one needs them, has finished, or has failed; it never watches the Agents itself, and forgets an Agent once it's done, failed, or quiet for 10 minutes.
_Avoid_: session (that's the Session), assistant (the Character is never one), bot, AI

**Connection**:
The feeling that the Character lives in the laptop and notices the user. It comes from the Character's behavior, not from words. This is what Pix is for.
_Avoid_: talking, chat, conversation

### Around the Character

**Skin**:
A different drawing of the Character's world that the user installs: the Character, its Hats and Emotes, even the Room. Whatever a Skin leaves out is drawn as Classic, the world's own look.
_Avoid_: theme, costume, mod

**Status corner**:
The fixed right end of the Touch Bar, outside the Room: it stays put while the Character walks between Spots. It holds the Clock and the Caption.
_Avoid_: HUD, overlay, status bar

**Clock**:
The time of day, in pixel digits, in the Status corner.
_Avoid_: time display, watch

**Caption**:
An Emote and a short word shown beside the Clock for a few seconds after a Moment, labelling what just happened (♥ PET, ! HELLO). It is the bar labelling the Character, not the Character speaking.
_Avoid_: toast, label, notification, speech
