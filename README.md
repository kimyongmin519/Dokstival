# Dokstival

PC-first, 1-4 player Roblox horror fan game. The Experience uses a Lobby Place and a
Chapter 1 Place. Chapter 1 contains Acts 1-3 without another Place teleport.

## Ownership boundary

Rojo owns code only:

- `ReplicatedStorage.Shared`
- `ServerScriptService.Server`
- `StarterPlayer.StarterPlayerScripts.Client`

Roblox Studio is the source of truth for `Workspace` maps, `Terrain`, `Lighting`,
animations, sounds, UI instances, and cinematic staging. Both project files intentionally
omit `Workspace` and `Lighting`, so syncing code cannot replace the map.

## Repository layout

```text
src/
  shared/                  # Shared config and network definitions
  server/                  # Server code used by both Places
  client/                  # Client code used by both Places
  places/
    lobby/server/          # Queue and teleport authority
    lobby/client/          # Queue UI integration API
    chapter1/server/       # Act/checkpoint/respawn authority
    chapter1/client/       # Chapter presentation integration API
```

- `lobby.project.json`: Lobby sync/build target
- `chapter1.project.json`: Chapter 1 sync/build target
- `default.project.json`: convenience alias for the Lobby target
- `aftman.toml`: pins Rojo `7.7.0`

## Setup

Install the pinned tool once:

```powershell
aftman install
rojo --version
```

Before published testing, update both `Development` and `Production` entries in
`src/shared/Config.luau` with the real Lobby and Chapter 1 Place IDs. A Place ID of `0`
is deliberately rejected, so an unconfigured project cannot teleport accidentally.
The DataStore names are reserved configuration only; persistence is not implemented yet.

Build each code model:

```powershell
rojo build lobby.project.json -o Dokstival-Lobby.rbxlx
rojo build chapter1.project.json -o Dokstival-Chapter1.rbxlx
```

For normal map development, open each existing Studio Place and sync only its matching
project:

```powershell
rojo serve lobby.project.json
rojo serve chapter1.project.json
```

Do not build a generated place over the canonical Studio map. Build output is only a
path/configuration validation artifact.

## Studio requirements

### Common

- Enable `Workspace.StreamingEnabled` in both Places in Studio.
- Keep the Experience player limit at 4.
- Scripts lock the local player to first person. Final camera/UI behavior remains a
  client presentation task.
- The server creates `ReplicatedStorage.Remotes` and all declared remotes. Do not create
  duplicate RemoteEvents or RemoteFunctions in Studio.

### Lobby

No queue pad or UI design is assumed. A future Studio-authored interaction should require
`StarterPlayerScripts.Client.Lobby.QueueClient` and call:

- `join()` when the player requests entry;
- `leave()` when the player exits;
- `getState()` for the initial snapshot;
- `onStateChanged(callback)` and `onError(callback)` for presentation.

The first queued player starts the configured 15-second countdown. The server caps the
queue at four and teleports the current group to a reserved Chapter 1 server.

### Chapter 1 checkpoints

Checkpoint parts remain Studio-owned. Each checkpoint must be a `BasePart` with:

| Setting | Value |
| --- | --- |
| CollectionService tag | `ChapterCheckpoint` |
| String Attribute | `CheckpointId` (unique, non-empty) |
| Number Attribute | `Act` (integer 1-3) |

Touching a valid checkpoint records it for that player in server memory. On respawn, the
character is moved four studs above that part. It is intentionally not written to a
DataStore and disappears when the server ends. Checkpoints may stream on clients; all
registration and touch authority runs on the server.

`ChapterStateService.setAct()` and `advance()` are server-only integration points for
future objective/puzzle code. Act state never moves backward and currently has no
Studio-authored trigger.

## Testing

### Studio tests

1. Sync the matching project into a separate test copy of the Place.
2. Use Studio's Server & Clients mode with 1-4 clients.
3. Connect temporary UI/interaction code to `QueueClient`; verify join, leave, full queue,
   countdown snapshots, and error codes.
4. Expect `TeleportSkippedInStudio` after the countdown. Teleport is intentionally not
   attempted in Studio.
5. In Chapter 1, tag test parts as described above, touch one, reset the character, and
   verify the player respawns above the last touched checkpoint.
6. Confirm malformed tagged instances warn without stopping the server.

### Published teleport test

1. Publish Lobby and Chapter 1 under the same Experience.
2. Set the exact Place IDs in `Config.luau` and publish the synced code.
3. Start from the published Lobby client, not Studio Play Solo.
4. Test groups of 1 and 4 players, queue leave/rejoin, a full queue, reserved-server
   arrival, and the error signal from a failed teleport. Automatic retry is not yet built.
5. Verify all players arrive in the same Chapter 1 server and that no checkpoint survives
   leaving that server.

## Current scope

Implemented: code-only Place separation, centralized configuration/remotes, server-owned
Lobby queue, guarded group teleport, first-person lock, Act state API, tagged checkpoint
capture, and same-server respawn restoration.

Integration skeleton only: queue interaction/UI, objective-driven Act changes, production
teleport retry UX, collection persistence, chapter completion persistence, puzzles,
cutscenes, subtitles, threats, and monster AI.
