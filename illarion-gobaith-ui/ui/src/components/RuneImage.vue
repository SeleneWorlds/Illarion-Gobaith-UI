<script setup lang="ts">
import { computed } from 'vue';
import { useUiAssetSrc } from '../composables/useClientAsset';

const props = defineProps<{ type: string; rune: number }>();
const source = useUiAssetSrc(computed(() => `rune_${props.type}${props.rune}.png`));
</script>

<template>
  <img :src="source" alt="" />
</template>
