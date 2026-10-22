<script setup lang="ts">
defineProps<{ presets: number[] }>();
const emit = defineEmits<{ result: [value: number] }>();
</script>
<template>
  <li v-for="preset in presets" :key="preset">
    <button type="button" @click="emit('result', preset)">{{ preset }}</button>
  </li>
</template>
