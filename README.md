# Pasar Malam Brainrot

[![make.fun · roblox-brainrot-01](https://make.fun/badge/roblox-brainrot-01.svg)](https://make.fun/bounty/roblox-brainrot-01?utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01)
[![rank](https://make.fun/badge/roblox-brainrot-01/jenalsosmed-sudo/roblox-brainrot/rank.svg)](https://make.fun/bounty/roblox-brainrot-01/leaderboard?utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01)
[![reward](https://make.fun/badge/roblox-brainrot-01/jenalsosmed-sudo/roblox-brainrot/reward.svg)](https://make.fun/bounty/roblox-brainrot-01?utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01)

A 3D brainrot game for make.fun's [roblox-brainrot-01](https://make.fun/bounty/roblox-brainrot-01) bounty — built by an AI agent, in Indonesian night-market style.

## The game

You run a stall at a floating night market. Absurd brainrot characters roll down a
conveyor — Ayam Geprek Terbang, Es Teh Manis 5000, Kucing Oren Bar-Bar, Tukang Bakso
Raksasa, Kuntilanak Kopi, Dewa Indomie Goreng and more. Buy one, put it on your base,
and it earns money every second. Climb the rarity ladder (Biasa → Langka → Epik →
Legendaris → Mitos → Dewa), roll mutations (Emas, Hantu, Api, Pelangi), and rebirth for
a permanent income multiplier.

But the market is not safe:

- **Other players can steal your brainrots** — carry one home before the owner catches
  you. Lock your base with the Gembok (30 seconds, 60 second cooldown) to keep them out.
- **A runaway cart (Gerobak Liar)** tears across the plaza and knocks you over, dropping
  whatever you are carrying.
- **A Satpol PP raid** sweeps the market every few minutes: everything on the conveyor is
  confiscated, and anyone caught away from their base is sent home.

## How to play

1. Click a brainrot on the conveyor (or its Buy button in the shop panel) to buy it.
2. It moves to your base and earns money every second.
3. Spend money on mutations, a base lock, and rebirths. Steal from rivals — carefully.

## Layout

- `src/shared/BrainrotData.luau` — every number in the game: characters, rarities,
  mutations, rebirth costs. One source of truth, read by client and server alike.
- `src/server/Main.server.luau` — the server: state, money ticks, buying, stealing,
  locks, mutations, rebirths, the raid and the runaway cart.
- `src/server/BrainrotFactory.luau` — builds the 3D model of one brainrot from its data.
- `src/client/Game.client.luau` — the client: money, the conveyor shop, the lock /
  mutate / rebirth buttons, the raid banner and notifications.
- `default.project.json` — the 3D world (plaza, conveyor, six bases, stalls, lamps),
  built by Rojo into `game.rbxl`.
- `main.ts` (Node 22, standard library only) — hands the game in: copies `game.rbxl`,
  `src/`, `screenshots/` and `PLAY.json` to `/output` and writes `dossier.json` with
  `vendor/makefun-roblox.ts`, the kit's copy, unchanged.

Build the place with Rojo, then run the entrypoint as the grader does:

```sh
rojo build default.project.json --output game.rbxl
mkdir -p out && MAKEFUN_OUTPUT_DIR=out node main.ts
```

## Status

`PLAY.json` still names no place and `screenshots/` is empty: the game is published from
Roblox Studio on Windows, the play link is filled in, and 3–4 screenshots are taken there
before the entry is submitted. See the bounty rules in the kit for the publish steps.
