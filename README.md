# Illarion Client

This repository contains reusable Illarion client behavior and the Gobaith HUD.
The existing Git history is retained from the former `illarion-gobaith-ui` checkout.

## Layout

- `illarion-client-core/`: Selene bundle for path execution, facing responses,
  shared combat tracking, and music playback. It runs independently of the web HUD.
- `illarion-client-core/ui/src/`: shared Vue/TypeScript state and semantic commands
  for inventory, vitals, skills, magic, combat, books, and world actions. It imports
  no Gobaith components, DOM APIs, gesture handlers, or visual assets.
- `illarion-gobaith-ui/`: replaceable Selene HUD bundle. It owns panels, layout,
  viewport, cursor graphics, key bindings, pointer gestures, item-use selection,
  spellbook selection/bookmarks, and popup positioning.

`illarion-gobaith-ui` depends on the `illarion-client-core` bundle at runtime and
imports the `illarion-client-core` TypeScript workspace package when building its HUD.
The TypeScript services mirror server state for each HUD; Lua owns ongoing native
client behavior. Both consume authoritative server payloads in their own runtime.

## Development

Run from this repository root:

```sh
pnpm install
pnpm dev
pnpm build
pnpm typecheck
pnpm lint
pnpm test
lua tests/books.test.lua
lua tests/movement.test.lua
```

The Lua book test uses the sibling `../illarion-script-loader` checkout.
`pnpm build` writes the HUD to `illarion-gobaith-ui/client/ui/dist`.
Keep this checkout beside the `moonlight` repository, as its UI sources are shared.

Load the bundles from their subfolders, for example with these client arguments:

```sh
-b illarion-client-core ../../bundles/illarion-client/illarion-client-core \
-b illarion-gobaith-ui ../../bundles/illarion-client/illarion-gobaith-ui
```

## Building another HUD

Add its folder to `pnpm-workspace.yaml`, depend on `illarion-client-core` using
`workspace:*`, and add `illarion-client-core` to its bundle dependencies. A HUD
outside this repository can reference `illarion-client-core` as a file or Git
subdirectory dependency. Supply Vue, Zod, and the Selene SDK peer dependencies.

```ts
import { createIllarionClient } from 'illarion-client-core';

const client = createIllarionClient(selene);
// Render client.inventory, client.vitals, client.skills, and client.books.
client.inventory.moveSlotToSlot('belt', 0, 'equipment', 1, 1);
client.inventory.useOn({ viewId: 'belt', slotId: 0 }, { x: 1, y: 2, z: 0 }, 1);
client.magic.cast([0, 1], { kind: 'character', networkId: 42 });
const actions = await client.world.getActions({ coordinate: { x: 1, y: 2, z: 0 } });
// Call client.dispose() when replacing or unmounting this HUD.
```

The UI decides how a gesture selects a source, target, or count. Services encode
requests and maintain shared state. The server remains authoritative for whether
an action is allowed. Gobaith-specific selection and counter state stay in its
local store adapters.

## Book protocol

Books are opened by server scripts through
`illarion-script-loader.server.lua.lib.books`:

- `Books.open(user, pageCount, readPage, initialPage)` registers a reader for the
  current character; `readPage(page)` returns `{ text, itemId }`.
- `Books.show(user, text, itemId)` opens a standalone one-page document, including
  druid reports that previously used page zero.

The server sends `illarion:book_page` with `{ id, page, pageCount, itemId, text }`.
The client sends `illarion:book_request_page` with `{ id, page }`, or
`illarion:book_close` with `{ id }`. Session IDs are server-issued, scoped to the
controlled character, replaced on opening another book, and checked alongside
page bounds. Page turns do not replay item use or accept a client-selected book.
Books no longer pass through `illarion:inform`; the client no longer interprets
`#b|...` strings. Deploy the client with the updated script-loader and Gobaith
scripts together.

## Assets

The Gobaith HUD includes dummy graphics because the original graphics cannot be
redistributed. Original sources are available under <https://github.com/Illarion-eV>.
