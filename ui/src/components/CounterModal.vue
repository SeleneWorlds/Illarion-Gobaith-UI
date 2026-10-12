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
    @keydown="onKeydown"
    @keyup.stop
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
