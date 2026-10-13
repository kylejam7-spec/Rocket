# Latest session — 2026-10-13: Studio sync

- Branch: `feat/first-playable`; no main/PR base yet, no PR opened.
  First playable implementation: `56d8cbc`; setup details in README.
- Connected the Build a Rocket Team Create experience to the pinned Rojo 7.7.1
  server at `127.0.0.1:34873`. CityGang's existing 34872 server stays untouched.
- Previous developer disconnected their Rojo session before connection.
  Plugin confirms project Rocket and Disconnect; session lock belongs to the
  current Studio user. Studio is left in Edit mode ready to play.
- Verification: all five source scripts in Studio have matching normalized byte
  counts and rolling hashes against the local files. No gameplay source changed.
  Earlier Luau compilation, delivery/profile checks and place build passed.
- Updated project port, README and project notes for repeatable reconnect.
- Not verified: two-client gameplay/UI, actual published DataStore calls,
  rejoin and shutdown recovery. Default persistence remains off.
- Public-release blocker: pending rewards in memory can be lost on server death;
  implement and fault-test durable pending entitlements before release.
- Next task: run README's two-player Studio scenario in the connected experience.
  Second developer independently reproduces it; agree initial main/PR base.
