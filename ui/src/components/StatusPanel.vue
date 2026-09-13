<script setup lang="ts">
// TODO deslop file
import { computed, onUnmounted, ref, watch, type Ref } from 'vue';
import { useSelene } from '../selene';
import { useVitalsStore } from '../stores/vitals';

const selene = useSelene();
const vitals = useVitalsStore();
const mode = ref<0 | 1>(0);
const tooltips = [
  'These gauges show your health, when you need to eat and your mana. Click to show the clock.',
  'This clock shows the day and month, the time of day and the temperature. Click to show your status.',
] as const;
const backgroundImage = (path: string) => ({ backgroundImage: `url("${selene.resolveAsset(path)}")` });

/** Reproduce Animation.approach at the legacy client's default 25 FPS. */
const statusBar = (source: Readonly<Ref<number>>, asset: string, maxValue: number) => {
  const value = ref(0);
  let target = 0;
  let frame: number | undefined;
  let previousTime: number | undefined;
  let elapsed = 0;

  const approach = () => {
    const difference = target - value.value;
    if (difference === 0) {
      return;
    }
    const step = Math.abs(difference) > 4 ? Math.trunc(difference / 4) : Math.sign(difference);
    value.value = Math.min(maxValue, Math.max(0, value.value + step));
  };
  const animate = (time: number) => {
    if (previousTime !== undefined) {
      elapsed += Math.min(time - previousTime, 200);
    }
    previousTime = time;
    while (elapsed >= 40) {
      approach();
      elapsed -= 40;
    }
    if (value.value !== target) {
      frame = requestAnimationFrame(animate);
    } else {
      frame = undefined;
      previousTime = undefined;
      elapsed = 0;
    }
  };
  watch(
    source,
    (normalizedValue) => {
      target = Math.round(normalizedValue * maxValue);
      if (frame === undefined && value.value !== target) {
        frame = requestAnimationFrame(animate);
      }
    },
    { immediate: true },
  );
  onUnmounted(() => {
    if (frame !== undefined) {
      cancelAnimationFrame(frame);
    }
  });
  return computed(() => ({
    ...backgroundImage(asset),
    height: `${(value.value / maxValue) * 100}%`,
  }));
};

const healthStyle = statusBar(vitals.health, './assets/status_health.png', 10_000);
const foodStyle = statusBar(vitals.food, './assets/status_food.png', 60_000);
const manaStyle = statusBar(vitals.mana, './assets/status_mana.png', 10_000);

// Fixed until game date, time, and weather payloads are available.
const clock = { day: '1.', month: 'Elos', year: '1', hour: 12, minute: 0, temperature: 15 };
const timeOffset = ((clock.hour * 60 + clock.minute) * 329) / 1440;
const temperatureOffset = ((clock.temperature + 15) * 280) / 60;
</script>

<template>
  <button
    class="status"
    type="button"
    data-selene-interactive
    :aria-label="mode === 0 ? 'Character status; show clock' : 'Game clock; show character status'"
    :title="tooltips[mode]"
    @click.stop="mode = mode === 0 ? 1 : 0"
  >
    <template v-if="mode === 0">
      <img class="frame" :src="selene.resolveAsset('./assets/gui_status.png')" alt="" />
      <span class="bar health"><span :style="healthStyle" /></span>
      <span class="bar food"><span :style="foodStyle" /></span>
      <span class="bar mana"><span :style="manaStyle" /></span>
    </template>
    <span v-else class="clock" aria-hidden="true">
      <span class="time-strip">
        <img :src="selene.resolveAsset('./assets/clock_time.png')" alt="" :style="{ left: `${32 - timeOffset}px` }" />
      </span>
      <span class="temperature-strip">
        <img
          :src="selene.resolveAsset('./assets/clock_temp.png')"
          alt=""
          :style="{ left: `${67 - temperatureOffset}px` }"
        />
      </span>
      <img class="dragon" :src="selene.resolveAsset('./assets/clock_dragon.png')" alt="" />
      <span class="day">{{ clock.day }}</span>
      <span class="month">{{ clock.month }}</span>
      <span class="year">{{ clock.year }}</span>
    </span>
  </button>
</template>

<style scoped>
.status {
  position: absolute;
  right: -1px;
  bottom: 454px;
  width: 177px;
  height: 139px;
  padding: 0;
  border: 0;
  outline: 0;
  background: transparent;
  color: inherit;
  font: inherit;
  text-align: left;
  cursor: pointer;
  pointer-events: auto;
}
.frame {
  position: absolute;
  inset: 0;
  display: block;
  width: 177px;
  height: 139px;
  user-select: none;
}
.bar {
  position: absolute;
  bottom: 28px;
  width: 12px;
  height: 80px;
  overflow: hidden;
  background: rgb(7 8 8 / 78%);
}
.bar > span {
  position: absolute;
  right: 0;
  bottom: 0;
  left: 0;
  background-position: bottom;
  background-repeat: repeat-y;
}
.health {
  left: 53px;
}
.food {
  left: 81px;
}
.mana {
  left: 109px;
}
.clock {
  position: absolute;
  inset: 0;
  display: block;
}
.dragon {
  position: absolute;
  left: -8px;
  bottom: -4px;
  width: 185px;
  height: 141px;
  user-select: none;
}
.time-strip {
  position: absolute;
  left: 42px;
  bottom: 58px;
  width: 90px;
  height: 65px;
  overflow: hidden;
}
.time-strip img {
  position: absolute;
  bottom: -2px;
  width: 453px;
  height: 64px;
  max-width: none;
}
.temperature-strip {
  position: absolute;
  left: 67px;
  bottom: 11px;
  width: 65px;
  height: 50px;
  overflow: hidden;
}
.temperature-strip img {
  position: absolute;
  bottom: 0;
  width: 343px;
  height: 54px;
  max-width: none;
}
.day,
.month,
.year {
  position: absolute;
  z-index: 1;
  color: #dfd09d;
  font-size: 13px;
  line-height: 16px;
  text-shadow: 1px 1px #26180e;
}
.day {
  left: 8px;
  bottom: 33px;
}
.month {
  left: 8px;
  bottom: 13px;
}
.year {
  left: 138px;
  bottom: 13px;
  color: #b8a276;
}
</style>
