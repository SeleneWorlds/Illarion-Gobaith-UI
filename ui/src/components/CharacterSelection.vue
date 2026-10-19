<script setup lang="ts">
import { Plus } from '@lucide/vue';
import MoonlightButton from 'moonlight-ui/MoonlightButton.vue';
import { computed, nextTick, ref } from 'vue';
import { z } from 'zod';
import { onConnected } from '../composables/onConnected';
import GameModal from './GameModal.vue';
import SeleneVisual from './SeleneVisual.vue';
import CharacterActionsMenu from './CharacterActionsMenu.vue';
import { usePayload } from '../composables/usePayload';
import { useSelene } from '../selene';

const characterSchema = z.object({
  id: z.number().int(),
  name: z.string().min(1),
  visual: z.string().optional(),
  subtitle: z.string().optional(),
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
const playableCharacters = computed(() => characters.value?.filter((character) => character.id !== 0) ?? []);
const headlessCharacter = computed(() => characters.value?.find((character) => character.id === 0));
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
  <GameModal v-show="deletingCharacter === null" title="Select a character" :dismissible="false">
    <div v-if="characters === null" class="moonlight-loading" role="status" aria-label="Loading characters">
      <span class="moonlight-spinner" aria-hidden="true" />
    </div>
    <div v-else class="panel">
      <p v-if="playableCharacters.length === 0">You do not have any characters yet.</p>
      <div v-else class="characters">
        <div v-for="character in playableCharacters" :key="character.id" class="character-row">
          <MoonlightButton
            type="button"
            class="select-character"
            :disabled="selectingId !== null || deletingCharacter !== null"
            @click="selectCharacter(character)"
          >
            <span class="character-visual" aria-hidden="true">
              <SeleneVisual
                :identifier="character.visual"
                animation="stationary/south"
                :seed="String(character.id)"
                without-offset
              />
            </span>
            <span class="character-description">
              <span class="character-name">{{ character.name }}</span>
              <small v-if="character.subtitle" class="character-subtitle">{{ character.subtitle }}</small>
            </span>
          </MoonlightButton>
          <CharacterActionsMenu
            class="character-menu"
            :name="character.name"
            :disabled="selectingId !== null || deletingCharacter !== null"
            @delete="openDelete(character)"
          />
        </div>
      </div>
      <MoonlightButton
        type="button"
        class="create"
        variant="primary"
        :disabled="selectingId !== null || deletingCharacter !== null"
        @click="emit('create')"
      >
        <Plus :size="16" aria-hidden="true" />
        Create Character
      </MoonlightButton>
    </div>
    <template v-if="headlessCharacter" #footer>
      <MoonlightButton
        class="headless-login"
        variant="ghost"
        size="small"
        :disabled="selectingId !== null || deletingCharacter !== null"
        @click="selectCharacter(headlessCharacter)"
        >Headless Login</MoonlightButton
      >
    </template>
  </GameModal>
  <GameModal v-if="deletingCharacter" title="Delete character" :dismissible="!deleting" @close="closeDelete">
    <form class="panel" @submit.prevent="deleteCharacter">
      <p>
        Do you want to delete <strong>{{ deletingCharacter.name }}</strong
        >? This action cannot be undone.
      </p>
      <label for="delete-character-name">Type the character's exact name to confirm:</label>
      <input
        class="moonlight-input"
        id="delete-character-name"
        ref="confirmationInput"
        v-model="confirmationName"
        autocomplete="off"
        :disabled="deleting"
      />
      <p v-if="deletionError" role="alert">{{ deletionError }}</p>
      <div class="deletion-actions">
        <MoonlightButton type="button" :disabled="deleting" @click="closeDelete">Cancel</MoonlightButton>
        <MoonlightButton
          type="submit"
          variant="danger"
          :disabled="deleting || confirmationName !== deletingCharacter.name"
        >
          {{ deleting ? 'Deleting…' : 'Delete character' }}
        </MoonlightButton>
      </div>
    </form>
  </GameModal>
</template>

<style scoped>
.panel {
  display: flex;
  flex-direction: column;
}

.characters {
  display: grid;
  gap: 8px;
}

.character-row {
  position: relative;
  display: flex;
}
.character-menu {
  position: absolute;
  top: 0;
  right: 10px;
  bottom: 0;
}
.select-character {
  flex: 1;
  padding-right: 48px;
  min-width: 0;
  justify-content: flex-start;
  gap: 12px;
  text-align: left;
}
.character-visual {
  position: relative;
  flex: 0 0 40px;
  height: 48px;
}
.character-description {
  display: grid;
  min-width: 0;
  gap: 3px;
}
.character-subtitle {
  color: var(--moonlight-text-muted);
  font-size: 11px;
}
.character-name {
  min-width: 0;
  overflow-wrap: anywhere;
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
.headless-login {
  margin-inline: auto;
  font-size: 12px;
}
</style>
