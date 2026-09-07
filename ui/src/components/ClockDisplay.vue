<script setup lang="ts">
import { computed, onUnmounted, ref } from 'vue';

const now = ref(new Date());
const formattedClock = computed(() => {
  return `${String(now.value.getHours()).padStart(2, '0')}:${String(now.value.getMinutes()).padStart(2, '0')}`;
});
const timer = window.setInterval(() => {
  now.value = new Date();
}, 1000);
onUnmounted(() => window.clearInterval(timer));
</script>

<template>
  <time class="clock">{{ formattedClock }}</time>
</template>

<style scoped>
.clock {
  position: absolute;
  right: 8px;
  bottom: 3px;
  left: 8px;
  color: #b2ccff;
  font-size: 13px;
}
</style>
