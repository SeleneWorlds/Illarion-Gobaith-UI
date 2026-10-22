import type { InjectionKey, Ref } from 'vue';

export const inputCursorKey: InjectionKey<Readonly<Ref<string | undefined>>> = Symbol('input-cursor');
