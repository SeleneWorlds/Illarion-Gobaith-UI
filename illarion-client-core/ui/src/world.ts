import type { Coordinate, SeleneUiApi } from './selene';

export interface WorldTarget {
  coordinate: Coordinate;
  networkId?: number;
}
export interface WorldAction {
  id: string;
  label: string;
  target?: { name: string; characterId: number };
  givenName?: string;
}

// Keep IDs unique across service instances, including a HUD replacement.
let nextRequestId = 0;

export const createWorldService = (network: SeleneUiApi['network']) => {
  let disposed = false;
  const pending = new Map<
    number,
    { resolve: (actions: WorldAction[]) => void; timer: ReturnType<typeof setTimeout> }
  >();
  const encodeTarget = (target: WorldTarget) => ({
    ...target.coordinate,
    ...(target.networkId !== undefined && { networkId: target.networkId }),
  });
  const clearPending = () => {
    for (const request of pending.values()) {
      clearTimeout(request.timer);
      request.resolve([]);
    }
    pending.clear();
  };
  network.onConnected(clearPending);
  network.onPayload('illarion:menu_at', (payload) => {
    const request = typeof payload.requestId === 'number' ? pending.get(payload.requestId) : undefined;
    if (!request) {
      return;
    }
    pending.delete(payload.requestId as number);
    clearTimeout(request.timer);
    const actions = Array.isArray(payload.actions) ? payload.actions : [];
    request.resolve(
      actions.filter((action): action is WorldAction =>
        Boolean(
          action &&
          typeof action === 'object' &&
          typeof (action as Record<string, unknown>).id === 'string' &&
          typeof (action as Record<string, unknown>).label === 'string',
        ),
      ),
    );
  });
  return {
    getActions(target: WorldTarget): Promise<WorldAction[]> {
      if (disposed) {
        return Promise.resolve([]);
      }
      const requestId = ++nextRequestId;
      return new Promise((resolve) => {
        const timer = setTimeout(() => {
          pending.delete(requestId);
          resolve([]);
        }, 5000);
        pending.set(requestId, { resolve, timer });
        network.sendToServer('illarion:request_menu_at', { requestId, ...encodeTarget(target) });
      });
    },
    performAction(target: WorldTarget, action: string, detail?: string) {
      network.sendToServer('illarion:menu_action_at', {
        action,
        ...encodeTarget(target),
        ...(detail !== undefined && { detail }),
      });
    },
    lookAt(target: Coordinate | { networkId: number }, mode = 0) {
      if ('networkId' in target) {
        network.sendToServer('illarion:look_at_entity', { networkId: target.networkId, mode });
      } else {
        network.sendToServer('illarion:look_at', { ...target });
      }
    },
    walkTo(coordinate: Coordinate) {
      network.sendToServer('illarion:walk_to', { ...coordinate });
    },
    turnTo(coordinate: Coordinate, delta?: number) {
      network.sendToServer('illarion:turn_to', { ...coordinate, ...(delta !== undefined && { delta }) });
    },
    useAt(coordinate: Coordinate, count: number) {
      network.sendToServer('illarion:use_at', { ...coordinate, count });
    },
    openContainer(coordinate: Coordinate) {
      network.sendToServer('illarion:open_container_at', { ...coordinate });
    },
    pushCharacter(networkId: number, coordinate: Coordinate) {
      network.sendToServer('illarion:push_character', { networkId, ...coordinate });
    },
    dispose() {
      disposed = true;
      clearPending();
    },
  };
};
export type WorldService = ReturnType<typeof createWorldService>;
