<script setup lang="ts">
import { nextTick, onBeforeUnmount, onMounted, ref, useTemplateRef } from 'vue';
import { useSelene } from '../selene';
import { speechModeById, type SpeechModeId } from '../chatModes';
import { useChatMacros } from '../composables/useChatMacros';
import { useLogger } from '../composables/useLogger';
import SpeechModeControl from './SpeechModeControl.vue';

const selene = useSelene();
const logger = useLogger();
const chatMacros = useChatMacros();
const chatBackground = `url(${selene.resolveAsset('./assets/gui_chat.png')})`;
const MAX_INPUT_LENGTH = 200;
const DESCRIPTION_MACRO_KEYS = ['F2', 'F3', 'F4', 'F5', 'F6'] as const;
type MessageKind = 'inform' | 'emote' | SpeechModeId;
interface ChatMessage {
  id: number;
  author: string;
  text: string;
  kind: MessageKind;
}

const history = useTemplateRef<HTMLElement>('history');
const input = useTemplateRef<HTMLTextAreaElement>('input');
const message = ref('');
const selectedMode = ref<SpeechModeId>('normal');
const expanded = ref(false);
const messages = ref<ChatMessage[]>([]);
let nextMessageId = 0;
// Promise queue for sending and saving macros
let macroAction = Promise.resolve();

const resizeInput = async () => {
  await nextTick();
  if (!input.value || !history.value) {
    return;
  }
  input.value.style.height = '20px';
  input.value.style.height = `${Math.min(64, Math.max(20, input.value.scrollHeight))}px`;
  history.value.style.bottom = `${Math.min(76, input.value.offsetHeight + 12)}px`;
};
const addMessage = (text: unknown, kind: MessageKind, author = '', log = false) => {
  if (typeof text !== 'string' || text.length === 0) {
    return;
  }
  const entry = { id: nextMessageId++, author, text, kind };
  messages.value.push(entry);
  if (log) {
    logger.log(entry);
  }
  const excess = messages.value.length - 100;
  if (excess > 0) {
    messages.value.splice(0, excess);
  }
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
const useDescriptionMacro = (event: KeyboardEvent) => {
  if (!DESCRIPTION_MACRO_KEYS.includes(event.key as (typeof DESCRIPTION_MACRO_KEYS)[number])) {
    return false;
  }
  const key = event.shiftKey ? `Shift+${event.key}` : event.key;
  if (key === undefined || event.repeat) {
    return false;
  }
  event.preventDefault();
  event.stopPropagation();
  const save = event.ctrlKey;
  macroAction = macroAction
    .then(async () => {
      if (save) {
        if (!message.value) {
          return;
        }
        await chatMacros.save(key, message.value);
        message.value = '';
      } else {
        const stored = await chatMacros.load(key);
        if (stored === null) {
          return;
        }
        message.value = stored.slice(0, MAX_INPUT_LENGTH);
      }
      await resizeInput();
    })
    .catch((error) => console.warn(`Could not access description macro ${key}.`, error));
  return true;
};
const onInputKeydown = (event: KeyboardEvent) => {
  if (useDescriptionMacro(event)) {
    return;
  }
  if (selene.input.isPassthroughKey(event.key)) {
    return event.preventDefault();
  }
  event.stopPropagation();
  if (event.key === 'Enter' && !event.shiftKey) {
    event.preventDefault();
    send();
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
  if (useDescriptionMacro(event)) {
    return;
  }
  const root = input.value?.getRootNode();
  const activeElement = root instanceof Document || root instanceof ShadowRoot ? root.activeElement : null;
  if (event.defaultPrevented || isEditable(activeElement) || isEditable(event.target as Element | null)) {
    return;
  }
  if (event.key === 'Enter') {
    send();
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
  expanded.value = event.deltaY < 0;
};
onMounted(() => {
  window.addEventListener('keydown', onWindowKeydown, true);
  selene.input.captureKeys('Enter', 'Backspace', ...DESCRIPTION_MACRO_KEYS);
  selene.input.captureText();
  selene.input.passThroughKeys('ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight');
  selene.network.onPayload('illarion:inform', (payload) => void addMessage(payload.Message, 'inform'));
  selene.network.onPayload('illarion:chat', (payload) => {
    if (payload.showInChat === false) {
      return;
    }
    const author = typeof payload.authorName === 'string' ? payload.authorName : '';
    const text = typeof payload.message === 'string' ? payload.message : '';
    if (author || text) {
      void addMessage(text, payload.mode as MessageKind, author, true);
    }
  });
  void resizeInput();
});
onBeforeUnmount(() => {
  window.removeEventListener('keydown', onWindowKeydown, true);
});
</script>

<template>
  <section class="panel" :class="{ expanded }" aria-label="Chat" data-selene-interactive @wheel.prevent.stop="onWheel">
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
      aria-label="Chat message"
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
  transition: height 180ms ease-out;
}

.expanded {
  height: 590px;
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
