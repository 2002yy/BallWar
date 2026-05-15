# Marble Dominion / 球球领土战争 Godot MVP

Godot 4.x 2D prototype skeleton generated from the bilingual requirement document.

## Current MVP Features

- Central 40x40 square grid battlefield.
- Four initial colored quadrants.
- Four corner turrets matching the four factions.
- Turrets randomly rotate but do not fire by timer.
- Four independent external control chambers.
- Each chamber has a control ball, pegs, x2 gate, and R gate.
- x2 doubles pending shot count.
- R triggers the mapped turret to fire the pending count, then resets to 1.
- Bullets recolor one grid cell.
- Bullets continue through same-color cells and disappear when they recolor enemy cells.
- Live score label shows occupied cells by faction.

## How to run

1. Open this folder with Godot 4.x.
2. Open `scenes/Main.tscn`.
3. Press Run.

## Notes

The scene is intentionally thin. Most gameplay nodes are created from code so Codex can modify one module at a time.
