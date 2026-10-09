<script setup lang="ts">
import { onActivated, onMounted, ref, useTemplateRef } from 'vue';
import { useSelene } from '../selene';

const selene = useSelene();
const emit = defineEmits<{ close: [] }>();
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
  selene.network.sendToServer('illarion:chat', { mode: 'normal', message: `!gm ${text}` });
  message.value = '';
  emit('close');
};
</script>

<template>
  <form @submit.prevent="submit">
    <textarea
      ref="input"
      v-model="message"
      rows="3"
      aria-label="What do you need help with?"
      placeholder="What do you need help with?"
      autocomplete="off"
    />
    <div class="form-actions">
      <button class="submit-button" type="submit" :disabled="!message.trim()">Submit</button>
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
