<script setup lang="ts">
import { computed, onScopeDispose, reactive, ref, watch } from 'vue';
import { z } from 'zod';
import { usePayload } from '../composables/usePayload';
import { useUiAssetSrc } from '../composables/useClientAsset';
import { useSelene } from '../selene';

const rangeSchema = z.object({ min: z.number().int(), max: z.number().int() });
const appearanceSchema = z.object({
  id: z.number().int(),
});
const attributesSchema = z.object({
  age: rangeSchema,
  height: rangeSchema,
  weight: rangeSchema,
  agility: rangeSchema,
  constitution: rangeSchema,
  dexterity: rangeSchema,
  essence: rangeSchema,
  intelligence: rangeSchema,
  perception: rangeSchema,
  strength: rangeSchema,
  willpower: rangeSchema,
  total: z.number().int(),
});
const optionsSchema = z.object({
  races: z.array(
    z.object({
      id: z.number().int(),
      name: z.string(),
      attributes: attributesSchema,
      types: z.array(appearanceSchema),
    }),
  ),
  startPacks: z.array(
    z.object({
      id: z.number().int(),
      name: z.string(),
      items: z.array(
        z.object({
          id: z.number().int(),
          name: z.string(),
          count: z.number().int().positive(),
        }),
      ),
    }),
  ),
});
const resultSchema = z.union([z.object({ id: z.number().int() }), z.object({ error: z.string() })]);

type Options = z.infer<typeof optionsSchema>;
type AttributeName =
  'agility' | 'constitution' | 'dexterity' | 'essence' | 'intelligence' | 'perception' | 'strength' | 'willpower';

const attributeNames: AttributeName[] = [
  'agility',
  'constitution',
  'dexterity',
  'essence',
  'intelligence',
  'perception',
  'strength',
  'willpower',
];
const emit = defineEmits<{ cancel: []; created: [] }>();
const selene = useSelene();
const scrollBackground = useUiAssetSrc('menu_short.png');
const options = ref<Options | null>(null);
const submitting = ref(false);
const error = ref('');
const form = reactive({
  name: '',
  race: 0,
  sex: 'male' as 'male' | 'female',
  age: 18,
  height: 60,
  weight: 60000,
  startPack: 1,
  attributes: Object.fromEntries(attributeNames.map((name) => [name, 0])) as Record<AttributeName, number>,
});

const selectedRace = computed(() => options.value?.races.find((race) => race.id === form.race));
const selectedStartPack = computed(() => options.value?.startPacks.find((pack) => pack.id === form.startPack));
const heightCm = computed({
  get: () => Math.round(form.height * 2.54),
  set: (value: number) => {
    form.height = Math.round(value / 2.54);
  },
});
const weightKg = computed({
  get: () => form.weight / 1000,
  set: (value: number) => {
    form.weight = Math.round(value * 1000);
  },
});
const pointsRemaining = computed(() => {
  const total = attributeNames.reduce((sum, name) => sum + form.attributes[name], 0);
  return (selectedRace.value?.attributes.total ?? 0) - total;
});

const resetForRace = () => {
  const race = selectedRace.value;
  if (!race) {
    return;
  }
  form.age = race.attributes.age.min;
  form.height = Math.round((race.attributes.height.min + race.attributes.height.max) / 2);
  form.weight = Math.round((race.attributes.weight.min + race.attributes.weight.max) / 2000) * 1000;
  let remaining = race.attributes.total;
  for (const name of attributeNames) {
    form.attributes[name] = race.attributes[name].min;
    remaining -= form.attributes[name];
  }
  for (const name of attributeNames) {
    const room = race.attributes[name].max - form.attributes[name];
    const addition = Math.min(room, remaining);
    form.attributes[name] += addition;
    remaining -= addition;
  }
};

watch(() => form.race, resetForRace);

const unsubscribeOptions = selene.network.onPayload('illarion:character_creation_options', (payload) => {
  const result = optionsSchema.safeParse(payload);
  if (!result.success) {
    console.error('Invalid character creation options', result.error, payload);
    error.value = 'The server returned invalid character creation options.';
    return;
  }
  options.value = result.data;
  if (result.data.races.length > 0) {
    form.race = result.data.races[0].id;
  }
  if (result.data.startPacks.length > 0) {
    form.startPack = result.data.startPacks[0].id;
  }
  resetForRace();
});
onScopeDispose(unsubscribeOptions);
usePayload('illarion:character_creation_result', resultSchema, (payload) => {
  submitting.value = false;
  if ('error' in payload) {
    error.value = payload.error;
  } else {
    emit('created');
  }
});

selene.network.sendToServer('illarion:request_character_creation');

const submit = () => {
  if (pointsRemaining.value !== 0 || form.name.trim().length < 2) {
    error.value = 'Complete all fields and allocate every attribute point.';
    return;
  }
  error.value = '';
  submitting.value = true;
  selene.network.sendToServer('illarion:create_character', {
    name: form.name,
    race: form.race,
    sex: form.sex,
    age: form.age,
    height: form.height,
    weight: form.weight,
    startPack: form.startPack,
    ...form.attributes,
  });
};
</script>

