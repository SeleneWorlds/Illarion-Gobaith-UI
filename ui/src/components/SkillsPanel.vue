<script setup lang="ts">
import { computed } from 'vue';
import { useUiAssetSrc } from '../composables/useClientAsset';
import { useSkillsStore, type Skill } from '../stores/skills';
import { useMenu } from '../overlays';
import TextPanelMenu from './TextPanelMenu.vue';
import { useI18n } from '../composables/useI18n';

defineProps<{ active: boolean }>();
const emit = defineEmits<{ close: [] }>();

const { groups } = useSkillsStore();
const menu = useMenu();
const { get } = useI18n();
const backgroundUrl = useUiAssetSrc('gui_chat.png');
const scaleUrl = useUiAssetSrc('skill_scale.png');
const background = computed(() => (backgroundUrl.value ? `url(${backgroundUrl.value})` : 'none'));
const displayName = (name: string) =>
  get(`skills.${name}`) ?? name.replace(/([a-z0-9])([A-Z])/g, '$1 $2').replace(/^./, (first) => first.toUpperCase());
const groupName = (id: number) => get(`skills.group.${id}`) ?? `Group ${id + 1}`;
const skillColor = (skill: Skill) => {
  const stops = [
    [36, 36, 255],
    [77, 230, 77],
    [255, 250, 92],
  ];
  const section = skill.major > 50 ? 1 : 0;
  const amount = (skill.major - section * 50) / 50;
  return `rgb(${stops[section].map((value, index) => Math.round(value + (stops[section + 1][index] - value) * amount)).join(' ')})`;
};
const openTextMenu = async (event: MouseEvent) => {
  const action = await menu.open<'fold'>(
    TextPanelMenu,
    { skillsOpen: true },
    { label: 'Text box options', position: { x: event.clientX, y: event.clientY } },
  );
  if (action === 'fold') {
    emit('close');
  }
};
const onWheel = (event: WheelEvent) => {
  if (event.deltaY > 0) {
    emit('close');
  }
};
</script>

<template>
  <section
    class="skills-panel"
    :class="{ active }"
    :aria-label="get('skills.title') ?? 'Skills'"
    data-selene-interactive
    @contextmenu.prevent.stop="openTextMenu"
    @wheel.prevent.stop="onWheel"
  >
    <div class="groups">
      <section v-for="group in groups" :key="group.id" class="group">
        <h2>{{ groupName(group.id) }}</h2>
        <div
          v-for="skill in group.skills"
          :key="skill.id"
          class="skill"
          :style="{ '--minor': `${skill.minor / 100}%`, color: skillColor(skill) }"
          :title="`${displayName(skill.name)}: ${skill.major}.${String(Math.floor(skill.minor / 100)).padStart(2, '0')}`"
        >
          {{ displayName(skill.name) }}
        </div>
      </section>
    </div>
    <img class="scale" :src="scaleUrl" :alt="get('skills.scale') ?? 'Skill scale from low to high'" />
  </section>
</template>

<style scoped>
.skills-panel {
  position: absolute;
  left: 0;
  bottom: 141px;
  width: 784px;
  height: 212px;
  overflow: hidden;
  padding: 10px 14px 48px;
  background: v-bind(background) 0 100% / 100% 100% no-repeat;
  color: #fff;
  text-shadow: 1px 1px 2px #000;
  opacity: 0;
  pointer-events: none;
  transition:
    height 180ms ease-out,
    opacity 140ms ease-out;
}
.skills-panel.active {
  height: 590px;
  opacity: 1;
  pointer-events: auto;
}
.groups {
  height: 518px;
  overflow-x: auto;
  column-fill: auto;
  column-gap: 8px;
  column-width: 184px;
}
.group {
  min-width: 0;
  margin-bottom: 14px;
  break-inside: avoid;
}
h2 {
  margin: 0 0 4px;
  color: #b7d9ba;
  font-size: 14px;
}
.skill {
  position: relative;
  isolation: isolate;
  height: 18px;
  overflow: hidden;
  padding: 1px 2px;
  white-space: nowrap;
  text-overflow: ellipsis;
}
.skill::before {
  position: absolute;
  inset: 0 auto 0 0;
  z-index: -1;
  width: var(--minor);
  background: currentColor;
  opacity: 0.15;
  content: '';
}
.scale {
  position: absolute;
  right: 12px;
  bottom: 3px;
  width: 256px;
  height: 50px;
  object-fit: contain;
}
</style>
