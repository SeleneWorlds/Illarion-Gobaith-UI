<script setup lang="ts">
import { onUnmounted, ref } from 'vue';

const formatClock = () => {
  const now = new Date();
  return `${String(now.getHours()).padStart(2, '0')}:${String(now.getMinutes()).padStart(2, '0')}`;
};
const clock = ref(formatClock());
const timer = window.setInterval(() => {
  clock.value = formatClock();
}, 1000);
onUnmounted(() => window.clearInterval(timer));
</script>

<template>
  <time class="counter__time">{{ clock }}</time>
</template>

<style scoped>
.counter__time {
  position: absolute;
  right: 8px;
  bottom: 3px;
  left: 8px;
  color: #b2ccff;
  font-size: 13px;
}
</style>
