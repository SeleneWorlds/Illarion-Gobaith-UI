import { computed, inject, reactive, type ComputedRef, type InjectionKey } from 'vue';
import { z } from 'zod';
import type { SeleneUiApi } from '../selene';

const skillSchema = z.object({
  id: z.number().int().nonnegative(),
  name: z.string().min(1),
  group: z.number().int().nonnegative(),
  major: z.number().min(0).max(100),
  minor: z.number().min(0).max(10000),
});

export type Skill = z.infer<typeof skillSchema>;
export interface SkillGroup {
  id: number;
  skills: readonly Skill[];
}
export interface SkillsStore {
  readonly groups: ComputedRef<readonly SkillGroup[]>;
}

export const skillsStoreKey: InjectionKey<SkillsStore> = Symbol('skills-store');

export const createSkillsStore = (network: SeleneUiApi['network']): SkillsStore => {
  const skills = reactive(new Map<number, Skill>());
  const update = (value: unknown) => {
    const result = skillSchema.safeParse(value);
    if (result.success) {
      if (result.data.major > 0 || result.data.minor > 0) {
        skills.set(result.data.id, result.data);
      } else {
        skills.delete(result.data.id);
      }
    }
  };

  network.onPayload('illarion:skill', update);
  network.onPayload('illarion:skills', (payload) => {
    const result = z.array(skillSchema).safeParse(payload.skills);
    if (!result.success) {
      return;
    }
    skills.clear();
    result.data.forEach((skill) => {
      if (skill.major > 0 || skill.minor > 0) {
        skills.set(skill.id, skill);
      }
    });
  });

  const groups = computed(() => {
    const grouped = new Map<number, Skill[]>();
    for (const skill of skills.values()) {
      const group = grouped.get(skill.group) ?? [];
      group.push(skill);
      grouped.set(skill.group, group);
    }
    return [...grouped.entries()]
      .sort(([left], [right]) => left - right)
      .map(([id, values]) => ({ id, skills: values.sort((left, right) => left.name.localeCompare(right.name)) }));
  });

  return { groups };
};

export const useSkillsStore = (): SkillsStore => {
  const store = inject(skillsStoreKey);
  if (!store) {
    throw new Error('Skills store was not provided.');
  }
  return store;
};
