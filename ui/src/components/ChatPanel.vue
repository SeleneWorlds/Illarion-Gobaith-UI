<script setup lang="ts">
import { computed, nextTick, onBeforeUnmount, onMounted, ref, useTemplateRef } from 'vue';
import { useSelene } from '../selene';
import { speechModeById, type SpeechModeId } from '../chatModes';
import { useChatMacros } from '../composables/useChatMacros';
import SpeechModeControl from './SpeechModeControl.vue';
import { useUiAssetSrc } from '../composables/useClientAsset';
import { useChatStore } from '../stores/chat';
import { useMenu } from '../overlays';
import TextPanelMenu from './TextPanelMenu.vue';

const selene = useSelene();
const props = defineProps<{ expanded: boolean; hidden: boolean }>();
const emit = defineEmits<{ openSkills: []; setExpanded: [expanded: boolean] }>();
const menu = useMenu();
const { messages } = useChatStore();
const chatMacros = useChatMacros();
const chatBackgroundUrl = useUiAssetSrc('gui_chat.png');
const chatBackground = computed(() => (chatBackgroundUrl.value ? `url(${chatBackgroundUrl.value})` : 'none'));
const MAX_INPUT_LENGTH = 200;
const MACRO_DEFAULT_KEYS = ['F2', 'F3', 'F4', 'F5', 'F6'] as const;
const history = useTemplateRef<HTMLElement>('history');
const input = useTemplateRef<HTMLTextAreaElement>('input');
const message = ref('');
const selectedMode = ref<SpeechModeId>('normal');
// Promise queue for sending and saving macros
let macroAction = Promise.resolve();
const releases: Array<() => void> = [];

const resizeInput = async () => {
  await nextTick();
  if (!input.value || !history.value) {
    return;
  }
  input.value.style.height = '20px';
  input.value.style.height = `${Math.min(64, Math.max(20, input.value.scrollHeight))}px`;
  history.value.style.bottom = `${Math.min(76, input.value.offsetHeight + 12)}px`;
};
const send = () => {
  const text = message.value.trim();
  if (!text) {
    return;
  }
  const currentMode = speechModeById(selectedMode.value);
  const prefix = 'prefix' in currentMode ? currentMode.prefix : '';
  selene.network.sendToServer('illarion:chat', {
    mode: currentMode.payloadMode,
    message: `${prefix}${text}`,
  });
  message.value = '';
  void resizeInput();
};
const selectLanguage = (language: string) => {
  selene.network.sendToServer('illarion:chat', { mode: 'normal', message: `!l ${language.toLowerCase()}` });
};
const useMacro = (slot: number, save: boolean) => {
  macroAction = macroAction
    .then(async () => {
      if (save) {
        if (!message.value) {
          return;
        }
        await chatMacros.save(slot, message.value);
        message.value = '';
      } else {
        const stored = await chatMacros.load(slot);
        if (stored === null) {
          return;
        }
        message.value = stored.slice(0, MAX_INPUT_LENGTH);
      }
      await resizeInput();
    })
    .catch((error) => console.warn(`Could not access chat macro ${slot}.`, error));
};
const onInputKeydown = (event: KeyboardEvent) => {
  if (selene.input.isPassthroughKey(event.key)) {
    return event.preventDefault();
  }
  event.stopPropagation();
  if (event.key === 'Enter' && !event.shiftKey && !event.ctrlKey && !event.altKey && !event.metaKey) {
    event.preventDefault();
    if (!event.repeat) {
      send();
    }
  } else if (event.key === 'Escape') {
    event.preventDefault();
    input.value?.blur();
  }
};
const onInputKeyup = (event: KeyboardEvent) => {
  if (!selene.input.isPassthroughKey(event.key)) {
    event.stopPropagation();
  }
};
const isEditable = (element: Element | null): boolean =>
  element instanceof HTMLInputElement ||
  element instanceof HTMLTextAreaElement ||
  (element instanceof HTMLElement && element.isContentEditable);
