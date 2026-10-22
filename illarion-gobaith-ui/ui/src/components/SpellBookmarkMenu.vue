<script setup lang="ts">
defineProps<{ canWrite: boolean; canRecall: boolean; canClear: boolean }>();
const emit = defineEmits<{ result: [value: 'write' | 'recall' | 'clear'] }>();
</script>

<template>
  <li v-if="canWrite"><button type="button" @click="emit('result', 'write')">Write down here</button></li>
  <li v-if="canRecall"><button type="button" @click="emit('result', 'recall')">Recall</button></li>
  <li v-if="canClear"><button type="button" @click="emit('result', 'clear')">Clear</button></li>
</template>
