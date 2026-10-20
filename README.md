# Flood GUI (Flood Escape 2)

Auto-play for Flood Escape 2 with a rebuilt interface, a difficulty skip list and Discord webhooks.
Originally made from https://github.com/tomatotxt/Flood-GUI

## Run it

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/MeDorel/Flood-GUI/refs/heads/main/FloodGUI.luau"))()
```

## Features

- **Auto-Play**: plays a recorded run for each map and queues the next one.
- **Skip list**: tick Easy, Normal (Medium), Hard, Insane, Crazy or Crazy+ and those maps are skipped
  (your character resets and you re-queue). Defaults to Crazy and Crazy+.
- **Webhooks**: Discord embeds when a map is completed (with your headshot, coins, gems, level, XP bar,
  XP to level up and a session summary), when you die, when a map fails to load, and optionally when a map is skipped.
- **Auto Collect**, walkspeed/jump sliders, noclip, infinite air, air jump, rejoin, and a TAS creator.
- Settings are saved to `Flood-GUI/settings.json` in your executor's workspace folder.
  Your webhook URL lives there, so never share that file.

Press **J** to hide or show the window.

## Credits

TAS record and playback by Voiz. Reverse engineering and the original GUI by tomato.txt. Stat tracker concept by Moz.
Interface, skip list and webhooks in this version.
