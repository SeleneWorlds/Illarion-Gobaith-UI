<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, watchEffect } from 'vue';
import { useUiAssetSrc } from '../composables/useClientAsset';
import { useMagicStore } from '../stores/magic';
import { useSelene } from '../selene';
import { useTooltip } from '../overlays';
import { useMenu } from '../overlays';
import RuneImage from './RuneImage.vue';
import SpellBookmarkMenu from './SpellBookmarkMenu.vue';

const runePrefixes = ['m', 'p', 'n', 'd'] as const;
const selene = useSelene();
const magic = useMagicStore();
const tooltip = useTooltip();
const menu = useMenu();
const runeNames: ReadonlyArray<ReadonlyArray<string | undefined>> = [
  [
    'KEL',
    'RA',
    'HEPT',
    'TAH',
    'PEN',
    'LUK',
    'MES',
    'ORL',
    'TAUR',
    'URA',
    'IRA',
    'CUN',
    'SAV',
    'YEG',
    'JUS',
    'QWAN',
    'SOLH',
    'SIH',
    'FHAN',
    'LEV',
    'FHEN',
    'KAH',
    'ANTH',
    'DUN',
    'PHERCC',
    'BHONAA',
    'SUL',
  ],
  [
    'BROCH',
    'DEMN',
    'BARA',
    'FESS',
    'BRAG',
    undefined,
    'HUM',
    'QUON',
    undefined,
    'PROT',
    'HOH',
    undefined,
    'NID',
    'USH',
    'POS',
    undefined,
    'REA',
    'ELD',
    undefined,
    'TAN',
    'VIE',
    'MET',
    undefined,
    'POI',
    'GRE',
    'FIN',
    'ALT',
    'DAR',
  ],
  [],
  [
    'Healing/Cleaning',
    'Poison/Destruction',
    'Lifeless',
    'Life',
    'Ghost',
    'Firnis blossom',
    'Foot leaf',
    'Heath flower',
    'Virgin weed',
    'Sun herb',
    'Sand berry',
    'Flamegoblet blossom',
    'Steppe fern',
    "Herder's mushroom",
    'Toadstool',
    'Red head',
    "Night angel's blossom",
    'Bulbsponge mushroom',
    'Four-leafed oneberry',
    'Anger berry',
    'Rotten tree bark',
    'Donf leaf',
    'Yellow weed',
    'Desert sky capsule',
    'Life root',
    'Ash',
    'Black thistle',
    'Ruby',
  ],
];
const background = useUiAssetSrc('menu_book.png');
const selection = useUiAssetSrc('mark_magic-0.png');
const storeButton = useUiAssetSrc('spellbook_store.png');
const clearButton = useUiAssetSrc('spellbook_close.png');
const hoverSelection = useUiAssetSrc('magic_select.png');
const magicCursor = useUiAssetSrc('cursor_magic.png');
const runePrefix = computed(() => runePrefixes[magic.type.value] ?? runePrefixes[0]);
const isOpen = computed(() => magic.active.value);
const runeName = (rune: number) => runeNames[magic.type.value]?.[rune] ?? `Rune ${rune + 1}`;
const showRuneTooltip = (event: Event, rune: number) => {
  if (event.currentTarget instanceof HTMLElement) {
    tooltip.show({ anchor: event.currentTarget, title: runeName(rune), immediate: true });
  }
};
const showSimpleTooltip = (event: Event, title: string) => {
  if (event.currentTarget instanceof HTMLElement) {
    tooltip.show({ anchor: event.currentTarget, title, immediate: true });
  }
};
const showSelectedSpellTooltip = (event: Event) => {
  const names = magic.selected.value.map(runeName);
  if (names.length > 0) {
    showSimpleTooltip(event, names.join(' '));
  }
};
const bookmarkRunes = (index: number) =>
  magic.runes.value.filter((rune) => ((magic.bookmarks.value[index] ?? 0) & (2 ** rune)) !== 0).slice(0, 5);
