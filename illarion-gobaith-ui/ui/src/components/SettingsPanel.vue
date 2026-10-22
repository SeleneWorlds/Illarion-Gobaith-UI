<script setup lang="ts">
import { computed, onActivated, onMounted, ref, useTemplateRef } from 'vue';
import { useSelene } from '../selene';
import { useI18n } from '../composables/useI18n';

const { preferences } = useSelene();
const { locale, t } = useI18n();
const language = computed(() => locale.value.replace('_', '-').split('-')[0]);
const error = ref('');
const select = useTemplateRef<HTMLSelectElement>('select');
const focus = () => select.value?.focus();
onMounted(focus);
onActivated(focus);
const changeLanguage = (event: Event) => {
  const value = (event.target as HTMLSelectElement).value;
  if (value !== 'en' && value !== 'de') {
    return;
  }
  error.value = '';
  try {
    preferences.setLocale(value);
  } catch {
    error.value = 'settings.languageError';
  }
};
</script>

<template>
  <div class="settings-panel">
    <label for="client-locale">{{ t('settings.language', 'Language') }}</label>
    <select class="moonlight-input" id="client-locale" ref="select" :value="language" @change="changeLanguage">
      <option value="en">{{ t('settings.english', 'English') }}</option>
      <option value="de">{{ t('settings.german', 'German') }}</option>
    </select>
    <p v-if="error" class="error" role="alert">{{ t(error, 'Unable to change client language.') }}</p>
  </div>
</template>

<style scoped>
.settings-panel {
  display: grid;
  gap: 10px;
}
.error {
  margin: 0;
  color: var(--moonlight-danger);
}
</style>
