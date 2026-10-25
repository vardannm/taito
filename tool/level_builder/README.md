# Developer level builder

Double-click `level_builder.cmd` in the project folder (or run `.\level_builder`
from a terminal there). The builder opens in your browser when it is ready; if
it is already running, it just opens the page. Close the window to stop it, or
run `.\level_builder -Stop` to stop every running builder on any port.
Use `.\level_builder -Port 8766` if the default port is busy, or `-NoBrowser`
to skip opening the browser. The editor is served only on loopback.
No editor files are Flutter assets or imports of the game's entry point; this
tool is not compiled into the player app. No Firebase account is used here.

## Create a level

- Start blank, or **Open existing**: the eye button previews a level read-only
  (your draft stays untouched; switch freely between levels), and the pencil
  button edits that level with its original number. You are only asked to
  confirm when your current draft has unsaved changes.
- Place **Target** holes 1–10, **Trap holes**, **Spiders**, **Lasers**, or **Moving holes**.
- Drag objects, or select them and type exact properties in the inspector.
- Select any hole to set its **Hole size** (0.2–2.5 × a normal hole) and its
  **Movement path** (side to side, up and down, circle or oval) to make a
  moving target or trap. X/Y become the path's center; the dashed line shows
  the route. Set **Size over time** to *Grow and shrink* to make a hole breathe
  between a smallest and biggest size for the whole level (dashed rings show
  both sizes). Normal stationary holes export exactly as before.
- Use **Erase**, Delete, **Undo**, and **Redo**. Snap can be switched off.
- **Duplicate**: with the Duplicate tool, press an object and drag out a copy;
  or select one and press **Ctrl+D** / *Duplicate selected object*. Copies keep
  every setting; a copied target takes the next free number (or becomes a trap).
- For hazards, choose the active wave and target. Waves repeat in their listed order.
  Add/reorder waves to alternate lasers and moving holes; set warning/active times.
  Select circular, oval, horizontal or vertical movement and set its radii,
  period (seconds per cycle), and phase (radians). Positions are motion centers.
  Laser orientation selects vertical beams (y 33–537) or horizontal beams
  (x 24–336). Enable **Preview hazard movement** to see the paths animate.
  Set a laser wave's **Beam** to *Dashed* for lit dashes with gaps the ball
  can slip through (gaps over 14); **Dash speed** slides them along the beam.
  Original sway preserves older levels. Spider coordinates are patrol centers.
- Levels 31 and up have deadly lasers on both side rails in the game; the
  board draws them in red, and Level check warns about a target that can only
  be reached by brushing a side laser.
- Add briefing text and timing under **Briefing & timing**.
- Click any **Level check** message to select what it is about (it flashes on
  the board). Click it again to step to the next object it mentions.
- The browser autosaves one current draft. **Save draft** downloads a JSON file
  for durable storage; **Import draft** restores it. Save drafts before replacing them.
- Resolve blocking level checks, review warnings, then **Save to game**. This writes
  the numbered Dart file and updates the registry. Rebuild and playtest afterward.
  Existing source is backed up under `artifacts/level-builder-backups/`.
- **Export Dart** remains available for manual downloads.

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
**Save to game** writes directly to that numbered source file. The local server
requires Node.js on PATH to validate/export with the shared editor model.
Changing a level number to the next available number creates a new level instead.
Saving does not rebuild a running game or update its installed release.

Validation checks structure, numeric bounds, targets and spacing. It does not
prove every route is playable; use actual gameplay to verify difficulty and hazards.

For a non-Windows machine with Dart/Flutter on PATH, run `dart tool/level_builder.dart`.
Registration is `dart tool/register_classic_levels.dart`. Mode previews draw
the current level data directly; no PNG regeneration is needed.