<template>
  <section class="creation" aria-label="Create character">
    <div v-if="!options" class="loading" role="status">
      {{ error || 'Loading character options…' }}
    </div>
    <form
      v-else
      class="sheet"
      :style="scrollBackground ? { backgroundImage: `url(${scrollBackground})` } : undefined"
      @submit.prevent="submit"
    >
      <header>
        <button type="button" class="text-button" @click="emit('cancel')">← Back</button>
        <h1>Create Character</h1>
      </header>

      <div class="columns">
        <fieldset>
          <legend>Identity</legend>
          <label>Name <input v-model="form.name" required minlength="2" maxlength="50" autocomplete="off" /></label>
          <label
            >Race
            <select v-model.number="form.race">
              <option v-for="race in options.races" :key="race.id" :value="race.id">{{ race.name }}</option>
            </select>
          </label>
          <label
            >Sex
            <select v-model="form.sex">
              <option value="male">Male</option>
              <option value="female">Female</option>
            </select>
          </label>
          <label v-if="selectedRace"
            >Age
            <input
              v-model.number="form.age"
              type="number"
              :min="selectedRace.attributes.age.min"
              :max="selectedRace.attributes.age.max"
          /></label>
          <label v-if="selectedRace"
            >Height (cm)
            <input
              v-model.number="heightCm"
              type="number"
              :min="Math.round(selectedRace.attributes.height.min * 2.54)"
              :max="Math.round(selectedRace.attributes.height.max * 2.54)"
          /></label>
          <label v-if="selectedRace"
            >Weight (kg)
            <input
              v-model.number="weightKg"
              type="number"
              step="1"
              :min="selectedRace.attributes.weight.min / 1000"
              :max="selectedRace.attributes.weight.max / 1000"
          /></label>
        </fieldset>

        <fieldset v-if="selectedRace">
          <legend>
            Attributes <span :class="{ invalid: pointsRemaining !== 0 }">({{ pointsRemaining }} left)</span>
          </legend>
          <label v-for="name in attributeNames" :key="name" class="attribute">
            <span>{{ name }}</span>
            <input
              v-model.number="form.attributes[name]"
              type="number"
              :min="selectedRace.attributes[name].min"
              :max="selectedRace.attributes[name].max"
            />
          </label>
        </fieldset>

        <fieldset>
          <legend>Starter Pack</legend>
          <select v-model.number="form.startPack">
            <option v-for="pack in options.startPacks" :key="pack.id" :value="pack.id">{{ pack.name }}</option>
          </select>
          <ul v-if="selectedStartPack" class="starter-items">
            <li v-for="(item, index) in selectedStartPack.items" :key="`${item.id}-${index}`">
              {{ item.name }}<span v-if="item.count > 1"> × {{ item.count }}</span>
            </li>
          </ul>
        </fieldset>
      </div>

      <p v-if="error" class="error" role="alert">{{ error }}</p>
      <button class="create" type="submit" :disabled="submitting || pointsRemaining !== 0">
        {{ submitting ? 'Creating…' : 'Create Character' }}
      </button>
    </form>
  </section>
</template>

<style scoped>
.creation {
  position: fixed;
  inset: 0;
  display: grid;
  place-items: center;
  padding: 24px;
  color: #3d2a16;
  background: rgb(8 7 5 / 75%);
  pointer-events: auto;
}
.sheet {
  box-sizing: border-box;
  width: min(900px, calc(100vw - 48px));
  max-height: calc(100vh - 48px);
  padding: 50px 88px;
  overflow: auto;
  background-position: center;
  background-size: 100% 100%;
  filter: drop-shadow(0 8px 16px rgb(0 0 0 / 55%));
}
header {
  display: grid;
  grid-template-columns: 1fr auto 1fr;
  align-items: center;
}
h1 {
  margin: 0 0 18px;
  font:
    700 26px Georgia,
    serif;
}
.text-button {
  justify-self: start;
  border: 0;
  background: transparent;
}
.columns {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 18px;
  align-items: start;
}
fieldset {
  min-width: 0;
  padding: 12px;
  border: 1px solid #9b784a;
}
legend {
  padding: 0 6px;
  font-weight: 700;
}
label {
  display: grid;
  grid-template-columns: 1fr auto;
  gap: 8px;
  align-items: center;
  margin: 7px 0;
  text-transform: capitalize;
}
input:not([type='range']),
select {
  box-sizing: border-box;
  width: 132px;
  padding: 4px 6px;
  border: 1px solid #8b6a3e;
  color: #3d2a16;
  background: #ead9b7;
}
.attribute input {
  width: 58px;
}
.starter-items {
  margin: 10px 0 0;
  padding-left: 20px;
}
.starter-items li + li {
  margin-top: 3px;
}
.create,
.text-button {
  padding: 7px 14px;
  color: #3d2a16;
  font: inherit;
  cursor: pointer;
}
.create {
  display: block;
  margin: 16px auto 0;
  border: 1px solid #6f5534;
  background: rgb(151 113 62 / 25%);
}
.create:disabled {
  cursor: not-allowed;
  opacity: 0.55;
}
.invalid,
.error {
  color: #8c211c;
}
.error {
  margin: 12px 0 0;
  text-align: center;
}
.loading {
  color: #ead9b7;
}
@media (max-width: 760px) {
  .columns {
    grid-template-columns: 1fr;
  }
  .sheet {
    padding-inline: 40px;
    background: #dfc99d;
  }
}
</style>
