# Number Merge review

## Rules retained

Equal powers combine through every matching segment, leaving a unique descending
sequence. The collected value is conserved across the snake; each intermediate
doubling contributes to score. Only the head collides. Earlier pickups can make
later pickups safe, while gates and pickups resolve in swept contact order.
Gates require a strictly larger head and keep their visible requirement fixed.
Existing save identifiers, achievements, records and mode order are preserved.

## Improvements

- Opening rows contain safe numbers. The dangerous third pickup has a 25% chance
  at an 8 head, 50% at 16, 75% at 32 and the configured maximum at 64. Red warning
  rings continue to mark dangerous pickups, evaluated against the current head.
- Each wave retains a guaranteed tail match. Its second safe pickup has a 65%
  chance to target an existing segment, with other powers available to fill gaps
  and prepare future chains. Both chances remain configurable.
- Wave generation preserves fractional elapsed time and each wave's age. It no
  longer discards the overshoot at every spawn. Long updates catch up correctly.
- Gate cooldown starts at the actual swept contact time within the frame.

## Naming and release materials

The visible mode name, guide, achievements and App Store materials use Number
Merge or Merge. The former numerical title is removed from marketing captions,
keywords and descriptions. The number itself remains a valid gameplay milestone.
Internal enum identifiers are retained for compatibility; they are not branding.
This cleanup is not a trademark clearance or a guarantee of store approval.

## Validation

Tests cover 10,000 seeded pickups for conservation, descending unique powers and
unchanged state on fatal pickups; danger rates over 600 waves per progression
stage; useful matching food; identical wave streams across frame partitions;
and gate cooldown measured from contact. Existing swept collision, chain,
pause, reset, record, control and small-screen checks also remain in place.

Balance still benefits from human playtesting, especially the later gates and
the rate of head growth. Automated tests establish rules and timing correctness,
not how satisfying a run feels.
