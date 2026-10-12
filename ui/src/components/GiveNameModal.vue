<script setup lang="ts">
import { computed, onMounted, ref, useTemplateRef } from 'vue';
import { useUiAssetSrc } from '../composables/useClientAsset';

const props = defineProps<{ value?: string }>();
const emit = defineEmits<{
  confirm: [value: string];
  cancel: [];
}>();
const input = useTemplateRef<HTMLInputElement>('input');
const text = ref(props.value ?? '');
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
  width: 400px;
  color: #000;
  font:
    24px/30px BlackChancery,
    Georgia,
    serif;
  text-shadow: none;
  transform: translate(-50%, -50%);
  pointer-events: auto;
}
.frame {
  position: absolute;
  inset: 0;
  width: 460px;
  height: 100%;
  pointer-events: none;
  user-select: none;
}
.editor form {
  position: relative;
  padding: 60px 0 190px;
}
.editor label {
  display: block;
  width: 340px;
  margin-left: 60px;
  color: #000;
}
.editor input {
  position: absolute;
  bottom: 145px;
  left: 60px;
  width: 340px;
  height: 30px;
  padding: 0;
  border: 0;
  outline: 0;
  background: transparent;
  color: #03c;
  font: inherit;
  caret-color: #03c;
  pointer-events: auto;
}
.editor button {
  position: absolute;
  padding: 0;
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
  bottom: 60px;
  width: 64px;
  height: 64px;
  transition: opacity 400ms linear;
  @starting-style {
    opacity: 0;
  }
}
.confirm img {
  inset: 0;
  width: 100%;
  height: 100%;
}
.confirm:disabled {
  opacity: 0;
  cursor: default;
  pointer-events: none;
}
.cancel {
  left: 266px;
  bottom: -160px;
  width: 80px;
  height: 190px;
}
.cancel img {
  inset: 0;
  width: 100%;
  height: 100%;
}
</style>
