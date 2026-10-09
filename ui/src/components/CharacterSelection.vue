<script setup lang="ts">
import { ref } from 'vue';
import { z } from 'zod';
import { onConnected } from '../composables/onConnected';
import GameModal from './GameModal.vue';
import { usePayload } from '../composables/usePayload';
import { useSelene } from '../selene';

const characterSchema = z.object({
  id: z.number().int(),
  name: z.string().min(1),
});
// TODO not clean, but quick fix for empty arrays arriving as empty objects from Lua
const characterListSchema = z.preprocess(
  (value) =>
    value !== null && typeof value === 'object' && !Array.isArray(value) && Object.keys(value).length === 0
      ? []
      : value,
  z.array(characterSchema),
);
const charactersPayloadSchema = z.object({
  characters: characterListSchema,
});
const characterSelectedPayloadSchema = z.object({
  id: z.number().int(),
});

type CharacterSummary = z.infer<typeof characterSchema>;

const emit = defineEmits<{
  selected: [characterId: number];
  create: [];
}>();

const selene = useSelene();
const characters = ref<CharacterSummary[] | null>(null);
const selectingId = ref<number | null>(null);

usePayload('illarion:characters', charactersPayloadSchema, (payload) => {
  characters.value = payload.characters;
  selectingId.value = null;
});

usePayload('illarion:character_selected', characterSelectedPayloadSchema, (payload) => {
  if (payload.id === selectingId.value) {
    emit('selected', payload.id);
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
  <GameModal title="Character selection" :dismissible="false">
    <div v-if="characters === null" class="loading" role="status" aria-label="Loading characters">
      <span class="spinner" aria-hidden="true" />
    </div>
    <div v-else class="panel">
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
  </GameModal>
</template>

<style scoped>
.panel {
  display: flex;
  flex-direction: column;
}

.loading {
  display: grid;
  place-items: center;
  padding: 24px;
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
  gap: 8px;
}

.create {
  margin-top: 14px;
}
</style>
