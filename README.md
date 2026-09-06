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
  shared/
    Config.luau            # Place IDs and gameplay settings
    Remotes.luau           # Every Remote name plus server creation
  server/
    RemoteBootstrap.server.luau
  places/
    lobby/server/Lobby.server.luau
    lobby/client/QueueClient.luau
    chapter1/server/Chapter.server.luau
    chapter1/client/ChapterClient.luau
    chapter1/client/FirstPersonCamera.client.luau
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

### Chapter 1 camera

- In Studio's Avatar Settings, set the avatar type to **R6**.
- Chapter 1 locks the local player to first person. Lobby camera behavior is unchanged.
- The local player's head and Accessory parts are hidden only on that player's screen.
  `Torso`, arms, and legs remain visible; other players still see the full character.
- Roblox's default `Humanoid` movement remains responsible for walking and jumping.
  `FirstPersonCamera.client.luau` adds only light breathing, vertical walking bob, sideways
  lean, mouse-turn inertia, and a landing kick after the default camera updates. Walking
  does not add repetitive side-to-side sway.
- Effect strengths are constants at the top of that file. Tune those constants instead
  of changing the camera formulas.
- `CAMERA_POSITION_OFFSET` controls the base viewpoint around the head. `X` moves
  horizontally left/right, `Y` always moves down/up, and `Z` moves horizontally
  backward/forward. Looking up or down does not tilt these position axes. Start with
  small changes of `0.05` studs.

### Chapter 1 sprint

- Hold `LeftShift` while moving to sprint. Stamina is consumed only while actually moving.
- Edit the constants at the top of `SprintController.client.luau` to change walk/run speed,
  acceleration/deceleration time, maximum stamina, drain, recovery, recovery delay, and
  the minimum stamina needed after exhaustion.
- The default R6 `Animate` script reacts to the increased Humanoid speed, so no custom
  animation ID is required yet.
- The bottom-center stamina line fades away when it is full and idle.

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

`Chapter.server.luau` keeps `setAct()` and `advanceAct()` as local server-only integration
points for future objective/puzzle code. Act state never moves backward and currently has
no Studio-authored trigger.

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
7. With an R6 avatar in Chapter 1, look down and confirm the torso, arms, and legs are
   visible while the head and accessories do not block the camera.
8. Stand still, walk, strafe, turn quickly, jump, and land. Confirm each camera effect is
   light enough to aim comfortably, then reset once to confirm it reconnects on respawn.
9. In a two-client test, confirm the other client still sees the complete head and
   accessories. `LocalTransparencyModifier` must affect only its owning client.
10. Hold `LeftShift` while moving and confirm speed takes about one second to reach its
    maximum. Release Shift and confirm it smoothly returns to walking speed.
11. Drain stamina to zero, confirm sprint stays disabled until the bar recovers past its
    threshold, and verify stamina does not drain while standing still.
12. Focus chat while holding Shift, switch window focus, die, and respawn. Confirm sprint
    never remains stuck and the thin stamina line resets correctly.

### Published teleport test

1. Publish Lobby and Chapter 1 under the same Experience.
2. Set the exact Place IDs in `Config.luau` and publish the synced code.
3. Start from the published Lobby client, not Studio Play Solo.
4. Test groups of 1 and 4 players, queue leave/rejoin, a full queue, reserved-server
   arrival, and the error signal from a failed teleport. Automatic retry is not yet built.
5. Verify all players arrive in the same Chapter 1 server and that no checkpoint survives
   leaving that server.

## Current scope

Implemented: code-only Place separation, one centralized Remote module, server-owned Lobby
queue, guarded group teleport, first-person lock, Act state functions, tagged checkpoint
capture, and same-server respawn restoration. Lobby and Chapter server flows each live in
one main script so they can be read from top to bottom.

Integration skeleton only: queue interaction/UI, objective-driven Act changes, production
teleport retry UX, collection persistence, chapter completion persistence, puzzles,
cutscenes, subtitles, threats, and monster AI.