const showBookmarkTooltip = (event: Event, index: number) => {
  const names = bookmarkRunes(index).map(runeName);
  if (names.length > 0) {
    showSimpleTooltip(event, names.join(' '));
  }
};
const openSpellMenu = async (event: MouseEvent, index?: number) => {
  const stored = index !== undefined && (magic.bookmarks.value[index] ?? 0) !== 0;
  const action = await menu.open<'write' | 'recall' | 'clear'>(
    SpellBookmarkMenu,
    {
      canWrite:
        index === undefined
          ? magic.selected.value.length > 0 && magic.bookmarks.value.includes(0)
          : !stored && magic.selected.value.length > 0,
      canRecall: stored,
      canClear: index === undefined ? magic.selected.value.length > 0 : stored,
    },
    { label: 'Spell actions', position: { x: event.clientX, y: event.clientY } },
  );
  if (action === 'write') {
    magic.store(index);
  } else if (action === 'recall' && index !== undefined) {
    magic.recall(index);
  } else if (action === 'clear') {
    if (index === undefined) {
      magic.clearSelection();
    } else {
      magic.clearBookmark(index);
    }
  }
};

const onKeyDown = (event: KeyboardEvent) => {
  if (event.key !== 'Alt') {
    return;
  }
  event.preventDefault();
  magic.begin();
};
const onKeyUp = (event: KeyboardEvent) => {
  if (event.key === 'Alt') {
    tooltip.hide();
    magic.cast();
  }
};

let releaseAlt: (() => void) | undefined;
const originalCursor = document.documentElement.style.cursor;
watchEffect(() => {
  document.documentElement.style.cursor =
    magic.active.value && magicCursor.value ? `url("${magicCursor.value}"), auto` : originalCursor;
});
onMounted(() => {
  releaseAlt = selene.input.captureKeys('Alt');
  window.addEventListener('keydown', onKeyDown, true);
  window.addEventListener('keyup', onKeyUp, true);
  window.addEventListener('blur', magic.cancel);
});
onBeforeUnmount(() => {
  document.documentElement.style.cursor = originalCursor;
  releaseAlt?.();
  window.removeEventListener('keydown', onKeyDown, true);
  window.removeEventListener('keyup', onKeyUp, true);
  window.removeEventListener('blur', magic.cancel);
});
</script>

<template>
  <section
    v-if="isOpen"
    class="magic-book"
    aria-label="Magic book"
    @pointerdown.stop
    @pointerup.stop
    @click.stop
    @contextmenu.prevent.stop
  >
    <img class="book" :src="background" alt="" />
    <div class="runes">
      <button
        v-for="rune in magic.runes.value"
        :key="rune"
        class="rune"
        type="button"
        :aria-label="runeName(rune)"
        :aria-pressed="magic.selected.value.includes(rune)"
        @click="magic.toggleRune(rune)"
        @mouseenter="showRuneTooltip($event, rune)"
        @mouseleave="tooltip.hide"
        @focus="showRuneTooltip($event, rune)"
        @blur="tooltip.hide"
      >
        <RuneImage :type="runePrefix" :rune="rune" />
        <img class="hover-selection" :src="hoverSelection" alt="" />
        <img v-if="magic.selected.value.includes(rune)" class="selected" :src="selection" alt="" />
      </button>
    </div>
    <div class="spell" aria-label="Selected spell">
      <RuneImage v-for="rune in magic.selected.value" :key="rune" :type="runePrefix" :rune="rune" />
    </div>
    <button
      v-if="magic.selected.value.length > 0 && magic.bookmarks.value.includes(0)"
      class="store-spell"
      type="button"
      aria-label="Write down this spell"
      @click="magic.store()"
      @mouseenter="showSimpleTooltip($event, 'Write down this spell')"
      @mouseleave="tooltip.hide"
    >
      <img :src="storeButton" alt="" />
    </button>
    <button
      v-if="magic.selected.value.length > 0"
      class="clear-spell"
      type="button"
      aria-label="Cancel spell"
      @click="magic.clearSelection()"
      @mouseenter="showSimpleTooltip($event, 'Cancel spell')"
      @mouseleave="tooltip.hide"
    >
      <img :src="clearButton" alt="" />
    </button>
    <button
      v-for="(_, index) in magic.bookmarks.value"
      :key="`bookmark-${index}`"
      class="bookmark"
      :class="`bookmark-${index}`"
      type="button"
      :aria-label="`Stored spell ${index + 1}`"
      @click="magic.recall(index)"
      @contextmenu.prevent.stop="openSpellMenu($event, index)"
      @mouseenter="showBookmarkTooltip($event, index)"
      @mouseleave="tooltip.hide"
      @focus="showBookmarkTooltip($event, index)"
      @blur="tooltip.hide"
    >
      <RuneImage v-for="rune in bookmarkRunes(index)" :key="rune" :type="runePrefix" :rune="rune" />
    </button>
    <button
      class="spell-hit-area"
      type="button"
      aria-label="Current spell"
      @contextmenu.prevent.stop="openSpellMenu($event)"
      @mouseenter="showSelectedSpellTooltip"
      @mouseleave="tooltip.hide"
    />
  </section>
