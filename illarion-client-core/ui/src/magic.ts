import { computed, readonly, ref } from 'vue';
import { z } from 'zod';
import type { SeleneUiApi, Coordinate } from './selene';
import type { InventorySlotDefinition } from './inventoryTypes';
import type { CombatService } from './combat';

export type MagicTarget =
  | ({ kind: 'field' } & Coordinate)
  | { kind: 'character' | 'item'; networkId: number }
  | ({ kind: 'item' } & InventorySlotDefinition);
const magicSchema = z.object({
  type: z.number().int().min(0).max(3),
  flags: z.number().int().min(0).max(0xffffffff),
});

export const createMagicService = (network: SeleneUiApi['network'], combat: CombatService) => {
  const type = ref(0);
  const flags = ref(0);
  network.onPayload('illarion:magic', (payload) => {
    const result = magicSchema.safeParse(payload);
    if (result.success) {
      type.value = result.data.type;
      flags.value = result.data.flags;
    }
  });
  network.onConnected(() => {
    type.value = 0;
    flags.value = 0;
  });
  const runes = computed(() =>
    Array.from({ length: 32 }, (_, rune) => rune).filter((rune) => ((flags.value >>> 0) & (1 << rune)) !== 0),
  );
  return {
    type: readonly(type),
    flags: readonly(flags),
    runes,
    cast(selected: readonly number[], target?: MagicTarget) {
      const unique = [...new Set(selected)];
      if (!unique.length || unique.length > 5 || unique.some((rune) => !runes.value.includes(rune))) {
        return;
      }
      const castTarget =
        target ??
        (combat.targetId.value === undefined ? undefined : { kind: 'character', networkId: combat.targetId.value });
      network.sendToServer('illarion:cast', {
        spell: unique.reduce((value, rune) => value + 2 ** rune, 0),
        ...castTarget,
      });
    },
  };
};
export type MagicService = ReturnType<typeof createMagicService>;
