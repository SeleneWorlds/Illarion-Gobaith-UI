import { onBeforeUnmount, readonly, ref } from 'vue';
import { useSelene } from '../selene';

export const useI18n = () => {
  const { i18n, preferences } = useSelene();
  const locale = ref(preferences.getLocale());
  const release = preferences.onLocaleChanged((value) => {
    locale.value = value;
  });
  onBeforeUnmount(release);

  const get = (key: string) => i18n.get(key, locale.value);
  const t = (key: string, fallback: string) => get(key) ?? fallback;
  return { locale: readonly(locale), get, t };
};
