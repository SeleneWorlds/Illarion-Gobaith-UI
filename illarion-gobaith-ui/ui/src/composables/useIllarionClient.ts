import { inject, type InjectionKey } from 'vue';
import type { IllarionClient } from 'illarion-client-core';

export const illarionClientKey: InjectionKey<IllarionClient> = Symbol('illarion-client');
export const useIllarionClient = (): IllarionClient => {
  const client = inject(illarionClientKey);
  if (!client) {
    throw new Error('Illarion client was not provided.');
  }
  return client;
};
