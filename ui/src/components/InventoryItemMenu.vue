<script setup lang="ts">
defineProps<{ canOpen: boolean }>();
const emit = defineEmits<{ result: [action: 'open' | 'lookAt' | 'use' | 'useWith' | 'drop'] }>();
</script>
<template>
  <li><button type="button" :disabled="!canOpen" @click="emit('result', 'open')">Open</button></li>
  <li><button type="button" @click="emit('result', 'lookAt')">Look at</button></li>
  <li><button type="button" @click="emit('result', 'use')">Use</button></li>
  <li><button type="button" @click="emit('result', 'useWith')">Use with</button></li>
  <li><button type="button" @click="emit('result', 'drop')">Drop</button></li>
</template>
