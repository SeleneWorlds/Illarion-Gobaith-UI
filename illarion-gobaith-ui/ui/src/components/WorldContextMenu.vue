<script setup lang="ts">
import type { WorldAction } from 'illarion-client-core';
export type WorldContextAction = WorldAction;

defineProps<{ actions: WorldContextAction[] }>();
const emit = defineEmits<{ result: [action: string] }>();
</script>

<template>
  <li v-for="action in actions" :key="action.id">
    <button type="button" @click="emit('result', action.id)">{{ action.label }}</button>
  </li>
</template>
