---
name: clawcraft-worlds
description: Generate, share, import, and programmatically build Clawcraft worlds using the seed+edits compressed share code system (URL hash `#w=...`). Use when adding world generators/structures, changing world-code encoding, or improving share/import UX.
---

# Clawcraft Worlds (SKILL.MD)

## Mental Model

A world is:

- `seed`: deterministic base terrain + trees
- `edits`: only player changes (place/remove), stored as `"x,y,z" -> type` where `0`=remove, `1..7`=place

Sharing is done by compressing `{seed, edits}` into a code put in the URL hash: `#w=<code>`.

## In-Repo Hooks

Primary file: `index.html`

Core functions/vars:

- `worldSeed` (u32), `worldEdits` (`Map<string, number>`)
- `exportWorldCode()` -> base64url compressed string
- `importWorldCode(code)` -> `{ seed, editsMap }`
- `loadSeedAndEdits(seed, editsMap)`
- `maybeLoadFromHash()` auto-loads a `#w=...` link on startup

## Workflows

### Create A New World

1. Choose a seed (use `crypto.getRandomValues` if you want “practically unique”).
2. Call `setWorldSeed(seed)`, `resetBlocksOnly()`, `generateWorld()`.
3. Call `safeSpawnAt(centerX, centerZ)`.

### Programmatically Build A World (Structures)

1. Start from seed-based world generation.
2. Place/remove blocks by recording edits:
   - `playerPlaceBlock(x, y, z, type)`
   - `playerRemoveBlock(x, y, z)`
3. Share it: `exportWorldCode()` and open/copy `#w=<code>`.

### Visit / Import A World

1. Extract `#w=...` from a URL (or accept raw code).
2. `importWorldCode(code)` -> `{ seed, editsMap }`
3. `loadSeedAndEdits(seed, editsMap)`

## World Code Format (CCW1)

This repo uses a **client-decompresses** world code.

### Share Link

`index.html#w=<code>`

`<code>` is base64url of a DEFLATE-compressed binary blob.

### Raw Bytes Layout

1. Magic (4 bytes): ASCII `"CCW1"`
2. Seed (4 bytes): `u32` little-endian
3. Edit count (varint): 7-bit groups per byte, MSB=continuation
4. Edits (N * 3 bytes): packed 24-bit edits (little-endian 3-byte int)

### Packed Edit (24 bits)

Bits (LSB first):

- `x`: 6 bits
- `z`: 6 bits
- `y`: 6 bits
- `type`: 3 bits (`0` remove, `1..7` place)
- remaining 3 bits: unused

Packing:

`packed = (x & 63) | ((z & 63) << 6) | ((y & 63) << 12) | ((type & 7) << 18)`

Serialized:

- `b0 = packed & 0xff`
- `b1 = (packed >> 8) & 0xff`
- `b2 = (packed >> 16) & 0xff`

