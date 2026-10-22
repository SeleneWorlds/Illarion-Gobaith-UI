import { inject, readonly, ref, type ComputedRef, type InjectionKey, type Ref } from 'vue';
import type { MagicService, MagicTarget } from 'illarion-client-core';
import type { SeleneUiApi } from '../selene';
import type { Coordinate } from '../selene';
import type { InventorySlotDefinition } from '../inventory';

export interface MagicStore {
  readonly type: Readonly<Ref<number>>;
  readonly flags: Readonly<Ref<number>>;
  readonly runes: ComputedRef<readonly number[]>;
  readonly active: Readonly<Ref<boolean>>;
  readonly selected: Readonly<Ref<readonly number[]>>;
  readonly bookmarks: Readonly<Ref<readonly number[]>>;
  initialize(characterId: number): Promise<void>;
  begin(): void;
  cancel(): void;
  toggleRune(rune: number): void;
  clearSelection(): void;
  store(index?: number): void;
  recall(index: number): void;
  clearBookmark(index: number): void;
  targetField(coordinate: Coordinate): void;
  targetEntity(kind: 'character' | 'item', networkId: number): void;
  targetSlot(slot: InventorySlotDefinition): void;
  isTargetSlot(slot: InventorySlotDefinition): boolean;
  cast(): void;
}

export const magicStoreKey: InjectionKey<MagicStore> = Symbol('magic-store');

export const createMagicStore = (magic: MagicService, storage: SeleneUiApi['storage']): MagicStore => {
  const { type, flags, runes } = magic;
  const active = ref(false);
  const selected = ref<number[]>([]);
  const bookmarks = ref<number[]>(Array(8).fill(0));
  const target = ref<MagicTarget>();
  let characterId: number | undefined;

  const bookmarkKey = (index: number) => `player.${characterId}.spell${index}`;
  const saveBookmark = (index: number) => {
    if (characterId !== undefined) {
      void storage.save(bookmarkKey(index), String(bookmarks.value[index] ?? 0));
    }
  };

  const clear = () => {
    active.value = false;
    selected.value = [];
    target.value = undefined;
  };

  return {
    type,
    flags,
    runes,
    active: readonly(active),
    selected: readonly(selected),
    bookmarks: readonly(bookmarks),
    async initialize(nextCharacterId) {
      characterId = nextCharacterId;
      bookmarks.value = await Promise.all(
        Array.from({ length: 8 }, async (_, index) => {
          const stored = await storage.load(bookmarkKey(index));
          const value = stored === null ? 0 : Number(stored);
          return Number.isInteger(value) && value >= 0 && value <= 0xffffffff ? value : 0;
        }),
      );
    },
    begin() {
      active.value = runes.value.length > 0;
    },
    cancel: clear,
    toggleRune(rune) {
      if (!runes.value.includes(rune)) {
        return;
      }
      const index = selected.value.indexOf(rune);
      if (index >= 0) {
        selected.value.splice(index, 1);
      } else if (selected.value.length < 5) {
        selected.value.push(rune);
      }
    },
    clearSelection() {
      selected.value = [];
    },
    store(index) {
      if (selected.value.length === 0) {
        return;
      }
      const targetIndex = index ?? bookmarks.value.findIndex((spell) => spell === 0);
      if (targetIndex < 0 || targetIndex >= bookmarks.value.length) {
        return;
      }
      bookmarks.value[targetIndex] = selected.value.reduce((value, rune) => value + 2 ** rune, 0);
      saveBookmark(targetIndex);
      selected.value = [];
    },
    recall(index) {
      const spell = bookmarks.value[index] ?? 0;
      if (spell === 0) {
        return;
      }
      selected.value = runes.value.filter((rune) => (spell & (2 ** rune)) !== 0).slice(0, 5);
    },
    clearBookmark(index) {
      if (index < 0 || index >= bookmarks.value.length) {
        return;
      }
      bookmarks.value[index] = 0;
      saveBookmark(index);
    },
    targetField(coordinate) {
      target.value = { kind: 'field', ...coordinate };
    },
    targetEntity(kind, networkId) {
      target.value = { kind, networkId };
    },
    targetSlot(slot) {
      target.value = { kind: 'item', viewId: slot.viewId, slotId: slot.slotId };
    },
    isTargetSlot(slot) {
      return (
        target.value?.kind === 'item' &&
        'viewId' in target.value &&
        target.value.viewId === slot.viewId &&
        target.value.slotId === slot.slotId
      );
    },
    cast() {
      magic.cast(selected.value, target.value);
      clear();
    },
  };
};

export const useMagicStore = (): MagicStore => {
  const store = inject(magicStoreKey);
  if (!store) {
    throw new Error('Magic store was not provided.');
  }
  return store;
};
