<script setup lang="ts">
import { computed, onMounted, ref, useTemplateRef } from 'vue';
import { useUiAssetSrc } from '../composables/useClientAsset';

const emit = defineEmits<{
  confirm: [value: string];
  cancel: [];
}>();
const input = useTemplateRef<HTMLInputElement>('input');
const text = ref('');
const name = computed(() => text.value.trim());
const valid = computed(() => name.value.length >= 3 && name.value.length <= 30);
const frame = useUiAssetSrc('menu_short.png');
const storeIcon = useUiAssetSrc('spellbook_store.png');
const closeIcon = useUiAssetSrc('menu_close.png');

const confirm = () => {
  if (valid.value) {
    emit('confirm', name.value);
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
    aria-labelledby="give-name-title"
    @click.stop
    @keydown="onKeydown"
    @keyup.stop
  >
    <img class="frame" :src="frame" alt="" />
    <form @submit.prevent="confirm">
      <label id="give-name-title" for="give-name-input">How would you like to name this person?</label>
      <input
        id="give-name-input"
        ref="input"
        v-model="text"
        type="text"
        maxlength="30"
        autocomplete="off"
        @keyup.stop
      />
      <button
        class="confirm"
        type="submit"
        :disabled="!valid"
        title="Note down the name"
        aria-label="Note down the name"
      >
        <img :src="storeIcon" alt="" />
      </button>
      <button class="cancel" type="button" title="Close dialog" aria-label="Close dialog" @click="emit('cancel')">
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
  color: #000;
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
  color: #000;
  font-size: 16px;
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
  color: #03c;
  font:
    18px Georgia,
    serif;
  caret-color: #03c;
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
