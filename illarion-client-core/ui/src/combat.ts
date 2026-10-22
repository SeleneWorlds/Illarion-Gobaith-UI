import { readonly, ref } from 'vue';
import type { SeleneUiApi } from './selene';

export const createCombatService = (network: SeleneUiApi['network']) => {
  const targetId = ref<number>();
  network.onPayload('illarion:set_combat_target', (payload) => {
    if (typeof payload.networkId === 'number' && Number.isSafeInteger(payload.networkId)) {
      targetId.value = payload.networkId === -1 ? undefined : payload.networkId;
    }
  });
  network.onConnected(() => {
    targetId.value = undefined;
  });
  return {
    targetId: readonly(targetId),
    setTarget(networkId?: number) {
      network.sendToServer('illarion:set_combat_target', { networkId: networkId ?? -1 });
    },
  };
};
export type CombatService = ReturnType<typeof createCombatService>;
