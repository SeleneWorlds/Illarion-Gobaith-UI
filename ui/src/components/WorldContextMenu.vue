<script setup lang="ts">
export interface WorldContextAction {
  id: string;
  label: string;
}

defineProps<{ actions: WorldContextAction[] }>();
const emit = defineEmits<{ result: [action: string] }>();
</script>

<template>
  <li v-for="action in actions" :key="action.id">
    <button type="button" @click="emit('result', action.id)">{{ action.label }}</button>
  </li>
</template>