</template>

<style scoped>
.magic-book {
  position: absolute;
  left: 0;
  bottom: -20px;
  z-index: 9;
  /* The source image has a transparent tail after the book artwork. */
  width: 805px;
  height: 320px;
  user-select: none;
  pointer-events: auto;
}
.book {
  position: absolute;
  inset: 0;
  width: 915px;
  height: 320px;
  pointer-events: none;
}
.runes {
  position: absolute;
  left: 420px;
  top: 15px;
  display: grid;
  grid-template-columns: repeat(7, 50px);
  grid-auto-rows: 50px;
  width: 350px;
  height: 250px;
}
.rune {
  position: relative;
  width: 50px;
  height: 50px;
  padding: 0;
  border: 0;
  background: transparent;
  cursor: pointer;
  display: grid;
  place-items: center;
}
.rune :deep(img) {
  display: block;
}
.selected {
  position: absolute;
  inset: 0;
  width: 50px;
  height: 50px;
  pointer-events: none;
}
.rune > .hover-selection {
  position: absolute;
  inset: 50% auto auto 50%;
  display: none;
  width: 59px;
  height: 59px;
  transform: translate(-50%, -50%);
  pointer-events: none;
}
.rune:hover > .hover-selection,
.rune:focus-visible > .hover-selection {
  display: block;
}
.spell {
  position: absolute;
  left: 60px;
  top: 35px;
  display: flex;
  width: 175px;
  height: 35px;
}
.spell :deep(img) {
  display: block;
  margin: auto 6.5px;
}
.store-spell,
.clear-spell {
  position: absolute;
  top: 25px;
  width: 64px;
  height: 64px;
  padding: 0;
  border: 0;
  background: transparent;
  cursor: pointer;
}
.store-spell {
  left: 240px;
}
.clear-spell {
  left: 320px;
}
.store-spell img,
.clear-spell img {
  width: 64px;
  height: 64px;
  pointer-events: none;
}
.bookmark {
  position: absolute;
  display: flex;
  width: 150px;
  height: 35px;
  padding: 0;
  border: 0;
  background: transparent;
  cursor: pointer;
}
.bookmark:empty {
  cursor: default;
}
.bookmark :deep(img) {
  display: block;
  margin: auto 6.5px;
}
.bookmark-0,
.bookmark-4 {
  top: 70px;
}
.bookmark-1,
.bookmark-5 {
  top: 120px;
}
.bookmark-2,
.bookmark-6 {
  top: 170px;
}
.bookmark-3,
.bookmark-7 {
  top: 220px;
}
.bookmark-0,
.bookmark-1,
.bookmark-2,
.bookmark-3 {
  left: 60px;
}
.bookmark-4,
.bookmark-5,
.bookmark-6,
.bookmark-7 {
  left: 230px;
}
.spell-hit-area {
  position: absolute;
  left: 60px;
  top: 20px;
  width: 150px;
  height: 35px;
  padding: 0;
  border: 0;
  background: transparent;
}
</style>
