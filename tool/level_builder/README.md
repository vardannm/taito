# Developer level builder

From the project folder, run:

```powershell
.\scripts\level_builder.ps1
```

Open http://127.0.0.1:8765 in a browser. Keep the terminal open; Ctrl+C stops it.
Use `-Port 8766` if the default port is busy. The editor is served only on loopback.
No editor files are Flutter assets or imports of the game's entry point; this
tool is not compiled into the player app. No Firebase account is used here.

## Create a level

- Start blank, or **Open existing** to copy a level into the next available number.
- Place **Target** holes 1–10, **Trap holes**, **Spiders**, **Lasers**, or **Moving holes**.
- Drag objects, or select them and type exact properties in the inspector.
- Use **Erase**, Delete, **Undo**, and **Redo**. Snap can be switched off.
- For hazards, choose the active wave and target. Waves repeat in their listed order.
  Add/reorder waves to alternate lasers and moving holes; set warning/active times.
  Select circular, oval, horizontal or vertical movement and set its radii,
  period (seconds per cycle), and phase (radians). Positions are motion centers.
  Laser orientation selects vertical beams (y 33–537) or horizontal beams
  (x 24–336). Enable **Preview hazard movement** to see the paths animate.
  Original sway preserves older levels. Spider coordinates are patrol centers.
- Add briefing text and timing under **Briefing & timing**.
- The browser autosaves one current draft. **Save draft** downloads a JSON file
  for durable storage; **Import draft** restores it. Save drafts before replacing them.
- Resolve blocking level checks, review warnings, then **Export Dart**.

## Add level 81 to the game

1. Export/download `level_81.dart` (or copy the code into a file with that name).
2. Place it in `lib/classic_levels/`.
3. Run `.\scripts\register_levels.ps1`. This updates the registry and bakes previews.
4. Rebuild and playtest. New levels appear after level 80 and use the existing
   star-unlock rules. Level count and saved-progress loading follow the registry.

Restart the builder after adding levels to refresh its existing-level list and
the suggested next level number.

Use consecutive numbers and keep existing IDs unchanged. The registration command
rejects gaps or mismatched constants. It does not overwrite individual levels.
To edit an existing level, explicitly set its original number before exporting.
There is no automatic write from the browser to the game source.

Validation checks structure, numeric bounds, targets and spacing. It does not
prove every route is playable; use actual gameplay to verify difficulty and hazards.

For a non-Windows machine with Dart/Flutter on PATH, run `dart tool/level_builder.dart`.
Registration is `dart tool/register_classic_levels.dart`, followed by
`flutter test --no-pub tool/bake_mode_previews.dart`.