const onWindowKeydown = (event: KeyboardEvent) => {
  if (selene.input.hasEditableFocus()) {
    return;
  }
  if ((event.ctrlKey || event.metaKey) && !event.altKey && event.key.toLowerCase() === 'a') {
    event.preventDefault();
    event.stopImmediatePropagation();
    input.value?.focus();
    input.value?.select();
    return;
  }
  if (selene.input.isPassthroughKey(event.key)) {
    return;
  }
  const root = input.value?.getRootNode();
  const activeElement = root instanceof Document || root instanceof ShadowRoot ? root.activeElement : null;
  if (
    event.shiftKey &&
    ['ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight', 'Home', 'End', 'PageUp', 'PageDown'].includes(event.key) &&
    !isEditable(activeElement) &&
    !isEditable(event.target as Element | null)
  ) {
    event.preventDefault();
    event.stopPropagation();
    return;
  }
  if (event.defaultPrevented || isEditable(activeElement) || isEditable(event.target as Element | null)) {
    return;
  }
  if (event.key === 'Enter' && !event.shiftKey && !event.ctrlKey && !event.altKey && !event.metaKey) {
    if (!event.repeat) {
      send();
    }
  } else if (event.key === 'Backspace') {
    message.value = message.value.slice(0, -1);
  } else if (
    event.key.length === 1 &&
    !event.ctrlKey &&
    !event.metaKey &&
    !event.altKey &&
    message.value.length < MAX_INPUT_LENGTH
  ) {
    message.value += event.key;
  } else {
    return;
  }
  event.preventDefault();
  event.stopPropagation();
  void resizeInput();
};
const onWheel = (event: WheelEvent) => {
  if (event.deltaY === 0) {
    return;
  }
  emit('setExpanded', event.deltaY < 0);
};
const openTextMenu = async (event: MouseEvent) => {
  const action = await menu.open<'fold' | 'unfold' | 'skills'>(
    TextPanelMenu,
    { skillsOpen: false, expanded: props.expanded },
    { label: 'Text box options', position: { x: event.clientX, y: event.clientY } },
  );
  if (action === 'skills') {
    emit('openSkills');
  } else if (action !== undefined) {
    emit('setExpanded', action === 'unfold');
  }
};
onMounted(() => {
  for (let index = 0; index < 10; index++) {
    const slot = index + 1;
    const defaultBinding = index < 5 ? `Shift+${MACRO_DEFAULT_KEYS[index]}` : null;
    for (const save of [false, true]) {
      releases.push(
        selene.input.registerBinding(
          {
            id: `chat.macro.${slot}.${save ? 'save' : 'load'}`,
            label: `${save ? 'Save' : 'Load'} macro ${slot}`,
            category: 'Macros',
            allowInText: true,
            defaultBinding: defaultBinding ? `${save ? 'Ctrl+' : ''}${defaultBinding}` : null,
          },
          () => {
            const root = input.value?.getRootNode();
            if (
              selene.input.hasEditableFocus() &&
              (!(root instanceof ShadowRoot || root instanceof Document) || root.activeElement !== input.value)
            ) {
              return false;
            }
            useMacro(slot, save);
          },
        ),
      );
    }
  }
  window.addEventListener('keydown', onWindowKeydown, true);
  releases.push(selene.input.captureKeys('Enter', 'Backspace'), selene.input.captureText());
  void resizeInput();
});
onBeforeUnmount(() => {
  for (const release of releases) {
    release();
  }
  window.removeEventListener('keydown', onWindowKeydown, true);
});
</script>

<template>
  <section
    class="panel"
    :class="{ expanded: props.expanded, hidden: props.hidden }"
    data-selene-interactive
    @contextmenu.prevent.stop="openTextMenu"
    @wheel.prevent.stop="onWheel"
  >
    <div ref="history" class="history" role="log" aria-live="polite" aria-relevant="additions">
      <div class="history-content">
        <TransitionGroup name="line">
          <p v-for="item in messages" :key="item.id" :class="item.kind">
            <strong v-if="item.author">{{ item.author }}{{ item.kind === 'emote' ? ' ' : ': ' }}</strong
            >{{ item.text }}
          </p>
        </TransitionGroup>
      </div>
    </div>
    <textarea
      id="chat-input"
      ref="input"
      v-model="message"
      class="input"
      rows="1"
      :maxlength="MAX_INPUT_LENGTH"
      autocomplete="off"
      spellcheck="true"
      @input="resizeInput"
      @keydown="onInputKeydown"
      @keyup="onInputKeyup"
    />
  </section>
  <SpeechModeControl v-model="selectedMode" @language-select="selectLanguage" />
</template>

<style scoped>
.panel {
  position: absolute;
  left: 0;
  bottom: 141px;
  width: 784px;
  height: 212px;
  overflow: hidden;
  padding: 12px 18px 10px 12px;
  color: #fff;
  text-shadow:
    1px 1px 2px #000,
    0 0 3px #000;
  pointer-events: auto;
  transition:
    height 180ms ease-out,
    opacity 140ms ease-out;
}

.expanded {
  height: 590px;
}
.hidden {
  opacity: 0;
  pointer-events: none;
}
.panel::before {
  position: absolute;
  inset: 0;
  background: v-bind(chatBackground) 0 100% / 100% 100% no-repeat;
  content: '';
  transition: opacity 180ms ease-out;
}
.expanded::before {
  opacity: 0.75;
}
.history {
  position: absolute;
  top: 8px;
  right: 18px;
  bottom: 32px;
  left: 12px;
  overflow: hidden;
  -webkit-user-select: text;
  user-select: text;
}
.history-content {
  position: absolute;
  right: 0;
  bottom: 0;
  left: 0;
}
.panel p {
  margin: 2px 0;
  line-height: 1.25;
}
.line-enter-active {
  transition:
    opacity 140ms ease-out,
    transform 140ms ease-out;
}
.line-enter-from {
  opacity: 0;
  transform: translateY(16px);
}
.inform {
  color: #b2ccff;
}
.whisper,
.ooc {
  color: #999999;
}
.shout {
  color: #ff4c4c;
}
.emote {
  color: #ffff33;
}
.input {
  position: absolute;
  right: 18px;
  bottom: 8px;
  left: 12px;
  height: 20px;
  min-height: 20px;
  max-height: 64px;
  margin: 0;
  padding: 1px 3px;
  resize: none;
  overflow: hidden;
  border: 0;
  outline: 0;
  background: transparent;
  color: #fff;
  line-height: 17px;
  text-shadow: inherit;
}
</style>
