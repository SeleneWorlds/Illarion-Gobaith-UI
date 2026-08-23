<script setup lang="ts">
import { ref } from 'vue';

const MIN_COUNTER = 1;
const MAX_COUNTER = 250;
const counter = ref(MAX_COUNTER);
const counterText = ref(String(counter.value));

const setCounter = (value: number) => {
  counter.value = Math.min(MAX_COUNTER, Math.max(MIN_COUNTER, Math.round(value)));
  counterText.value = String(counter.value);
};
const onInput = (event: Event) => {
  const target = event.target as HTMLInputElement;
  counterText.value = target.value.replace(/\D/g, '').slice(0, 3);
};
const commit = () => {
  const value = Number(counterText.value);
  setCounter(Number.isFinite(value) ? value : counter.value);
};
const onKeydown = (event: KeyboardEvent) => {
  event.stopPropagation();
  if (event.key === 'Enter') {
    event.preventDefault();
    commit();
    (event.currentTarget as HTMLInputElement).blur();
  } else if (event.key === 'Escape') {
    event.preventDefault();
    counterText.value = String(counter.value);
    (event.currentTarget as HTMLInputElement).blur();
  } else if (event.key === 'ArrowUp' || event.key === 'ArrowDown') {
    event.preventDefault();
    setCounter(counter.value + (event.key === 'ArrowUp' ? 1 : -1));
  }
};
const onWheel = (event: WheelEvent) => {
  event.preventDefault();
  setCounter(counter.value + (event.deltaY < 0 ? 1 : -1));
};
</script>

<template>
  <input v-model="counterText" class="counter__value" type="text" inputmode="numeric" maxlength="3"
         aria-label="Item counter" title="Number of items to move (1–250)" data-selene-interactive
         @input="onInput" @blur="commit" @keydown="onKeydown" @keyup.stop @wheel="onWheel">
</template>

<style scoped>
.counter__value {
  position: absolute;
  right: 8px;
  bottom: 60px;
  left: 8px;
  width: 55px;
  height: 24px;
  padding: 0;
  border: 0;
  outline: 0;
  background: transparent;
  color: #B2CCFF;
  font: inherit;
  font-size: 17px;
  text-align: center;
  text-shadow: inherit;
  pointer-events: auto;
}
</style>
