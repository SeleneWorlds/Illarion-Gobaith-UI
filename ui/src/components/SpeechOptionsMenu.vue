<script setup lang="ts">
import { speechModes, type SpeechModeId } from '../chatModes';
defineProps<{ selectedMode: SpeechModeId; languages: readonly string[] }>();
const emit = defineEmits<{ result: [selection: { mode: SpeechModeId } | { language: string }] }>();
</script>
<template>
  <li v-for="item in speechModes" v-show="item.id !== selectedMode" :key="item.id">
    <button type="button" @click="emit('result', { mode: item.id })">
      {{ item.name === 'Normal' ? 'Speak' : item.name }}
    </button>
  </li>
  <li class="separator" role="separator" />
  <li v-for="language in languages" :key="language">
    <button type="button" @click="emit('result', { language })">{{ language }}</button>
  </li>
</template>
