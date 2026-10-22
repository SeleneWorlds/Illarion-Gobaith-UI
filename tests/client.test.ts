import { test } from 'node:test';
import { createHudLayout } from '../illarion-gobaith-ui/ui/src/layout';
import assert from 'node:assert/strict';
import { createIllarionClient } from '../illarion-client-core/ui/src/index';
import type { ClientNetworkPayload, SeleneUiApi } from '../illarion-client-core/ui/src/selene';

const setup = () => {
  const handlers = new Map<string, Set<(payload: ClientNetworkPayload) => void>>();
  const connected = new Set<() => void>();
  const sent: Array<{ id: string; payload?: ClientNetworkPayload }> = [];
  const network: SeleneUiApi['network'] = {
    sendToServer(id, payload) {
      sent.push({ id, payload });
    },
    onPayload(id, handler) {
      const entries = handlers.get(id) ?? new Set();
      handlers.set(id, entries);
      entries.add(handler);
      return () => entries.delete(handler);
    },
    onConnected(handler) {
      connected.add(handler);
      return () => connected.delete(handler);
    },
  };
  const client = createIllarionClient({ network });
  const receive = (id: string, payload: ClientNetworkPayload) =>
    handlers.get(id)?.forEach((handler) => handler(payload));
  return { client, receive, sent, handlers, connected };
};

test('an alternative HUD can observe inventory and move/use items through shared services', () => {
  const { client, receive, sent } = setup();
  receive('illarion:update_slot', { viewId: 'belt', slotId: 0, item: { visual: 'illarion:apple', count: 4 } });
  assert.equal(client.inventory.getItem('belt', 0)?.count, 4);
  client.inventory.moveSlotToSlot('belt', 0, 'equipment', 1, 2);
  assert.deepEqual(sent.pop(), {
    id: 'illarion:move_slot_to_slot',
    payload: {
      fromViewId: 'belt',
      fromSlotId: 0,
      toViewId: 'equipment',
      toSlotId: 1,
      count: 2,
    },
  });
  client.inventory.useOn({ viewId: 'belt', slotId: 0 }, { x: 1, y: 2, z: 0 }, 1);
  assert.deepEqual(sent.pop(), {
    id: 'illarion:use_slot_at',
    payload: { viewId: 'belt', slotId: 0, x: 1, y: 2, z: 0, count: 1 },
  });
  receive('illarion:update_slot', { viewId: 'belt', slotId: 0 });
  assert.equal(client.inventory.getItem('belt', 0), undefined);
  client.dispose();
});

test('casting uses authoritative known runes and combat target, with explicit target overriding it', () => {
  const { client, receive, sent } = setup();
  receive('illarion:magic', { type: 1, flags: 0x80000001 });
  receive('illarion:set_combat_target', { networkId: 42 });
  client.magic.cast([0, 31]);
  assert.deepEqual(sent.pop(), {
    id: 'illarion:cast',
    payload: { spell: 0x80000001, kind: 'character', networkId: 42 },
  });
  client.magic.cast([0], { kind: 'field', x: 3, y: 4, z: 0 });
  assert.equal(sent.pop()?.payload?.kind, 'field');
  client.magic.cast([1]);
  assert.equal(sent.length, 0);
  client.dispose();
});

test('books use explicit sessions and page counts, without item use or inform interception', () => {
  const { client, receive, sent } = setup();
  receive('illarion:inform', { Message: '#b|1|0|legacy text' });
  assert.equal(client.books.current.value, undefined);
  receive('illarion:book_page', { id: 10, page: 250, pageCount: 251, itemId: 105, text: 'Page 250' });
  assert.equal(client.books.canNext.value, true);
  client.books.turn(1);
  assert.deepEqual(sent.pop(), { id: 'illarion:book_request_page', payload: { id: 10, page: 251 } });
  receive('illarion:book_page', { id: 10, page: 251, pageCount: 251, itemId: 105, text: 'Last page' });
  client.books.turn(1);
  assert.equal(sent.length, 0);
  assert.equal(client.books.canNext.value, false);
  client.books.close();
  assert.equal(sent.pop()?.id, 'illarion:book_close');
  receive('illarion:book_page', { id: 10, page: 250, pageCount: 251, itemId: 105, text: 'Late reply' });
  assert.equal(client.books.current.value, undefined);
  receive('illarion:book_page', { id: 11, page: 2, pageCount: 1, itemId: 0, text: 'Invalid' });
  assert.equal(client.books.current.value, undefined);
  client.dispose();
});

test('concurrent action requests are correlated and subscriptions are released when a HUD is replaced', async () => {
  const { client, receive, sent, handlers, connected } = setup();
  const first = client.world.getActions({ coordinate: { x: 1, y: 2, z: 0 }, networkId: 7 });
  const second = client.world.getActions({ coordinate: { x: 3, y: 4, z: 0 } });
  const [one, two] = sent;
  receive('illarion:menu_at', { requestId: two.payload?.requestId, actions: [{ id: 'open', label: 'Open' }] });
  receive('illarion:menu_at', { requestId: one.payload?.requestId, actions: [{ id: 'lookAt', label: 'Look' }] });
  assert.equal((await first)[0]?.id, 'lookAt');
  assert.equal((await second)[0]?.id, 'open');
  const pending = client.world.getActions({ coordinate: { x: 0, y: 0, z: 0 } });
  client.dispose();
  assert.deepEqual(await pending, []);
  assert.equal(
    [...handlers.values()].reduce((sum, entries) => sum + entries.size, 0),
    0,
  );
  assert.equal(connected.size, 0);
  const before = sent.length;
  client.world.walkTo({ x: 0, y: 0, z: 0 });
  assert.equal(sent.length, before);
});

test('HUD layout preserves default geometry and scales high resolution packs uniformly', () => {
  const original = createHudLayout();
  assert.equal(original.scale, 1);
  assert.deepEqual(
    [original.width, original.height, original.viewportWidth, original.viewportHeight],
    [1024, 768, 839, 419],
  );
  const large = createHudLayout(128, 64);
  assert.equal(large.scale, 64 / 37);
  assert.deepEqual([large.width, large.height, large.viewportWidth, large.viewportHeight], [1771, 1328, 1451, 725]);
  const point = large.toHud({ x: 400 * large.scale, y: 200 * large.scale });
  assert.ok(Math.abs(point.x - 400) < 1e-9);
  assert.ok(Math.abs(point.y - 200) < 1e-9);
  // The texture's inverse scale cancels the HUD scale, preserving native item dimensions.
  assert.equal((128 / large.scale) * large.scale, 128);
  assert.throws(() => createHudLayout(0, 0));
});
