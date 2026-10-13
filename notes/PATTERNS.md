# Patterns

## 2026-10-13 — Atomic shared delivery

`RocketService:deliver` does not yield: check phase/cargo, clamp accepted amount,
consume cargo, credit one contributor and transition to boarding in one handler.
The runnable two-contributor check in `tests/Rocket.spec.luau` protects replay
handling and prevents exceeding the final requirement.

## 2026-10-13 — Confirmed reward transaction

`ProfileService:save` captures a retry batch, commits reward IDs with bonuses and
completions, and updates the displayed reward only on success. Preserve new
training/delivery changes earned during the write. `tests/Profiles.spec.luau`
injects a committed write whose response is lost to check exactly-once retry.
