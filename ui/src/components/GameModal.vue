<script setup lang="ts">
import { ArrowLeft, X } from '@lucide/vue';
import { useId } from 'vue';
import MoonlightSurface from 'moonlight-ui/MoonlightSurface.vue';
import MoonlightButton from 'moonlight-ui/MoonlightButton.vue';
const titleId = useId();

withDefaults(
  defineProps<{ title: string; showBack?: boolean; dismissible?: boolean; wide?: boolean; backLabel?: string }>(),
  { dismissible: true },
);
const emit = defineEmits<{ back: []; close: [] }>();
</script>

<template>
  <div class="game-modal moonlight-ui" data-selene-interactive @mousedown.self="dismissible && emit('close')">
    <MoonlightSurface
      as="section"
      class="modal-panel moonlight-panel"
      :class="{ wide }"
      role="dialog"
      aria-modal="true"
      :aria-labelledby="titleId"
      @keydown.stop
      @keydown.esc="dismissible && ($event.preventDefault(), emit('close'))"
      @keyup.stop
    >
      <header>
        <MoonlightButton
          v-if="showBack"
          class="modal-icon-button"
          variant="ghost"
          size="icon"
          @click="emit('back')"
        >
          <ArrowLeft :size="18" aria-hidden="true" />
        </MoonlightButton>
        <h2 :id="titleId" class="ml-grow">{{ title }}</h2>
        <MoonlightButton
          v-if="dismissible"
          class="modal-icon-button"
          variant="ghost"
          size="icon"
          @click="emit('close')"
        >
          <X :size="18" aria-hidden="true" />
        </MoonlightButton>
      </header>
      <div class="ml-pad ml-scroll"><slot /></div>
      <footer v-if="$slots.footer"><slot name="footer" /></footer>
    </MoonlightSurface>
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
.modal-icon-button {
  width: 32px;
  height: 32px;
  flex-shrink: 0;
}
.modal-panel {
  width: 350px;
  max-width: calc(100% - 32px);
  max-height: calc(100% - 32px);
  color-scheme: dark;
}
.modal-panel.wide {
  width: 900px;
}
</style>
