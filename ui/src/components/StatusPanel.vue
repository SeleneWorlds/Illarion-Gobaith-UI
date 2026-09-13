<script setup lang="ts">
import { computed, ref } from 'vue';
import { useClientAssetSrc, useClientAssetStyle } from '../composables/useClientAsset';
import { useVitalsStore } from '../stores/vitals';

const { health, food, mana } = useVitalsStore();
const modes = {
  status: {
    tooltip: 'These gauges show your health, when you need to eat and your mana. Click to show the clock.',
    ariaLabel: 'Character status; show clock',
    next: 'clock',
  },
  clock: {
    tooltip: 'This clock shows the day and month, the time of day and the temperature. Click to show your status.',
    ariaLabel: 'Game clock; show character status',
    next: 'status',
  },
} as const;
type Mode = keyof typeof modes;

const mode = ref<Mode>('status');
const currentMode = computed(() => modes[mode.value]);

const healthBackground = useClientAssetStyle('client/textures/illarion/ui/status_health.png');
const foodBackground = useClientAssetStyle('client/textures/illarion/ui/status_food.png');
const manaBackground = useClientAssetStyle('client/textures/illarion/ui/status_mana.png');
const frameSrc = useClientAssetSrc('client/textures/illarion/ui/gui_status.png');
const clockTimeSrc = useClientAssetSrc('client/textures/illarion/ui/clock_time.png');
const clockTemperatureSrc = useClientAssetSrc('client/textures/illarion/ui/clock_temp.png');
const clockDragonSrc = useClientAssetSrc('client/textures/illarion/ui/clock_dragon.png');

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
    :aria-label="currentMode.ariaLabel"
    :title="currentMode.tooltip"
    @click.stop="mode = currentMode.next"
  >
    <template v-if="mode === 'status'">
      <img class="frame" :src="frameSrc" alt="" />
      <span class="bar health">
        <span :style="{ backgroundImage: healthBackground, height: `${health * 100}%` }" />
      </span>
      <span class="bar food">
        <span :style="{ backgroundImage: foodBackground, height: `${food * 100}%` }" />
      </span>
      <span class="bar mana">
        <span :style="{ backgroundImage: manaBackground, height: `${mana * 100}%` }" />
      </span>
    </template>
    <span v-else class="clock" aria-hidden="true">
      <span class="time-strip">
        <img :src="clockTimeSrc" alt="" :style="{ left: `${32 - timeOffset}px` }" />
      </span>
      <span class="temperature-strip">
        <img :src="clockTemperatureSrc" alt="" :style="{ left: `${67 - temperatureOffset}px` }" />
      </span>
      <img class="dragon" :src="clockDragonSrc" alt="" />
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
  transition: height 180ms ease-out;
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
