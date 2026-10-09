<script setup lang="ts">
import { onActivated, onBeforeUnmount, onMounted, ref, useTemplateRef } from 'vue';
import { z } from 'zod';
import { usePayload } from '../composables/usePayload';
import { useSelene } from '../selene';
import { useI18n } from '../composables/useI18n';

const { t } = useI18n();
const selene = useSelene();
const emit = defineEmits<{ close: [] }>();
const pending = ref(false);
const error = ref(false);
let timeout: ReturnType<typeof setTimeout> | undefined;
onBeforeUnmount(() => clearTimeout(timeout));
usePayload('illarion:report_bug_result', z.object({ success: z.boolean() }), ({ success }) => {
  clearTimeout(timeout);
  pending.value = false;
  error.value = !success;
  if (success) {
    message.value = '';
    emit('close');
  }
});
const message = ref('');
const input = useTemplateRef<HTMLTextAreaElement>('input');
const focus = () => input.value?.focus();
onMounted(focus);
onActivated(focus);
const submit = () => {
  const text = message.value.trim();
  if (!text || pending.value) {
    return;
  }
  pending.value = true;
  error.value = false;
  timeout = setTimeout(() => {
    pending.value = false;
    error.value = true;
  }, 15000);
  selene.network.sendToServer('illarion:report_bug', { message: text });
};
</script>

<template>
  <form @submit.prevent="submit">
    <textarea
      ref="input"
      v-model="message"
      rows="5"
      maxlength="4000"
      :disabled="pending"
      :aria-label="t('bug.description', 'Describe the bug and how to reproduce it.')"
      :placeholder="t('bug.description', 'Describe the bug and how to reproduce it.')"
      autocomplete="off"
    />
    <p v-if="error" role="alert">{{ t('bug.error', 'Unable to send your report. Please try again.') }}</p>
    <div class="form-actions">
      <button class="submit-button" type="submit" :disabled="pending || !message.trim()">
        {{ t('request.submit', 'Submit') }}
      </button>
    </div>
  </form>
</template>

<style scoped>
form {
  display: grid;
  gap: 10px;
}
label {
  color: #c7bdab;
}
textarea {
  min-width: 0;
  width: 100%;
  padding: 10px;
  border: 1px solid rgb(185 162 120 / 40%);
  border-radius: 5px;
  background: rgb(0 0 0 / 25%);
  color: #eee5d5;
  font: inherit;
  resize: vertical;
  min-height: 78px;
  max-height: 180px;
}
textarea::placeholder {
  color: #a49b8b;
}
.form-actions {
  display: flex;
  justify-content: flex-end;
  margin-top: 4px;
}
.submit-button {
  border-color: rgb(185 162 120 / 60%);
  background: rgb(185 162 120 / 25%);
  color: #fff4df;
}
.submit-button:hover:not(:disabled) {
  background: rgb(185 162 120 / 35%);
}
</style>
