<script setup lang="ts">
import { nextTick, ref } from 'vue';
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
const launchCoordinateSchema = z
  .string()
  .regex(/^-?\d+$/)
  .transform(Number)
  .pipe(z.number().int().min(-2147483647).max(2147483647));
const launchParameters = selene.launch?.getParameters() ?? {};
const launchCharacter = launchParameters.character;
const headlessCoordinates = z
  .object({
    x: launchCoordinateSchema,
    y: launchCoordinateSchema,
    z: launchCoordinateSchema,
  })
  .safeParse(launchParameters);
const hasHeadlessCoordinates = ['x', 'y', 'z'].some((key) => launchParameters[key] !== undefined);
const headlessFollow = z
  .string()
  .regex(/^\d+$/)
  .transform(Number)
  .pipe(z.number().int().min(1).max(2147483647))
  .safeParse(launchParameters.follow);
const hasHeadlessFollow = launchParameters.follow !== undefined;
let deeplinkRequested = false;
const characters = ref<CharacterSummary[] | null>(null);
const selectingId = ref<number | null>(null);
const deletingCharacter = ref<CharacterSummary | null>(null);
const confirmationName = ref('');
const deleting = ref(false);
const deletionError = ref('');
const confirmationInput = ref<HTMLInputElement | null>(null);

const openDelete = async (character: CharacterSummary) => {
  deletingCharacter.value = character;
  confirmationName.value = '';
  deletionError.value = '';
  await nextTick();
  confirmationInput.value?.focus();
};
const closeDelete = () => {
  if (!deleting.value) {
    deletingCharacter.value = null;
  }
};
const deleteCharacter = () => {
  const character = deletingCharacter.value;
  if (!character || deleting.value || confirmationName.value !== character.name) {
    return;
  }
  deleting.value = true;
  deletionError.value = '';
  selene.network.sendToServer('illarion:delete_character', { id: character.id, name: confirmationName.value });
};
usePayload(
  'illarion:character_deletion_result',
  z.object({
    id: z.number().int().optional(),
    error: z.string().optional(),
  }),
  (payload) => {
    if (!deleting.value) {
      return;
    }
    deleting.value = false;
    if (payload.error) {
      deletionError.value = payload.error;
    } else if (payload.id === deletingCharacter.value?.id) {
      characters.value = characters.value?.filter((character) => character.id !== payload.id) ?? null;
      deletingCharacter.value = null;
    }
  },
);

usePayload('illarion:characters', charactersPayloadSchema, (payload) => {
  characters.value = payload.characters;
  if (selectingId.value !== null || deletingCharacter.value !== null) {
    return;
  }
  if (!launchCharacter || deeplinkRequested) {
    return;
  }
  const headless = launchCharacter === 'headless';
  const selected = payload.characters.find((character) =>
    headless ? character.id === 0 : character.id !== 0 && character.name === launchCharacter,
  );
  if (
    !selected ||
    (headless &&
      ((hasHeadlessCoordinates && !headlessCoordinates.success) || (hasHeadlessFollow && !headlessFollow.success)))
  ) {
    return;
  }

  deeplinkRequested = true;
  selectingId.value = selected.id;
  selene.network.sendToServer('illarion:select_character', {
    id: selected.id,
    ...(headless && (headlessCoordinates.success || headlessFollow.success)
      ? {
          headless: {
            ...(headlessCoordinates.success ? headlessCoordinates.data : {}),
            ...(headlessFollow.success ? { follow: headlessFollow.data } : {}),
          },
        }
      : {}),
  });
});

usePayload('illarion:character_selected', characterSelectedPayloadSchema, (payload) => {
  if (payload.id === selectingId.value) {
    emit('selected', payload.id);
  }
});

onConnected(() => {
  characters.value = null;
  selectingId.value = null;
  deeplinkRequested = false;
  deletingCharacter.value = null;
  deleting.value = false;
  selene.network.sendToServer('illarion:request_characters');
});

const selectCharacter = (character: CharacterSummary) => {
  if (selectingId.value !== null || deletingCharacter.value !== null) {
    return;
  }
  selectingId.value = character.id;
  selene.network.sendToServer('illarion:select_character', { id: character.id });
};
</script>

<template>
  <GameModal v-show="deletingCharacter === null" title="Character selection" :dismissible="false">
    <div v-if="characters === null" class="loading" role="status" aria-label="Loading characters">
      <span class="spinner" aria-hidden="true" />
    </div>
    <div v-else class="panel">
      <p v-if="characters.length === 0">You do not have any characters yet.</p>
      <div v-else class="characters">
        <div v-for="character in characters" :key="character.id" class="character-row">
          <button
            type="button"
            class="select-character"
            :disabled="selectingId !== null || deletingCharacter !== null"
            @click="selectCharacter(character)"
          >
            {{ character.name }}
          </button>
          <button
            v-if="character.id !== 0"
            type="button"
            class="delete-character danger"
            :aria-label="`Delete ${character.name}`"
            :disabled="selectingId !== null || deletingCharacter !== null"
            @click="openDelete(character)"
          >
            ×
          </button>
        </div>
      </div>
      <button
        type="button"
        class="create"
        :disabled="selectingId !== null || deletingCharacter !== null"
        @click="emit('create')"
      >
        Create Character
      </button>
    </div>
  </GameModal>
  <GameModal v-if="deletingCharacter" title="Delete character" :dismissible="!deleting" @close="closeDelete">
    <form class="panel" @submit.prevent="deleteCharacter">
      <p>
        Do you want to delete <strong>{{ deletingCharacter.name }}</strong
        >? This action cannot be undone.
      </p>
      <label for="delete-character-name">Type the character's exact name to confirm:</label>
      <input
        id="delete-character-name"
        ref="confirmationInput"
        v-model="confirmationName"
        autocomplete="off"
        :disabled="deleting"
      />
      <p v-if="deletionError" role="alert">{{ deletionError }}</p>
      <div class="deletion-actions">
        <button type="button" :disabled="deleting" @click="closeDelete">Cancel</button>
        <button type="submit" class="danger" :disabled="deleting || confirmationName !== deletingCharacter.name">
          {{ deleting ? 'Deleting…' : 'Delete character' }}
        </button>
      </div>
    </form>
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

.character-row {
  display: flex;
  gap: 8px;
}
.select-character {
  flex: 1;
}
.delete-character {
  font-size: 20px;
  line-height: 1;
}
button.danger {
  color: #ff8585;
  border-color: #bd4848;
  background: rgb(160 35 35 / 25%);
}
.deletion-actions {
  display: flex;
  justify-content: flex-end;
  gap: 8px;
  margin-top: 14px;
}
input {
  margin-top: 8px;
}

.create {
  margin-top: 14px;
}
</style>
