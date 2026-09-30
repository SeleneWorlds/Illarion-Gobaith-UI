<script setup lang="ts">
import { ref } from 'vue';
import { z } from 'zod';
import { onConnected } from '../composables/onConnected';
import { useUiAssetSrc } from '../composables/useClientAsset';
import { usePayload } from '../composables/usePayload';
import { useSelene } from '../selene';

const characterSchema = z.object({
  id: z.number().int(),
  name: z.string().min(1),
});
const charactersPayloadSchema = z.object({
  characters: z.array(characterSchema),
});
const characterSelectedPayloadSchema = z.object({
  id: z.number().int(),
});

type CharacterSummary = z.infer<typeof characterSchema>;

const emit = defineEmits<{
  selected: [];
  create: [];
}>();

const selene = useSelene();
const characters = ref<CharacterSummary[] | null>(null);
const selectingId = ref<number | null>(null);
const scrollBackground = useUiAssetSrc('menu_short.png');

usePayload('illarion:characters', charactersPayloadSchema, (payload) => {
  characters.value = payload.characters;
  selectingId.value = null;
});

usePayload('illarion:character_selected', characterSelectedPayloadSchema, (payload) => {
  if (payload.id === selectingId.value) {
    emit('selected');
  }
});

onConnected(() => {
  characters.value = null;
  selectingId.value = null;
  selene.network.sendToServer('illarion:request_characters');
});

const selectCharacter = (character: CharacterSummary) => {
  if (selectingId.value !== null) {
    return;
  }
  selectingId.value = character.id;
  selene.network.sendToServer('illarion:select_character', { id: character.id });
};
</script>

<template>
  <section class="selection" aria-label="Character selection">
    <div v-if="characters === null" class="loading" role="status" aria-label="Loading characters">
      <span class="spinner" aria-hidden="true" />
    </div>
    <div v-else class="panel" :style="scrollBackground ? { backgroundImage: `url(${scrollBackground})` } : undefined">
      <p v-if="characters.length === 0">You do not have any characters yet.</p>
      <div v-else class="characters">
        <button
          v-for="character in characters"
          :key="character.id"
          type="button"
          :disabled="selectingId !== null"
          @click="selectCharacter(character)"
        >
          {{ character.name }}
        </button>
      </div>
      <button type="button" class="create" :disabled="selectingId !== null" @click="emit('create')">
        Create Character
      </button>
    </div>
  </section>
</template>

<style scoped>
.selection {
  position: fixed;
  inset: 0;
  display: grid;
  place-items: center;
  color: #3d2a16;
  background: rgb(8 7 5 / 60%);
  pointer-events: auto;
}

.panel {
  display: flex;
  width: 300px;
  height: 220px;
  padding: 48px 48px 42px;
  flex-direction: column;
  justify-content: center;
  text-align: center;
  background-position: center;
  background-size: 100% 100%;
  filter: drop-shadow(0 8px 16px rgb(0 0 0 / 50%));
}

.loading {
  display: grid;
  place-items: center;
}

.spinner {
  width: 30px;
  height: 30px;
  border: 3px solid rgb(234 217 183 / 25%);
  border-top-color: #ead9b7;
  border-radius: 50%;
  animation: spin 0.8s linear infinite;
}

@keyframes spin {
  to {
    transform: rotate(360deg);
  }
}

@media (prefers-reduced-motion: reduce) {
  .spinner {
    animation-duration: 1.8s;
  }
}

.characters {
  display: grid;
  gap: 6px;
  overflow-y: auto;
}

.create {
  margin-top: 14px;
}

button {
  padding: 7px 14px;
  border: 1px solid #8b6a3e;
  border-radius: 2px;
  color: #3d2a16;
  font: inherit;
  font-size: 14px;
  background: rgb(151 113 62 / 15%);
  cursor: pointer;
}

button:hover:not(:disabled),
button:focus-visible {
  background: rgb(151 113 62 / 35%);
}

button:disabled {
  cursor: wait;
  opacity: 0.65;
}
</style>
