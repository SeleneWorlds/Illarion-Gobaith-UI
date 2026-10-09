<script setup lang="ts">
import GameDialog from './GameDialog.vue';

withDefaults(
  defineProps<{ title: string; showBack?: boolean; dismissible?: boolean; wide?: boolean; backLabel?: string }>(),
  { dismissible: true },
);
const emit = defineEmits<{ back: []; close: [] }>();
</script>

<template>
  <div class="game-modal" data-selene-interactive @mousedown.self="dismissible && emit('close')">
    <GameDialog
      :title="title"
      :show-back="showBack"
      :show-close="dismissible"
      :wide="wide"
      :back-label="backLabel"
      @back="emit('back')"
      @close="emit('close')"
    >
      <slot />
    </GameDialog>
  </div>
</template>

<style scoped>
.game-modal {
  position: absolute;
  z-index: 40;
  inset: 0;
  display: grid;
  place-items: center;
  background: rgb(0 0 0 / 15%);
  pointer-events: auto;
}
</style>
