<script setup lang="ts">
import { CircleMinus, CirclePlus } from '@lucide/vue';
import MoonlightButton from 'moonlight-ui/MoonlightButton.vue';
import { computed, onScopeDispose, reactive, ref, watch } from 'vue';
import { z } from 'zod';
import { usePayload } from '../composables/usePayload';
import GameModal from './GameModal.vue';
import SeleneVisual from './SeleneVisual.vue';
import { useI18n } from '../composables/useI18n';
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
      attributes: z
        .object({
          agility: z.number().int(),
          constitution: z.number().int(),
          dexterity: z.number().int(),
          essence: z.number().int(),
          intelligence: z.number().int(),
          perception: z.number().int(),
          strength: z.number().int(),
          willpower: z.number().int(),
        })
        .partial()
        .optional(),
      skills: z
        .preprocess(
          (value) =>
            value && typeof value === 'object' && !Array.isArray(value) && Object.keys(value).length === 0 ? [] : value,
          z.array(z.object({ id: z.number().int(), name: z.string(), value: z.number() })),
        )
        .optional(),
      items: z.array(
        z.object({
          id: z.number().int(),
          name: z.string(),
          count: z.number().int().positive(),
          visual: z.string().optional(),
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
const { get } = useI18n();
const skillName = (name: string) =>
  get(`skills.${name}`) ?? name.replace(/([a-z0-9])([A-Z])/g, '$1 $2').replace(/^./, (first) => first.toUpperCase());
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

const attributesEdited = ref(false);

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

const attributeAllocation = (name: AttributeName): number => {
  const range = selectedRace.value?.attributes[name];
  const value = Number(form.attributes[name]);
  if (!range || !Number.isFinite(value)) {
    return 0;
  }
  if (range.max === range.min) {
    return 100;
  }
  return Math.max(0, Math.min(100, (value / range.max) * 100));
};

const resetForRace = () => {
  const race = selectedRace.value;
  if (!race) {
    return;
  }
  form.age = race.attributes.age.min;
  form.height = Math.round((race.attributes.height.min + race.attributes.height.max) / 2);
  form.weight = Math.round((race.attributes.weight.min + race.attributes.weight.max) / 2000) * 1000;
  applySuggestedAttributes();
};

const applySuggestedAttributes = () => {
  const race = selectedRace.value;
  if (!race) {
    return;
  }
  attributesEdited.value = false;
  const suggestions = selectedStartPack.value?.attributes;
  let remaining = race.attributes.total;
  for (const name of attributeNames) {
    const range = race.attributes[name];
    form.attributes[name] = Math.max(range.min, Math.min(range.max, suggestions?.[name] ?? range.min));
    remaining -= form.attributes[name];
  }
  // Adjust the least important attributes first to preserve the profession's strengths.
  const priority = [...attributeNames].sort((a, b) => (suggestions?.[a] ?? 0) - (suggestions?.[b] ?? 0));
  for (const name of priority) {
    if (remaining >= 0) {
      break;
    }
    const reduction = Math.min(form.attributes[name] - race.attributes[name].min, -remaining);
    form.attributes[name] -= reduction;
    remaining += reduction;
  }
  for (const name of [...priority].reverse()) {
    if (remaining <= 0) {
      break;
    }
    const addition = Math.min(race.attributes[name].max - form.attributes[name], remaining);
    form.attributes[name] += addition;
    remaining -= addition;
  }
};

watch(() => form.race, resetForRace);
watch(
  () => form.startPack,
  () => {
    if (!attributesEdited.value) {
      applySuggestedAttributes();
    }
  },
);

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
  <GameModal
    title="Create Character"
    show-back
    back-label="Back to character selection"
    :dismissible="false"
    wide
    @back="emit('cancel')"
  >
    <div v-if="!options" class="loading" role="status">
      {{ error || 'Loading character options…' }}
    </div>
    <form v-else @submit.prevent="submit">
      <div class="columns">
        <fieldset class="identity-panel">
          <legend>Identity</legend>
          <label
            >Name
            <input class="moonlight-input" v-model="form.name" required minlength="2" maxlength="50" autocomplete="off"
          /></label>
          <label
            >Race
            <select class="moonlight-input" v-model.number="form.race">
              <option v-for="race in options.races" :key="race.id" :value="race.id">{{ race.name }}</option>
            </select>
          </label>
          <label
            >Sex
            <select class="moonlight-input" v-model="form.sex">
              <option value="male">Male</option>
              <option value="female">Female</option>
            </select>
          </label>
          <label v-if="selectedRace"
            >Age
            <input
              class="moonlight-input"
              v-model.number="form.age"
              type="number"
              :min="selectedRace.attributes.age.min"
              :max="selectedRace.attributes.age.max"
          /></label>
          <label v-if="selectedRace"
            >Height (cm)
            <input
              class="moonlight-input"
              v-model.number="heightCm"
              type="number"
              :min="Math.round(selectedRace.attributes.height.min * 2.54)"
              :max="Math.round(selectedRace.attributes.height.max * 2.54)"
          /></label>
          <label v-if="selectedRace"
            >Weight (kg)
            <input
              class="moonlight-input"
              v-model.number="weightKg"
              type="number"
              step="1"
              :min="selectedRace.attributes.weight.min / 1000"
              :max="selectedRace.attributes.weight.max / 1000"
          /></label>
        </fieldset>

        <fieldset class="starter-pack-selector">
          <legend>Starter Pack</legend>
          <select class="moonlight-input" v-model.number="form.startPack" aria-label="Starter Pack">
            <option v-for="pack in options.startPacks" :key="pack.id" :value="pack.id">{{ pack.name }}</option>
          </select>
        </fieldset>

        <div class="attribute-panels">
          <fieldset v-if="selectedRace" class="attributes-panel">
            <legend class="attributes-heading">
              <span>Attributes</span>
              <span class="points-remaining" :class="{ invalid: pointsRemaining !== 0 }">
                {{ pointsRemaining }} points remaining
              </span>
            </legend>
            <div v-for="name in attributeNames" :key="name" class="attribute">
              <label :for="`attribute-${name}`">{{ name }}</label>
              <span class="attribute-bar" aria-hidden="true">
                <span class="attribute-fill" :style="{ width: `${attributeAllocation(name)}%` }" />
              </span>
              <input
                :id="`attribute-${name}`"
                class="attribute-value"
                v-model.number="form.attributes[name]"
                @input="attributesEdited = true"
                type="number"
                :min="selectedRace.attributes[name].min"
                :max="selectedRace.attributes[name].max"
              />
              <MoonlightButton
                variant="ghost"
                size="icon"
                :aria-label="`Decrease ${name}`"
                :disabled="submitting || form.attributes[name] <= selectedRace.attributes[name].min"
                @click="
                  form.attributes[name]--;
                  attributesEdited = true;
                "
                ><CircleMinus :size="16" aria-hidden="true"
              /></MoonlightButton>
              <MoonlightButton
                variant="ghost"
                size="icon"
                :aria-label="`Increase ${name}`"
                :disabled="
                  submitting || pointsRemaining <= 0 || form.attributes[name] >= selectedRace.attributes[name].max
                "
                @click="
                  form.attributes[name]++;
                  attributesEdited = true;
                "
                ><CirclePlus :size="16" aria-hidden="true"
              /></MoonlightButton>
            </div>
            <MoonlightButton
              v-if="attributesEdited && selectedStartPack"
              class="recommended-attributes"
              size="small"
              :disabled="submitting"
              @click="applySuggestedAttributes"
              >Use recommended attributes for {{ selectedStartPack.name }}</MoonlightButton
            >
          </fieldset>
          <fieldset v-if="selectedStartPack">
            <legend>Skills</legend>
            <ul v-if="selectedStartPack.skills?.length" class="starter-skills">
              <li v-for="skill in selectedStartPack.skills" :key="skill.id">
                <span>{{ skillName(skill.name) }}</span>
                <strong>{{ skill.value }}</strong>
              </li>
            </ul>
            <p v-else class="ml-muted">No starter skills.</p>
          </fieldset>
        </div>

        <fieldset>
          <legend>Equipment</legend>

          <div v-if="selectedStartPack" class="starter-details">
            <ul class="starter-items" aria-label="Starter equipment">
              <li
                v-for="(item, index) in selectedStartPack.items"
                :key="`${item.id}-${index}`"
                class="starter-item"
                :title="item.name"
              >
                <span class="starter-visual" aria-hidden="true">
                  <SeleneVisual :identifier="item.visual" :seed="String(item.id)" without-offset />
                </span>
                <span class="starter-item-name">{{ item.name }}</span>
                <span v-if="item.count > 1" class="item-count">× {{ item.count }}</span>
              </li>
            </ul>
          </div>
        </fieldset>
      </div>

      <p v-if="error" class="error" role="alert">{{ error }}</p>
      <MoonlightButton class="create" variant="primary" type="submit" :disabled="submitting || pointsRemaining !== 0">
        {{ submitting ? 'Creating…' : 'Create Character' }}
      </MoonlightButton>
    </form>
  </GameModal>
</template>

<style scoped>
.columns {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 18px;
  align-items: start;
}
fieldset {
  min-width: 0;
  padding: 12px;
  border: 1px solid var(--moonlight-border);
  border-radius: 8px;
}
legend {
  padding: 0 6px;
  font-size: 13px;
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
input,
select {
  width: 132px;
}
.identity-panel {
  grid-column: 1 / -1;
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  column-gap: 18px;
}
.identity-panel input,
.identity-panel select {
  width: 100%;
}
.identity-panel label {
  grid-template-columns: minmax(0, 1fr);
}
.starter-pack-selector {
  grid-column: 1 / -1;
}
.starter-pack-selector select {
  width: 100%;
}
.attribute-panels {
  display: grid;
  min-width: 0;
  gap: 18px;
}
.attributes-panel {
  min-width: 0;
}
.recommended-attributes {
  width: 100%;
  margin-top: 8px;
  white-space: normal;
}
.attributes-heading {
  display: flex;
  align-items: center;
  gap: 8px;
  width: 100%;
}
.attributes-heading::after {
  content: '';
  flex: 1;
  height: 1px;
  background: var(--moonlight-border);
}
.attributes-heading .points-remaining {
  order: 1;
}
.points-remaining {
  padding: 2px 8px;
  border-radius: 12px;
  background: var(--moonlight-surface-raised);
  color: var(--moonlight-text-muted);
  font-size: 12px;
  font-weight: 400;
}
.attribute {
  display: grid;
  grid-template-columns: 90px minmax(0, 1fr) 32px 28px 28px;
  align-items: center;
  gap: 8px;
  margin-block: 10px;
}
.attribute label {
  display: block;
  margin: 0;
}
.attribute-bar {
  height: 8px;
  overflow: hidden;
  border-radius: 4px;
  background: var(--moonlight-surface-raised);
}
.attribute-fill {
  display: block;
  height: 100%;
  border-radius: inherit;
  background: var(--moonlight-accent);
}
.attribute-value {
  width: 38px;
  padding: 0;
  border: 0;
  background: transparent;
  color: var(--moonlight-text);
  font: inherit;
  text-align: center;
  appearance: textfield;
}
.attribute-value::-webkit-inner-spin-button,
.attribute-value::-webkit-outer-spin-button {
  appearance: none;
  margin: 0;
}
.attribute-value:focus-visible {
  outline: 2px solid var(--moonlight-accent);
  border-radius: 3px;
}
@media (max-width: 540px) {
  .attribute {
    grid-template-columns: 90px minmax(0, 1fr) 32px 28px 28px;
    gap: 4px;
  }
}
.starter-details h3 {
  margin: 16px 0 8px;
  color: var(--moonlight-text-muted);
  font-size: 12px;
  font-weight: 600;
}
.starter-items,
.starter-skills {
  margin: 0;
  padding: 0;
  list-style: none;
}
.starter-items {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(90px, 1fr));
  gap: 8px;
}
.starter-item {
  position: relative;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 4px;
  padding: 8px;
  border: 1px solid var(--moonlight-border);
  border-radius: 6px;
  background: var(--moonlight-background);
}
.starter-visual {
  position: relative;
  width: 64px;
  height: 48px;
}
.starter-item-name {
  font-size: 11px;
  text-align: center;
  overflow-wrap: anywhere;
}
.item-count {
  position: absolute;
  top: 4px;
  right: 5px;
  padding: 1px 4px;
  border-radius: 4px;
  background: var(--moonlight-surface-raised);
  font-size: 10px;
}
.starter-skills li {
  display: flex;
  justify-content: space-between;
  gap: 12px;
  padding: 6px 0;
  border-bottom: 1px solid var(--moonlight-border);
}
.starter-skills strong {
  color: var(--moonlight-accent);
  font-variant-numeric: tabular-nums;
}
.create {
  display: block;
  margin: 16px auto 0;
}
.invalid,
.error {
  color: var(--moonlight-danger);
}
.error {
  margin: 12px 0 0;
  text-align: center;
}
.loading {
  color: var(--moonlight-text-muted);
}
@media (max-width: 860px) {
  .columns {
    grid-template-columns: 1fr;
  }
}
@media (max-width: 540px) {
  .identity-panel {
    grid-template-columns: 1fr;
  }
}
</style>
