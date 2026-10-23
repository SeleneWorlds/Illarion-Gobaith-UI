<script setup lang="ts">
import { onBeforeUnmount, onMounted, ref } from 'vue';
import { useHudLayout } from '../layout';
import { useSelene } from '../selene';
import { useChatStore } from '../stores/chat';

const selene = useSelene();
const layout = useHudLayout();
const chat = useChatStore();
const layer = ref<HTMLElement>();
const positions = ref<Record<number, { x: number; y: number; background: string; opacity: number }>>({});
let frame = 0;

function update(now: number) {
  chat.expireBubbles(now);
  const placed: Array<{ x: number; y: number; width: number; height: number }> = [];
  const next: typeof positions.value = {};
  for (const bubble of chat.bubbles.value) {
    const projected = selene.world.projectEntity(bubble.author);
    const point = projected && layout.toHud(projected);
    const element = layer.value?.querySelector<HTMLElement>(`[data-bubble="${bubble.id}"]`);
    if (!point || !element || point.x < 0 || point.x > 839 || point.y < 0 || point.y > 419) {
      continue;
    }
    const width = element.offsetWidth;
    const height = element.offsetHeight;
    const clampX = (x: number) => Math.max(4, Math.min(x, 835 - width));
    const clampY = (y: number) => Math.max(4, Math.min(y, 415 - height));
    // Prefer above the speaker, then try nearby positions to avoid other bubbles.
    const candidates = [
      { x: point.x - width / 2, y: point.y - height - 16 },
      { x: point.x + 30, y: point.y - height / 2 },
      { x: point.x - width - 30, y: point.y - height / 2 },
      { x: point.x - width / 2, y: point.y + 60 },
      ...placed.map((rect) => ({ x: point.x - width / 2, y: rect.y - height - 8 })),
    ].map(({ x, y }) => ({ x: clampX(x), y: clampY(y) }));
    const overlap = ({ x, y }: { x: number; y: number }) =>
      placed.reduce(
        (area, rect) =>
          area +
          Math.max(0, Math.min(x + width, rect.x + rect.width) - Math.max(x, rect.x)) *
            Math.max(0, Math.min(y + height, rect.y + rect.height) - Math.max(y, rect.y)),
        0,
      );
    const best = candidates.reduce((best, candidate) => (overlap(candidate) < overlap(best) ? candidate : best));
    placed.push({ ...best, width, height });
    const vertical = point.y < best.y || point.y > best.y + height;
    // Overlap subpaths inside one fill so the join has no seam or doubled opacity.
    const baseX = vertical
      ? Math.max(best.x + 10, Math.min(point.x, best.x + width - 10))
      : point.x < best.x
        ? best.x + 1
        : best.x + width - 1;
    const baseY = vertical
      ? point.y < best.y
        ? best.y + 1
        : best.y + height - 1
      : Math.max(best.y + 5, Math.min(point.y, best.y + height - 5));
    const a = { x: baseX - (vertical ? 5 : 0), y: baseY - (vertical ? 0 : 5) };
    const b = { x: baseX + (vertical ? 5 : 0), y: baseY + (vertical ? 0 : 5) };
    // Both closed subpaths must wind clockwise for a nonzero-fill union.
    const clockwise = (b.x - a.x) * (point.y - a.y) - (b.y - a.y) * (point.x - a.x) >= 0;
    const [start, end] = clockwise ? [a, b] : [b, a];
    const { x, y } = best;
    const right = x + width;
    const bottom = y + height;
    const radius = Math.min(8, width / 2, height / 2);
    const background = [
      `M ${x + radius} ${y} H ${right - radius} Q ${right} ${y} ${right} ${y + radius}`,
      `V ${bottom - radius} Q ${right} ${bottom} ${right - radius} ${bottom}`,
      `H ${x + radius} Q ${x} ${bottom} ${x} ${bottom - radius}`,
      `V ${y + radius} Q ${x} ${y} ${x + radius} ${y} Z`,
      `M ${start.x} ${start.y} L ${end.x} ${end.y} L ${point.x} ${point.y} Z`,
    ].join(' ');
    next[bubble.id] = {
      ...best,
      background,
      opacity: Math.max(0, Math.min(1, (now - bubble.createdAt) / 200, (bubble.expiresAt + 200 - now) / 200)),
    };
  }
  positions.value = next;
  frame = requestAnimationFrame(update);
}
onMounted(() => {
  frame = requestAnimationFrame(update);
});
onBeforeUnmount(() => cancelAnimationFrame(frame));
</script>

<template>
  <div ref="layer" class="chat-bubbles" aria-hidden="true">
    <template v-for="bubble in chat.bubbles.value" :key="bubble.id">
      <svg
        v-if="positions[bubble.id]"
        class="pointers"
        viewBox="0 0 839 419"
        :style="{ opacity: positions[bubble.id].opacity }"
      >
        <path :d="positions[bubble.id].background" fill-rule="nonzero" />
      </svg>
      <div
        :data-bubble="bubble.id"
        class="bubble"
        :class="bubble.kind"
        :style="{
          left: `${positions[bubble.id]?.x ?? 0}px`,
          top: `${positions[bubble.id]?.y ?? 0}px`,
          opacity: positions[bubble.id]?.opacity ?? 0,
        }"
      >
        <template v-if="bubble.kind === 'typing'">
          <span v-for="dot in 3" :key="dot" class="typing-dot" :style="{ animationDelay: `${(dot - 1) * 150}ms` }"
            >.</span
          >
        </template>
        <template v-else>{{ bubble.text }}</template>
      </div>
    </template>
  </div>
</template>

<style scoped>
.chat-bubbles {
  position: absolute;
  left: 0;
  top: 0;
  width: 839px;
  height: 419px;
  overflow: hidden;
  pointer-events: none;
}
.bubble {
  position: absolute;
  width: max-content;
  max-width: 290px;
  max-height: 407px;
  overflow: hidden;
  padding: 5px 10px;
  border-radius: 8px;
  color: white;
  text-align: center;
  font-size: 14px;
  line-height: 18px;
  white-space: pre-wrap;
  overflow-wrap: anywhere;
}
.bubble.typing {
  padding: 2px 9px;
}
.typing-dot {
  display: inline-block;
  animation: typing-pulse 1s infinite;
}
@keyframes typing-pulse {
  0%,
  60%,
  100% {
    opacity: 0.35;
    transform: translateY(0);
  }
  30% {
    opacity: 1;
    transform: translateY(-2px);
  }
}
.pointers {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
  fill: rgb(0 0 0 / 50%);
}
.whisper,
.ooc {
  color: #999;
}
.shout {
  color: #ff4c4c;
}
.emote {
  color: #ffff33;
}
</style>
