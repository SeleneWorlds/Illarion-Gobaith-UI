import { inject, type InjectionKey } from 'vue';
import type { SkillsStore } from 'illarion-client-core';
export type { SkillsStore, Skill, SkillGroup } from 'illarion-client-core';
export const skillsStoreKey: InjectionKey<SkillsStore> = Symbol('skills-store');

export const useSkillsStore = (): SkillsStore => {
  const store = inject(skillsStoreKey);
  if (!store) {
    throw new Error('Skills store was not provided.');
  }
  return store;
};
