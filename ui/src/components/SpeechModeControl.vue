<script setup lang="ts">
// TODO deslop file
import { ref } from 'vue';
import { useSelene } from '../selene';
import { speechModes, type SpeechModeId } from '../chatModes';
import ContextMenu from './ContextMenu.vue';

const languages = ['Common', 'Ancient', 'Halfling', 'Dwarf', 'Elf', 'Human', 'Lizard', 'Orc', 'Fairy', 'Gnoll', 'Goblin'] as const;
const selene = useSelene();
const selectedMode = defineModel<SpeechModeId>({ required: true });
const emit = defineEmits<{
  interactionComplete: [];
  languageSelect: [language: string];
}>();
const menuOpen = ref(false);
const mode = () => speechModes.find(item => item.id === selectedMode.value) ?? speechModes[0];
const cycleMode = () => {
  menuOpen.value = false;
  const index = speechModes.findIndex(item => item.id === selectedMode.value);
  selectedMode.value = speechModes[(index + 1) % speechModes.length].id;
  emit('interactionComplete');
};
const selectMode = (id: SpeechModeId) => {
  selectedMode.value = id;
  menuOpen.value = false;
  emit('interactionComplete');
};
const selectLanguage = (language: string) => {
  menuOpen.value = false;
  emit('languageSelect', language);
  emit('interactionComplete');
};
</script>

<template>
  <button class="button" type="button" data-selene-interactive :data-mode="mode().id" :aria-label="`Speech mode: ${mode().name}`" aria-haspopup="menu" :aria-expanded="menuOpen" :title="`${mode().name} — click to change speech mode; right-click for menu`" @click.stop="cycleMode" @contextmenu.prevent.stop="menuOpen = true">
    <img :src="selene.resolveAsset(`./assets/${mode().icon}`)" alt="">
  </button>
  <ContextMenu v-model:open="menuOpen" class="menu" label="Speech options">
    <li v-for="item in speechModes" v-show="item.id !== selectedMode" :key="item.id">
      <button type="button" @click="selectMode(item.id)">{{ item.name === 'Normal' ? 'Speak' : item.name }}</button>
    </li>
    <li class="separator" role="separator" />
    <li v-for="language in languages" :key="language">
      <button type="button" @click="selectLanguage(language)">{{ language }}</button>
    </li>
  </ContextMenu>
</template>

<style scoped>
.button { position: absolute; left: 799px; bottom: 146px; width: 30px; height: 30px; padding: 0; overflow: hidden; border: 0; background: transparent; cursor: pointer; pointer-events: auto; }
.button img { display: block; width: 30px; height: 30px; }
.button:focus-visible { outline: 1px solid #b7d9ba; outline-offset: 1px; }
.menu { left: 770px; bottom: 178px; }
</style>
