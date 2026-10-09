<script setup lang="ts">
import { computed, onUnmounted, ref } from 'vue';
import { useClientAssetSrc, useClientAssetStyle } from '../composables/useClientAsset';
import { onConnected } from '../composables/onConnected';
import { useSelene } from '../selene';
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

const selene = useSelene();
const monthNames = [
  'Elos',
  'Tanos',
  'Zhas',
  'Ushos',
  'Siros',
  'Ronas',
  'Bras',
  'Eldas',
  'Irmas',
  'Malas',
  'Findos',
  'Olos',
  'Adras',
  'Naras',
  'Chos',
  'Mas',
] as const;
const clock = ref({ year: 0, month: 1, day: 1, hour: 0, minute: 0 });
const temperature = ref(15);

const unsubscribeTime = selene.network.onPayload('illarion:time', (payload) => {
  const values = [payload.year, payload.month, payload.day, payload.hour, payload.minute];
  if (!values.every((value) => typeof value === 'number' && Number.isFinite(value))) {
    return;
  }
  clock.value = {
    year: payload.year as number,
    month: payload.month as number,
    day: payload.day as number,
    hour: payload.hour as number,
    minute: payload.minute as number,
  };
});

const unsubscribeWeather = selene.network.onPayload('illarion:weather', (payload) => {
  if (typeof payload.temperature === 'number' && Number.isFinite(payload.temperature)) {
    temperature.value = payload.temperature;
  }
});
onConnected(() => {
  selene.network.sendToServer('illarion:request_time');
  selene.network.sendToServer('illarion:request_weather');
});

onUnmounted(() => {
  unsubscribeTime();
  unsubscribeWeather();
});

const displayClock = computed(() => {
  return {
    day: `${clock.value.day}.`,
    month: monthNames[clock.value.month - 1] ?? monthNames[0],
    year: clock.value.year,
    hour: clock.value.hour,
    minute: clock.value.minute,
    temperature: temperature.value,
  };
});
const timeOffset = computed(() =>
  Math.floor(((displayClock.value.hour * 60 + displayClock.value.minute) * 329) / 1440),
);
const temperatureOffset = computed(() => {
  const clampedTemperature = Math.max(-15, Math.min(45, displayClock.value.temperature));
  return Math.floor(((clampedTemperature + 15) * 280) / 60);
});
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
        <img :src="clockTimeSrc" alt="" :style="{ left: `${-10 - timeOffset}px` }" />
      </span>
      <span class="temperature-strip">
        <img :src="clockTemperatureSrc" alt="" :style="{ left: `${-temperatureOffset}px` }" />
      </span>
      <img class="dragon" :src="clockDragonSrc" alt="" />
      <span class="day">{{ displayClock.day }}</span>
      <span class="month">{{ displayClock.month }}</span>
      <span class="year">{{ displayClock.year }}</span>
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
  bottom: 31px;
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
