<script setup lang="ts">
defineProps<{ canOpenWorldMap: boolean; canZoomIn: boolean; canZoomOut: boolean }>();
const emit = defineEmits<{ result: [action: 'openWorldMap' | number] }>();
</script>
<template>
  <li v-if="canOpenWorldMap"><button type="button" @click="emit('result', 'openWorldMap')">Open world map</button></li>
  <li><button type="button" :disabled="!canZoomIn" @click="emit('result', 0.3)">Zoom in</button></li>
  <li><button type="button" :disabled="!canZoomOut" @click="emit('result', -0.3)">Zoom out</button></li>
</template>
