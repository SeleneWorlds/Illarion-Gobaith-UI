<script setup lang="ts">
import { useId } from 'vue';
import MoonlightSurface from 'moonlight-ui/MoonlightSurface.vue';
import MoonlightButton from 'moonlight-ui/MoonlightButton.vue';
import { useI18n } from '../composables/useI18n';
const { t } = useI18n();
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
          variant="ghost"
          size="icon"
          :aria-label="backLabel || t('menu.back', 'Back to menu')"
          @click="emit('back')"
          >‹</MoonlightButton
        >
        <h2 :id="titleId" class="ml-grow">{{ title }}</h2>
        <MoonlightButton
          v-if="dismissible"
          variant="ghost"
          size="icon"
          :aria-label="t('menu.close', 'Close menu')"
          @click="emit('close')"
          >×</MoonlightButton
        >
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
