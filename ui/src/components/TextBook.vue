<script setup lang="ts">
import { onBeforeUnmount, onMounted, watch } from 'vue';
import { useBookStore } from '../stores/books';
import { useUiAssetSrc } from '../composables/useClientAsset';
import { useI18n } from '../composables/useI18n';
import { useSelene } from '../selene';
import SeleneVisual from './SeleneVisual.vue';

const books = useBookStore();
const selene = useSelene();
const { t } = useI18n();
const background = useUiAssetSrc('menu_book.png');
let releaseKeys: (() => void) | undefined;
const onKeyDown = (event: KeyboardEvent) => {
  if (!books.current.value || event.defaultPrevented || selene.input.hasEditableFocus()) {
    return;
  }
  if (event.key === 'Escape') {
    books.close();
  } else if (event.key === 'ArrowLeft') {
    books.turn(-1);
  } else if (event.key === 'ArrowRight') {
    books.turn(1);
  } else {
    return;
  }
  event.preventDefault();
  event.stopImmediatePropagation();
};
watch(
  () => Boolean(books.current.value),
  (open) => {
    releaseKeys?.();
    releaseKeys = open ? selene.input.captureKeys('Escape', 'ArrowLeft', 'ArrowRight') : undefined;
  },
);
onMounted(() => {
  window.addEventListener('keydown', onKeyDown);
});
onBeforeUnmount(() => {
  releaseKeys?.();
  window.removeEventListener('keydown', onKeyDown);
});
</script>

<template>
  <section
    v-if="books.current.value"
    class="text-book"
    role="dialog"
    :aria-label="t('book.title', 'Book')"
    data-selene-interactive
    @pointerdown.stop
    @pointerup.stop
    @click.stop
    @contextmenu.prevent.stop
    @wheel.prevent.stop="books.turn(Math.sign($event.deltaY))"
  >
    <img class="background" :src="background" alt="" />
    <button
      class="left-page"
      type="button"
      :disabled="books.current.value.page <= 1"
      :aria-label="t('book.previous', 'Previous page')"
      @click="books.turn(-1)"
    >
      <SeleneVisual
        v-if="books.current.value.itemId > 0"
        :identifier="`illarion:items/item_${books.current.value.itemId}`"
        without-offset
      />
    </button>
    <button
      class="right-page"
      type="button"
      :aria-label="t('book.next', 'Next page')"
      :disabled="!books.canNext.value || books.current.value.page >= 250"
      @click="books.turn(1)"
    >
      <span class="text">{{ books.current.value.text }}</span>
      <span class="page-number">{{ books.current.value.page }}</span>
    </button>
    <button class="close" type="button" :aria-label="t('book.close', 'Close book')" @click="books.close">×</button>
  </section>
</template>

<style scoped>
.text-book {
  position: absolute;
  left: 237px;
  top: 209px;
  width: 610px;
  height: 350px;
  z-index: 20;
  pointer-events: auto;
  color: #342415;
}
.background {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
  pointer-events: none;
}
.left-page,
.right-page {
  position: absolute;
  top: 30px;
  height: 290px;
  border: 0;
  padding: 0;
  background: transparent;
  color: inherit;
  cursor: pointer;
}
.left-page {
  left: 30px;
  width: 230px;
}
.left-page :deep(img) {
  max-width: 100px;
  max-height: 100px;
  width: auto;
  height: auto;
}
.right-page {
  left: 290px;
  width: 215px;
  text-align: left;
  display: flex;
  flex-direction: column;
}
.text {
  white-space: pre-wrap;
  overflow-wrap: anywhere;
  font:
    18px/1.4 Georgia,
    serif;
  overflow-y: auto;
  flex: 1;
  width: 100%;
}
.page-number {
  align-self: flex-end;
  padding-top: 8px;
}
button:disabled {
  cursor: default;
}
.close {
  position: absolute;
  right: 75px;
  bottom: 14px;
  border: 0;
  background: transparent;
  color: inherit;
  font-size: 24px;
  cursor: pointer;
}
</style>
