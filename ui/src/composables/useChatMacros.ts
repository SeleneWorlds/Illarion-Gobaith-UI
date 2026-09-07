import { useSelene } from '../selene';

const descriptionMacroStorageKey = (key: string) => `illarion.descriptionMacro.${key}`;

export const useChatMacros = () => {
  const { storage } = useSelene();

  const load = (key: string) => storage.load(descriptionMacroStorageKey(key));
  const save = (key: string, message: string) => storage.save(descriptionMacroStorageKey(key), message);

  return { load, save };
};
