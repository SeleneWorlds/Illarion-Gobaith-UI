<script setup lang="ts">
import { provide, useTemplateRef } from 'vue';
import BloodFog from './components/BloodFog.vue';
import ChatPanel from './components/ChatPanel.vue';
import CounterPanel from './components/CounterPanel.vue';
import InputHandler from './components/InputHandler.vue';
import InventoryPanel from './components/InventoryPanel.vue';
import MinimapPanel from './components/MinimapPanel.vue';
import MenuContainer from './components/MenuContainer.vue';
import WorldMap from './components/WorldMap.vue';
import StatusPanel from './components/StatusPanel.vue';
import TooltipContainer from './components/TooltipContainer.vue';
import { useSelene } from './selene';
import { createVitalsStore, vitalsStoreKey } from './stores/vitals';
import { createInventoryStore, inventoryStoreKey } from './stores/inventory';
import { createMinimapStore, minimapStoreKey } from './stores/minimap';

const selene = useSelene();
const vitals = createVitalsStore(selene.network);
const inventory = createInventoryStore(selene.network);
const minimap = createMinimapStore(selene);
const worldMap = useTemplateRef<InstanceType<typeof WorldMap>>('worldMap');
const openWorldMap = () => worldMap.value?.open();

provide(vitalsStoreKey, vitals);
provide(inventoryStoreKey, inventory);
provide(minimapStoreKey, minimap);
void minimap.initialize();
</script>

<template>
  <main class="hud" aria-label="Illarion game interface">
    <TooltipContainer>
      <MenuContainer>
        <InputHandler />
        <BloodFog />
        <img class="bottom-frame" :src="selene.resolveAsset('./assets/gui_bottom.png')" alt="" />
        <img class="top-frame" :src="selene.resolveAsset('./assets/gui_top.png')" alt="" />
        <MinimapPanel @open-world-map="openWorldMap" />
        <WorldMap ref="worldMap" />
        <ChatPanel />
        <CounterPanel />
        <StatusPanel />
        <InventoryPanel />
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
