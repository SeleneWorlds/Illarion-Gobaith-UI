<script setup lang="ts">
import { Bug, UserShield, Settings } from '@lucide/vue';
import MoonlightButton from 'moonlight-ui/MoonlightButton.vue';
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
  { id: 'settings', title: 'Settings', icon: Settings, titleKey: 'menu.settings', component: SettingsPanel },
  { id: 'report-bug', title: 'Report a Bug', icon: Bug, titleKey: 'menu.reportBug', component: ReportBugForm },
  {
    id: 'request-admin',
    title: 'Request Gamemaster',
    icon: UserShield,
    titleKey: 'menu.requestAdmin',
    component: RequestAdminForm,
  },
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
    activeItem.value = menuItems.find((item) => item.id === 'request-admin')!;
    isOpen.value = true;
  }
});
const selectItem = (item: (typeof menuItems)[number]) => {
  if (item.id === 'request-admin') {
    adminRequest.open();
  }
  activeItem.value = item;
};
const joinDiscord = () => {
  window.open('https://discord.gg/S7maQVRRa9', '_blank', 'noopener,noreferrer');
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
    class="escape-menu"
    :class="{ 'menu-home': !activeItem }"
    :title="activeItem ? t(activeItem.titleKey, activeItem.title) : t('menu.title', 'Menu')"
    :show-back="Boolean(activeItem)"
    @back="back"
    @close="close"
  >
    <div v-show="!activeItem" ref="menuElement" class="menu-actions">
      <MoonlightButton v-for="item in menuItems" :key="item.id" type="button" @click="selectItem(item)">
        <component :is="item.icon" :size="18" aria-hidden="true" />
        {{ t(item.titleKey, item.title) }}
      </MoonlightButton>
      <MoonlightButton type="button" @click="joinDiscord">
        <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
          <path
            d="M20.317 4.37a19.79 19.79 0 0 0-4.885-1.515c-.211.375-.457.88-.626 1.282a18.27 18.27 0 0 0-5.417 0 13.58 13.58 0 0 0-.636-1.282A19.736 19.736 0 0 0 3.87 4.37C.782 8.942-.055 13.4.364 17.795a19.9 19.9 0 0 0 5.993 3.03c.483-.66.914-1.36 1.286-2.095a12.9 12.9 0 0 1-2.025-.965c.17-.124.337-.253.499-.386 3.906 1.827 8.15 1.827 12.01 0 .163.133.33.262.5.386-.645.38-1.323.704-2.026.965.372.735.803 1.436 1.286 2.095a19.84 19.84 0 0 0 6.002-3.03c.49-5.095-.838-9.512-3.572-13.425ZM8.02 15.108c-1.173 0-2.135-1.076-2.135-2.397 0-1.32.942-2.397 2.135-2.397 1.192 0 2.154 1.086 2.134 2.397 0 1.32-.942 2.397-2.134 2.397Zm7.96 0c-1.173 0-2.135-1.076-2.135-2.397 0-1.32.942-2.397 2.135-2.397 1.192 0 2.154 1.086 2.134 2.397 0 1.32-.942 2.397-2.134 2.397Z"
          />
        </svg>
        {{ t('menu.joinDiscord', 'Join Discord') }}
      </MoonlightButton>
    </div>
    <KeepAlive>
      <component :is="activeItem.component" v-if="activeItem" :key="activeItem.id" @close="close" />
    </KeepAlive>
  </GameModal>
</template>

<style scoped>
.escape-menu.menu-home :deep(.modal-panel) {
  width: 260px;
}
.escape-menu :deep(header h2) {
  margin: 0;
  font-size: 20px;
  line-height: 1.3;
}
.menu-actions {
  display: grid;
  gap: 8px;
}
.menu-actions button {
  width: 100%;
  justify-content: flex-start;
  text-align: left;
}
</style>
