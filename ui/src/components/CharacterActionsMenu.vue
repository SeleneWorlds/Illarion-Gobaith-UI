<script setup lang="ts">
import { Ellipsis, Trash2 } from '@lucide/vue';
import MoonlightButton from 'moonlight-ui/MoonlightButton.vue';
import MoonlightSurface from 'moonlight-ui/MoonlightSurface.vue';
import { nextTick, onBeforeUnmount, onMounted, ref, useId } from 'vue';

defineProps<{ name: string; disabled: boolean }>();
const emit = defineEmits<{ delete: [] }>();
const open = ref(false);
const root = ref<HTMLElement>();
const trigger = ref<InstanceType<typeof MoonlightButton>>();
const action = ref<InstanceType<typeof MoonlightButton>>();
const menuId = useId();
const close = (restoreFocus = false) => {
  open.value = false;
  if (restoreFocus) {
    trigger.value?.focus();
  }
};
const toggle = async () => {
  open.value = !open.value;
  if (open.value) {
    await nextTick();
    action.value?.focus();
  }
};
const outside = (event: Event) => {
  if (root.value && !event.composedPath().includes(root.value)) {
    close();
  }
};
const blur = (event: FocusEvent) => {
  // The game bridge can clear DOM focus during pointer-down. A null target
  // does not mean the pointer left this menu; outside clicks are handled above.
  if (event.relatedTarget instanceof Node && !root.value?.contains(event.relatedTarget)) {
    close();
  }
};
let eventRoot: Node | undefined;
onMounted(() => {
  // Document listeners cannot see the internal event path of Selene's closed
  // shadow root, so they would classify clicks on Delete as outside clicks.
  eventRoot = root.value?.getRootNode();
  eventRoot?.addEventListener('mousedown', outside, true);
});
onBeforeUnmount(() => eventRoot?.removeEventListener('mousedown', outside, true));
</script>

<template>
  <div ref="root" class="character-actions" @focusout="blur" @keydown.esc.stop.prevent="close(true)">
    <MoonlightButton
      ref="trigger"
      variant="ghost"
      size="icon"
      aria-haspopup="menu"
      :aria-expanded="open"
      :aria-controls="menuId"
      :disabled="disabled"
      @click="toggle"
      @keydown.down.prevent="!open && toggle()"
      ><Ellipsis :size="16" aria-hidden="true"
    /></MoonlightButton>
    <MoonlightSurface
      v-if="open"
      :id="menuId"
      variant="popup"
      class="actions-popup"
      role="menu"
    >
      <MoonlightButton
        ref="action"
        variant="ghost"
        class="moonlight-item"
        role="menuitem"
        :disabled="disabled"
        @click="
          close();
          emit('delete');
        "
      >
        <Trash2 :size="16" aria-hidden="true" /> Delete
      </MoonlightButton>
    </MoonlightSurface>
  </div>
</template>

<style scoped>
.character-actions {
  position: relative;
  display: flex;
  align-items: center;
}
.actions-popup {
  position: absolute;
  z-index: 1;
  top: calc(50% + 18px);
  right: 0;
  min-width: 120px;
  padding: 4px;
}
</style>
