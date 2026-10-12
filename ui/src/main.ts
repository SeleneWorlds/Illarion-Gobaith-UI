import { createApp } from 'vue';
import App from './App.vue';
import blackChanceryUrl from './assets/fonts/BlackChancery.ttf?url';
import { createMockSeleneUiApi, seleneKey, type SeleneUiApi } from './selene';

export function mount(root: ParentNode, selene: SeleneUiApi): () => void {
  const target = root.querySelector('#illarion-ui');
  if (!(target instanceof HTMLElement)) {
    throw new Error('Missing Illarion UI mount element.');
  }

  // Register on the document: CSS font faces inside a shadow root are not
  // supported consistently by the embedded browser.
  const fonts = target.ownerDocument.fonts;
  if (!Array.from(fonts).some((font) => font.family === 'BlackChancery')) {
    const font = new FontFace('BlackChancery', `url("${blackChanceryUrl}")`, {
      style: 'normal',
      weight: '400',
    });
    fonts.add(font);
    void font.load().catch((error: unknown) => console.warn('Failed to load BlackChancery', error));
  }

  const app = createApp(App);
  app.provide(seleneKey, selene);
  app.mount(target);
  return () => app.unmount();
}

if (import.meta.env.DEV && document.querySelector('#illarion-ui')) {
  mount(document, createMockSeleneUiApi());
}
