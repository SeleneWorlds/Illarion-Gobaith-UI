<script setup lang="ts">
import { createHudLayout, hudLayoutKey } from './layout';
import { createIllarionClient } from 'illarion-client-core';
import { computed, onBeforeUnmount, onMounted, provide, reactive, ref, useTemplateRef } from 'vue';
import { adminRequestStoreKey, createAdminRequestStore } from './stores/adminRequest';
import BloodFog from './components/BloodFog.vue';
import ChatPanel from './components/ChatPanel.vue';
import ChatBubbles from './components/ChatBubbles.vue';
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
import { useSelene } from './selene';
import { bookStoreKey } from './stores/books';
import TextBook from './components/TextBook.vue';
import { vitalsStoreKey } from './stores/vitals';
import { createInventoryStore, inventoryStoreKey } from './stores/inventory';
import { createMinimapStore, minimapStoreKey } from './stores/minimap';
import { chatStoreKey, createChatStore } from './stores/chat';
import { skillsStoreKey } from './stores/skills';
import { createMagicStore, magicStoreKey } from './stores/magic';
import MagicBook from './components/MagicBook.vue';
import { useUiAssetSrc } from './composables/useClientAsset';
import { useLogger } from './composables/useLogger';
import { illarionClientKey } from './composables/useIllarionClient';

const selene = useSelene();
const grid = selene.world.getRenderGrid();
const layout = reactive(createHudLayout(grid.tileWidth, grid.tileHeight));
const uiSurface = useTemplateRef<HTMLElement>('uiSurface');
const hudDisplayScale = ref(1);
let releaseSurfaceResize: ResizeObserver | undefined;
provide(hudLayoutKey, layout);
const applyViewport = () =>
  selene.world.setViewport(
    0,
    0,
    editorEnabled.value ? layout.width : layout.viewportWidth,
    editorEnabled.value ? layout.height : layout.viewportHeight,
  );
const client = createIllarionClient(selene);
provide(illarionClientKey, client);
const { books, vitals, skills } = client;
provide(bookStoreKey, books);
provide(adminRequestStoreKey, createAdminRequestStore());
const inventory = createInventoryStore(client.inventory);
const showcases = computed(() => inventory.showcases.value);
const minimap = createMinimapStore(selene);
const chat = createChatStore(useLogger().log);
const magic = createMagicStore(client.magic, selene.storage);
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

let releaseRenderGrid: (() => void) | undefined;
let releaseF8: (() => void) | undefined;
let releaseEditorState: (() => void) | undefined;
const toggleSkills = () => {
  if (!characterSelected.value) {
    return false;
  }
  skillsOpen.value = !skillsOpen.value;
  chatExpanded.value = false;
};
onMounted(() => {
  const surface = uiSurface.value!;
  releaseSurfaceResize = new ResizeObserver(([entry]) => {
    hudDisplayScale.value = Math.min(entry.contentRect.width / 1024, entry.contentRect.height / 768);
  });
  releaseSurfaceResize.observe(surface);
  const updateLayout = () => {
    const grid = selene.world.getRenderGrid();
    Object.assign(layout, createHudLayout(grid.tileWidth, grid.tileHeight));
    selene.world.setOffscreenRendering(layout.width, layout.height);
    applyViewport();
  };
  releaseRenderGrid = selene.world.onRenderGridChanged(updateLayout);
  updateLayout();
  releaseF8 = selene.input.registerBinding(
    { id: 'game.skills', label: 'Skills', category: 'Game', defaultBinding: 'F8', allowInText: true },
    toggleSkills,
  );
  releaseEditorState = selene.network.onPayload('moonlight-editor:editor-state', (payload) => {
    editorEnabled.value = payload.enabled === true;
    minimap.setActive(!editorEnabled.value);
    applyViewport();
    selene.ui.setBundleVisible('illarion-gobaith-ui', !editorEnabled.value);
  });
});
onBeforeUnmount(() => {
  releaseSurfaceResize?.disconnect();
  releaseRenderGrid?.();
  client.dispose();
  selene.ui.setBundleVisible('illarion-gobaith-ui', true);
  releaseEditorState?.();
  releaseF8?.();
});
</script>

<template>
  <div ref="uiSurface" class="ui-surface">
    <CharacterCreation
      v-if="!characterSelected && creatingCharacter"
      @cancel="creatingCharacter = false"
      @created="creatingCharacter = false"
    />
    <CharacterSelection v-else-if="!characterSelected" @create="creatingCharacter = true" @selected="selectCharacter" />
    <main v-else class="hud" :style="{ '--hud-scale': hudDisplayScale }">
      <TooltipContainer>
        <MenuContainer>
          <InputHandler>
            <BloodFog />
            <ChatBubbles />
            <img class="bottom-frame" :src="bottomFrame" alt="" />
            <img class="top-frame" :src="topFrame" alt="" />
            <MinimapPanel v-if="!editorEnabled" @open-world-map="openWorldMap" />
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
  </div>
</template>

<style src="moonlight-ui/styles/theme.css"></style>
<style src="moonlight-ui/styles/primitives.css"></style>
<style src="./styles.css"></style>

<style scoped>
.ui-surface {
  position: absolute;
  inset: 0;
}

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
