<script setup lang="ts">
import { nextTick, onBeforeUnmount, onMounted, ref, shallowRef, useTemplateRef, watch } from 'vue';
import { useSelene } from '../selene';
import { useAdminRequestStore } from '../stores/adminRequest';
import GameModal from './GameModal.vue';
import RequestAdminForm from './RequestAdminForm.vue';
import ReportBugForm from './ReportBugForm.vue';
import SettingsPanel from './SettingsPanel.vue';
import { useI18n } from '../composables/useI18n';

const selene = useSelene();
const { t } = useI18n();
const isOpen = ref(false);
const adminRequest = useAdminRequestStore();
const menuItems = [
  { id: 'request-admin', title: '❔ Request Admin', titleKey: 'menu.requestAdmin', component: RequestAdminForm },
  { id: 'report-bug', title: '🪲 Report a Bug', titleKey: 'menu.reportBug', component: ReportBugForm },
  { id: 'settings', title: '⚙️ Settings', titleKey: 'menu.settings', component: SettingsPanel },
];
const activeItem = shallowRef<(typeof menuItems)[number] | null>(null);
const menuElement = useTemplateRef<HTMLDivElement>('menuElement');
let releaseKeys: (() => void) | undefined;
let mounted = false;

const focusMenu = async () => {
  await nextTick();
  menuElement.value?.querySelector('button')?.focus();
};
const back = () => {
  activeItem.value = null;
  adminRequest.close();
  void focusMenu();
};
const close = () => {
  adminRequest.close();
  isOpen.value = false;
  activeItem.value = null;
};
watch(adminRequest.isOpen, (open) => {
  if (open) {
    activeItem.value = menuItems[0]!;
    isOpen.value = true;
  }
});
const selectItem = (item: (typeof menuItems)[number]) => {
  if (item.id === 'request-admin') {
    adminRequest.open();
  }
  activeItem.value = item;
};
const onEscape = (event: KeyboardEvent) => {
  if (event.key !== 'Escape' || event.repeat || event.defaultPrevented) {
    return;
  }
  if (isOpen.value) {
    event.preventDefault();
    event.stopImmediatePropagation();
    close();
    return;
  }
  // Let existing menus and focused inputs consume Escape first.
  queueMicrotask(() => {
    if (!mounted || event.defaultPrevented) {
      return;
    }
    isOpen.value = true;
    void focusMenu();
  });
};
onMounted(() => {
  mounted = true;
  releaseKeys = selene.input.captureKeys('Escape');
  window.addEventListener('keydown', onEscape);
});
onBeforeUnmount(() => {
  mounted = false;
  releaseKeys?.();
  window.removeEventListener('keydown', onEscape);
});
</script>

<template>
  <GameModal
    v-if="isOpen"
    :title="activeItem ? t(activeItem.titleKey, activeItem.title) : t('menu.title', 'Menu')"
    :show-back="Boolean(activeItem)"
    @back="back"
    @close="close"
  >
    <div v-show="!activeItem" ref="menuElement" class="menu-actions">
      <button v-for="item in menuItems" :key="item.id" type="button" @click="selectItem(item)">
        {{ t(item.titleKey, item.title) }}
      </button>
    </div>
    <KeepAlive>
      <component :is="activeItem.component" v-if="activeItem" :key="activeItem.id" @close="close" />
    </KeepAlive>
  </GameModal>
</template>

<style scoped>
.menu-actions {
  display: grid;
  gap: 8px;
}
.menu-actions button {
  width: 100%;
  text-align: left;
}
</style>
