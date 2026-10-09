<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, provide, ref, useTemplateRef } from 'vue';
import { adminRequestStoreKey, createAdminRequestStore } from './stores/adminRequest';
import BloodFog from './components/BloodFog.vue';
import ChatPanel from './components/ChatPanel.vue';
import EscapeMenu from './components/EscapeMenu.vue';
import SkillsPanel from './components/SkillsPanel.vue';
import CounterPanel from './components/CounterPanel.vue';
import InputHandler from './components/InputHandler.vue';
import InventoryPanel from './components/InventoryPanel.vue';
import ShowcasePanel from './components/ShowcasePanel.vue';
import MinimapPanel from './components/MinimapPanel.vue';
import MenuContainer from './components/MenuContainer.vue';
import MenuStructMenu from './components/MenuStructMenu.vue';
import WorldMap from './components/WorldMap.vue';
import StatusPanel from './components/StatusPanel.vue';
import TooltipContainer from './components/TooltipContainer.vue';
import CharacterSelection from './components/CharacterSelection.vue';
import CharacterCreation from './components/CharacterCreation.vue';
import { seleneKey, useSelene } from './selene';
import { bookStoreKey, createBookStore } from './stores/books';
import TextBook from './components/TextBook.vue';
import { createVitalsStore, vitalsStoreKey } from './stores/vitals';
import { createInventoryStore, inventoryStoreKey } from './stores/inventory';
import { createMinimapStore, minimapStoreKey } from './stores/minimap';
import { chatStoreKey, createChatStore } from './stores/chat';
import { createSkillsStore, skillsStoreKey } from './stores/skills';
import { createMagicStore, magicStoreKey } from './stores/magic';
import MagicBook from './components/MagicBook.vue';
import { useUiAssetSrc } from './composables/useClientAsset';
import { useLogger } from './composables/useLogger';

const originalSelene = useSelene();
const books = createBookStore(originalSelene.network);
const selene = { ...originalSelene, network: books.network };
provide(seleneKey, selene);
provide(bookStoreKey, books);
provide(adminRequestStoreKey, createAdminRequestStore());
const vitals = createVitalsStore(selene.network);
const inventory = createInventoryStore(selene.network);
const showcases = computed(() => inventory.showcases.value);
const minimap = createMinimapStore(selene);
const chat = createChatStore(useLogger().log, books.receive);
const skills = createSkillsStore(selene.network);
const magic = createMagicStore(selene);
const worldMap = useTemplateRef<InstanceType<typeof WorldMap>>('worldMap');
const openWorldMap = () => worldMap.value?.open();
const bottomFrame = useUiAssetSrc('gui_bottom.png');
const topFrame = useUiAssetSrc('gui_top.png');
const characterSelected = ref(false);
const creatingCharacter = ref(false);
const skillsOpen = ref(false);
const chatExpanded = ref(false);
const editorEnabled = ref(false);
const openSkills = () => {
  skillsOpen.value = true;
  chatExpanded.value = false;
};

provide(vitalsStoreKey, vitals);
provide(inventoryStoreKey, inventory);
provide(minimapStoreKey, minimap);
provide(chatStoreKey, chat);
provide(skillsStoreKey, skills);
provide(magicStoreKey, magic);
const selectCharacter = (characterId: number) => {
  characterSelected.value = true;
  void minimap.initialize(characterId);
  void magic.initialize(characterId);
};

let releaseF8: (() => void) | undefined;
let releaseEditorState: (() => void) | undefined;
const toggleSkills = (event: KeyboardEvent) => {
  if (!characterSelected.value || event.key !== 'F8' || event.repeat) {
    return;
  }
  event.preventDefault();
  event.stopImmediatePropagation();
  skillsOpen.value = !skillsOpen.value;
  chatExpanded.value = false;
};
onMounted(() => {
  releaseF8 = selene.input.captureKeys('F8');
  window.addEventListener('keydown', toggleSkills, true);
  releaseEditorState = selene.network.onPayload('moonlight-editor:editor-state', (payload) => {
    editorEnabled.value = payload.enabled === true;
    selene.world.setViewport?.(0, 0, editorEnabled.value ? 1024 : 839, editorEnabled.value ? 768 : 419);
    selene.ui.setBundleVisible('illarion-gobaith-ui', !editorEnabled.value);
  });
});
onBeforeUnmount(() => {
  selene.ui.setBundleVisible('illarion-gobaith-ui', true);
  releaseEditorState?.();
  releaseF8?.();
  window.removeEventListener('keydown', toggleSkills, true);
});
</script>

<template>
  <CharacterCreation
    v-if="!characterSelected && creatingCharacter"
    @cancel="creatingCharacter = false"
    @created="creatingCharacter = false"
  />
  <CharacterSelection v-else-if="!characterSelected" @create="creatingCharacter = true" @selected="selectCharacter" />
  <main v-else class="hud" aria-label="Illarion game interface">
    <TooltipContainer>
      <MenuContainer>
        <InputHandler>
          <BloodFog />
          <img class="bottom-frame" :src="bottomFrame" alt="" />
          <img class="top-frame" :src="topFrame" alt="" />
          <MinimapPanel @open-world-map="openWorldMap" />
          <WorldMap ref="worldMap" />
          <ChatPanel
            :expanded="chatExpanded || skillsOpen"
            :hidden="skillsOpen"
            @open-skills="openSkills"
            @set-expanded="chatExpanded = $event"
          />
          <SkillsPanel :active="skillsOpen" @close="skillsOpen = false" />
          <MagicBook />
          <TextBook />
          <CounterPanel />
          <StatusPanel />
          <InventoryPanel />
          <ShowcasePanel v-for="showcase in showcases" :key="showcase.id" :showcase="showcase" />
          <MenuStructMenu />
          <EscapeMenu v-if="!editorEnabled" />
        </InputHandler>
      </MenuContainer>
    </TooltipContainer>
  </main>
</template>

<style src="./styles.css"></style>

<style scoped>
.hud {
  --hud-scale: 1;
  position: absolute;
  left: 50%;
  bottom: 0;
  width: 1024px;
  height: 768px;
  overflow: hidden;
  transform: translateX(-50%) scale(var(--hud-scale));
  transform-origin: bottom center;
}

.bottom-frame,
.top-frame {
  position: absolute;
  display: block;
  user-select: none;
}

.bottom-frame {
  left: 0;
  bottom: 0;
  width: 1024px;
  height: 512px;
}
.top-frame {
  top: 0;
  right: 0;
  width: 256px;
  height: 256px;
}
</style>
