<script setup lang="ts">
import { useId } from 'vue';
import { useI18n } from '../composables/useI18n';

const { t } = useI18n();

withDefaults(
  defineProps<{ title: string; showBack?: boolean; showClose?: boolean; wide?: boolean; backLabel?: string }>(),
  { showClose: true },
);
const emit = defineEmits<{ back: []; close: [] }>();
const titleId = useId();
</script>

<template>
  <section
    class="dialog"
    :class="{ wide }"
    role="dialog"
    aria-modal="true"
    :aria-labelledby="titleId"
    @keydown.stop
    @keydown.esc="showClose && ($event.preventDefault(), emit('close'))"
    @keyup.stop
  >
    <header>
      <button
        v-if="showBack"
        class="icon-button"
        type="button"
        :aria-label="backLabel || t('menu.back', 'Back to menu')"
        @click="emit('back')"
      >
        ‹
      </button>
      <h2 :id="titleId">{{ title }}</h2>
      <button
        v-if="showClose"
        class="icon-button"
        type="button"
        :aria-label="t('menu.close', 'Close menu')"
        @click="emit('close')"
      >
        ×
      </button>
    </header>
    <slot />
  </section>
</template>

<style scoped>
.dialog {
  width: 350px;
  max-width: calc(100% - 32px);
  max-height: calc(100% - 32px);
  overflow: auto;
  padding: 18px;
  border: 1px solid rgb(185 162 120 / 65%);
  border-radius: 8px;
  background: rgb(30 27 23 / 86%);
  backdrop-filter: blur(4px);
  box-shadow: 0 12px 36px rgb(0 0 0 / 30%);
  color: #eee5d5;
  font:
    13px/1.45 Arial,
    Helvetica,
    sans-serif;
}
.dialog.wide {
  width: 900px;
}
header {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-bottom: 18px;
}
h2 {
  flex: 1;
  margin: 0;
  font-size: 16px;
  font-weight: 600;
}
:deep(button) {
  padding: 8px 12px;
  border: 1px solid rgb(185 162 120 / 40%);
  border-radius: 5px;
  background: rgb(185 162 120 / 12%);
  color: #eee5d5;
  font: inherit;
  cursor: pointer;
}
:deep(button:hover:not(:disabled)) {
  background: rgb(185 162 120 / 22%);
}
.icon-button {
  display: grid;
  place-items: center;
  width: 26px;
  height: 26px;
  padding: 0;
  border-color: transparent;
  background: transparent;
  font-size: 20px;
  line-height: 1;
}
:deep(button:disabled) {
  opacity: 0.5;
  cursor: default;
}
:deep(button:focus-visible),
:deep(textarea:focus-visible),
:deep(input:focus-visible),
:deep(select:focus-visible) {
  outline: 2px solid #b9a278;
  outline-offset: 2px;
}
:deep(input:not([type='range']):not([type='checkbox']):not([type='radio'])),
:deep(select) {
  min-width: 0;
  padding: 4px 6px;
  border: 1px solid rgb(185 162 120 / 40%);
  border-radius: 5px;
  background: rgb(0 0 0 / 25%);
  color: #eee5d5;
  font: inherit;
  color-scheme: dark;
}
:deep(fieldset) {
  border: 1px solid rgb(185 162 120 / 40%);
  border-radius: 5px;
}
</style>
