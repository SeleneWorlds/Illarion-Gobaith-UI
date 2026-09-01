<script setup lang="ts">
import { ref } from 'vue';
import BloodFog from './components/BloodFog.vue';
import ChatPanel from './components/ChatPanel.vue';
import CounterPanel from './components/CounterPanel.vue';
import InventoryPanel from './components/InventoryPanel.vue';
import MinimapPanel from './components/MinimapPanel.vue';
import StatusPanel from './components/StatusPanel.vue';
import type { SeleneUiApi } from './selene';

defineProps<{ selene: SeleneUiApi }>();
const counter = ref(1);
</script>

<template>
  <main class="hud" aria-label="Illarion game interface">
    <BloodFog :selene="selene" />
    <img class="hud__bottom-frame" :src="selene.resolveAsset('./assets/gui_bottom.png')" alt="">
    <img class="hud__top-frame" :src="selene.resolveAsset('./assets/gui_top.png')" alt="">
    <MinimapPanel :selene="selene" />
    <ChatPanel :selene="selene" />
    <CounterPanel v-model="counter" :selene="selene" />
    <StatusPanel :selene="selene" />
    <InventoryPanel :selene="selene" :counter="counter" />
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

.hud__bottom-frame,
.hud__top-frame {
  position: absolute;
  display: block;
  user-select: none;
}

.hud__bottom-frame { left: 0; bottom: 0; width: 1024px; height: 512px; }
.hud__top-frame { top: 0; right: 0; width: 256px; height: 256px; }
</style>
