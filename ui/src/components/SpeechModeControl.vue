<script setup lang="ts">
import { useSelene } from '../selene';
import { useMenu } from '../overlays';
import { speechModes, type SpeechModeId } from '../chatModes';
import SpeechOptionsMenu from './SpeechOptionsMenu.vue';

const languages = [
  'Common',
  'Ancient',
  'Halfling',
  'Dwarf',
  'Elf',
  'Human',
  'Lizard',
  'Orc',
  'Fairy',
  'Gnoll',
  'Goblin',
] as const;
const selene = useSelene();
const menu = useMenu();
const selectedMode = defineModel<SpeechModeId>({ required: true });
const emit = defineEmits<{
  languageSelect: [language: string];
}>();
const mode = () => speechModes.find((item) => item.id === selectedMode.value) ?? speechModes[0];
const cycleMode = () => {
  menu.close();
  const index = speechModes.findIndex((item) => item.id === selectedMode.value);
  selectedMode.value = speechModes[(index + 1) % speechModes.length].id;
};
type SpeechSelection = { mode: SpeechModeId } | { language: string };
const openMenu = async (event: MouseEvent) => {
  const selection = await menu.open<SpeechSelection>(
    SpeechOptionsMenu,
    { selectedMode: selectedMode.value, languages },
    { label: 'Speech options', anchor: event.currentTarget as HTMLElement },
  );
  if (!selection) {
    return;
  }
  if ('mode' in selection) {
    selectedMode.value = selection.mode;
  } else {
    emit('languageSelect', selection.language);
  }
};
</script>

<template>
  <button
    class="button"
    type="button"
    data-selene-interactive
    :data-mode="mode().id"
    :aria-label="`Speech mode: ${mode().name}`"
    aria-haspopup="menu"
    :aria-expanded="menu.isOpen(SpeechOptionsMenu)"
    :title="`${mode().name} — click to change speech mode; right-click for menu`"
    @click.left.stop="cycleMode"
    @contextmenu.prevent.stop="openMenu"
  >
    <img :src="selene.resolveAsset(`./assets/${mode().icon}`)" alt="" />
  </button>
</template>

<style scoped>
.button {
  position: absolute;
  left: 799px;
  bottom: 146px;
  width: 30px;
  height: 30px;
  padding: 0;
  overflow: hidden;
  border: 0;
  background: transparent;
  cursor: pointer;
  pointer-events: auto;
}
.button img {
  display: block;
  width: 30px;
  height: 30px;
}
.button:focus-visible {
  outline: 1px solid #b7d9ba;
  outline-offset: 1px;
}
</style>
