import type { SeleneUiApi } from './selene';
import { createBookService } from './books';
import { createCombatService } from './combat';
import { createInventoryService } from './inventory';
import { createMagicService } from './magic';
import { createSkillsStore } from './skills';
import { createVitalsStore } from './vitals';
import { createWorldService } from './world';

// One instance per HUD. Subscription ownership is explicit, so unmounting or
// replacing a HUD cannot leave a second set of protocol handlers behind.
export const createIllarionClient = (api: Pick<SeleneUiApi, 'network'>) => {
  let disposed = false;
  const subscriptions: Array<() => void> = [];
  const network: SeleneUiApi['network'] = {
    sendToServer(id, payload) {
      if (!disposed) {
        api.network.sendToServer(id, payload);
      }
    },
    onPayload(id, callback) {
      const release = api.network.onPayload(id, callback);
      subscriptions.push(release);
      return release;
    },
    onConnected(callback) {
      const release = api.network.onConnected(callback);
      subscriptions.push(release);
      return release;
    },
  };
  const combat = createCombatService(network);
  const world = createWorldService(network);
  return {
    books: createBookService(network),
    combat,
    inventory: createInventoryService(network),
    magic: createMagicService(network, combat),
    skills: createSkillsStore(network),
    vitals: createVitalsStore(network),
    world,
    dispose() {
      disposed = true;
      world.dispose();
      subscriptions.splice(0).forEach((release) => release());
    },
  };
};
export type IllarionClient = ReturnType<typeof createIllarionClient>;
