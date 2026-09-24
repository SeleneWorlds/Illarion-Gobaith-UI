<script setup lang="ts">
import { computed, onMounted, ref, useTemplateRef } from 'vue';
import { useUiAssetSrc } from '../composables/useClientAsset';

const props = defineProps<{ value: number }>();
const emit = defineEmits<{
  confirm: [value: number];
  cancel: [];
}>();
const input = useTemplateRef<HTMLInputElement>('input');
const text = ref(String(props.value));
const number = computed(() => Number(text.value));
const valid = computed(() => /^\d{1,3}$/.test(text.value) && number.value >= 1 && number.value <= 250);
const frame = useUiAssetSrc('menu_short.png');
const storeIcon = useUiAssetSrc('spellbook_store.png');
const closeIcon = useUiAssetSrc('menu_close.png');

const onInput = (event: Event) => {
  text.value = (event.target as HTMLInputElement).value.replace(/\D/g, '').slice(0, 3);
};
const confirm = () => {
  if (valid.value) {
    emit('confirm', number.value);
  }
};
const onKeydown = (event: KeyboardEvent) => {
  event.stopPropagation();
  if (event.key === 'Enter') {
    event.preventDefault();
    confirm();
  } else if (event.key === 'Escape') {
    event.preventDefault();
    emit('cancel');
  }
};

onMounted(() => input.value?.select());
</script>

<template>
  <span class="scrim" data-selene-interactive aria-hidden="true" @click="emit('cancel')" />
  <section
    class="editor"
    data-selene-interactive
    role="dialog"
    aria-modal="true"
    aria-labelledby="counter-editor-title"
    @click.stop
    @keydown.stop
  >
    <img class="frame" :src="frame" alt="" />
    <form @submit.prevent="confirm">
      <label id="counter-editor-title" for="counter-input">Enter new number</label>
      <input
        id="counter-input"
        ref="input"
        v-model="text"
        type="text"
        inputmode="numeric"
        maxlength="3"
        autocomplete="off"
        @input="onInput"
        @keydown="onKeydown"
        @keyup.stop
      />
      <button class="confirm" type="submit" :disabled="!valid" title="Set number" aria-label="Set number">
        <img :src="storeIcon" alt="" />
      </button>
      <button class="cancel" type="button" title="Cancel" aria-label="Cancel" @click="emit('cancel')">
        <img :src="closeIcon" alt="" />
      </button>
    </form>
  </section>
</template>

<style scoped>
.scrim {
  position: fixed;
  z-index: 29;
  inset: 0;
  display: block;
  pointer-events: auto;
}
.editor {
  position: fixed;
  z-index: 30;
  top: 50%;
  left: 50%;
  width: 460px;
  height: 270px;
  color: #3b2917;
  font-family: Georgia, serif;
  text-shadow: none;
  transform: translate(-50%, -50%);
  pointer-events: auto;
}
.frame {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
  pointer-events: none;
  user-select: none;
}
.editor form {
  position: absolute;
  inset: 0;
}
.editor label {
  position: absolute;
  top: 54px;
  right: 60px;
  left: 60px;
  color: #4a321c;
  font-size: 18px;
}
.editor input {
  position: absolute;
  top: 123px;
  right: 60px;
  left: 60px;
  width: 340px;
  padding: 4px 2px;
  border: 0;
  outline: 0;
  background: transparent;
  color: #6c2019;
  font:
    20px Georgia,
    serif;
  caret-color: #6c2019;
  pointer-events: auto;
}
.editor button {
  position: absolute;
  bottom: 24px;
  width: 42px;
  height: 42px;
  padding: 0;
  overflow: hidden;
  border: 0;
  outline: 0;
  background: transparent;
  cursor: pointer;
  pointer-events: auto;
}
.editor button:focus-visible {
  outline: 1px solid #7a3d27;
}
.editor button img {
  position: absolute;
  pointer-events: none;
  user-select: none;
}
.confirm {
  left: 120px;
}
.confirm img {
  inset: 5px;
  width: 32px;
  height: 32px;
}
.confirm:disabled {
  opacity: 0;
  cursor: default;
  pointer-events: none;
}
.cancel {
  left: 267px;
}
.cancel img {
  top: 2px;
  left: 1px;
  width: 40px;
  height: 95px;
  object-fit: cover;
  object-position: top;
}
</style>
