<script setup lang="ts">
defineProps<{ skillsOpen: boolean; expanded?: boolean }>();
const emit = defineEmits<{ result: [action: 'fold' | 'unfold' | 'skills'] }>();
</script>

<template>
  <li v-if="!skillsOpen">
    <button type="button" @click="emit('result', expanded ? 'fold' : 'unfold')">
      {{ expanded ? 'Fold up' : 'Unfold' }}
    </button>
  </li>
  <li v-if="!skillsOpen"><button type="button" @click="emit('result', 'skills')">Skills</button></li>
  <li v-else><button type="button" @click="emit('result', 'fold')">Fold up</button></li>
</template>
