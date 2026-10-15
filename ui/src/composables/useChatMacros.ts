import { useSelene } from '../selene';

const macroStorageKey = (slot: number) => `illarion.chatMacro.${slot}`;

export const useChatMacros = () => {
  const { storage } = useSelene();

  const load = (slot: number) => storage.load(macroStorageKey(slot));
  const save = (slot: number, message: string) => storage.save(macroStorageKey(slot), message);

  return { load, save };
};
