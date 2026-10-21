<script setup lang="ts">
import MoonlightButton from 'moonlight-ui/MoonlightButton.vue';
import { onActivated, onMounted, ref, useTemplateRef } from 'vue';
import { useAdminRequestStore } from '../stores/adminRequest';
import { useSelene } from '../selene';
import { useI18n } from '../composables/useI18n';

const { t } = useI18n();
const selene = useSelene();
const emit = defineEmits<{ close: [] }>();
const adminRequest = useAdminRequestStore();
const message = ref('');
const input = useTemplateRef<HTMLTextAreaElement>('input');
const focus = () => input.value?.focus();
onMounted(focus);
onActivated(focus);
const submit = () => {
  const text = message.value.trim();
  if (!text) {
    return;
  }
  const target = adminRequest.target.value;
  const suffix = target ? ` (Report concerning ${target.name} (${target.characterId}))` : '';
  selene.network.sendToServer('illarion:chat', { mode: 'normal', message: `!gm ${text}${suffix}` });
  adminRequest.close();
  message.value = '';
  emit('close');
};
</script>

<template>
  <form @submit.prevent="submit">
    <textarea
      class="moonlight-input"
      ref="input"
      v-model="message"
      rows="3"
      :placeholder="t('request.help', 'What do you need help with?')"
      autocomplete="off"
    />
    <div class="form-actions">
      <MoonlightButton variant="primary" type="submit" :disabled="!message.trim()">
        {{ t('request.submit', 'Submit') }}
      </MoonlightButton>
    </div>
  </form>
</template>

<style scoped>
form {
  display: grid;
  gap: 10px;
}
textarea {
  resize: vertical;
  min-height: 78px;
  max-height: 180px;
}
.form-actions {
  display: flex;
  justify-content: flex-end;
  margin-top: 4px;
}
</style>
