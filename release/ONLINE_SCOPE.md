# Online services: pending backend selection

Status: not deployed or connected. The app currently provides local friend challenges and manual snapshots only.

## Inputs needed

Choose an existing backend and supply its project details through the provider's normal connection process, or choose a self-hosted service. Do not put admin/service keys in the Flutter client, chat, exported backups, or source control. Confirm the account/identity flow supported on both Android and iPhone before implementation.

## Implementation acceptance criteria

- Account sign-in, sign-out, account recovery and deletion work on both target platforms.
- Cloud progress uses the versioned snapshot schema in `lib/progress_backup.dart`, with ownership enforced by the service. Unauthenticated requests cannot read or replace another player's data.
- Writes use a revision/version precondition. If both devices changed progress, show a comparison and require a deliberate choice; do not silently overwrite one device's wallet or combine coin balances.
- Offline play keeps working. A failed sync preserves local progress and offers a retry; credentials are stored with the platform's protected storage.
- Competitive boards are separated by date, control scheme and rules version. Gear/economy variants must not share rankings unless competition normalizes them.
- Public scores must come from validated runs or be explicitly presented as unverified. A submitted integer or a friend code is not sufficient proof of a run.
- A player explicitly opts into publishing a display name/score. Keep public ranking data separate from private cloud snapshots.
- Validate failure, interrupted upload, stale version, duplicated result, account switch and account deletion before publishing.

Live online service integration and its automated authorization checks remain outstanding until backend selection and account setup.
