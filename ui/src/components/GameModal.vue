<script setup lang="ts">
import { useId } from 'vue';

defineProps<{ title: string; showBack?: boolean }>();
const emit = defineEmits<{ back: []; close: [] }>();
const titleId = useId();
</script>

<template>
  <div class="escape-menu" data-selene-interactive @mousedown.self="emit('close')">
    <section
      class="dialog"
      role="dialog"
      aria-modal="true"
      :aria-labelledby="titleId"
      @keydown.stop
      @keydown.esc.prevent="emit('close')"
      @keyup.stop
    >
      <header>
        <button v-if="showBack" class="icon-button" type="button" aria-label="Back to menu" @click="emit('back')">
          ‹
        </button>
        <h2 :id="titleId">{{ title }}</h2>
        <button class="icon-button" type="button" aria-label="Close menu" @click="emit('close')">×</button>
      </header>
      <slot />
    </section>
  </div>
</template>

<style scoped>
.escape-menu {
  position: absolute;
  z-index: 40;
  inset: 0;
  display: grid;
  place-items: center;
  background: rgb(0 0 0 / 15%);
  pointer-events: auto;
}
.dialog {
  width: 350px;
  max-width: calc(100% - 32px);
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
:deep(textarea:focus-visible) {
  outline: 2px solid #b9a278;
  outline-offset: 2px;
}
</style>
