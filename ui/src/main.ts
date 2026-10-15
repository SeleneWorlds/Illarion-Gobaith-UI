import { createApp } from 'vue';
import App from './App.vue';
import blackChanceryUrl from './assets/fonts/BlackChancery.ttf?url';
import { createMockSeleneUiApi, seleneKey, type SeleneUiApi } from './selene';

function clearTextFocus(root: Document | ShadowRoot): void {
  const active = root.activeElement;
  if (active instanceof HTMLElement) {
    active.blur();
  }
  root.ownerDocument?.getSelection()?.removeAllRanges();
  if (root instanceof Document) {
    root.getSelection()?.removeAllRanges();
  }
}

function preventBackgroundFocus(event: Event): void {
  const target = event.composedPath()[0];
  if (!(target instanceof Element)) {
    return;
  }
  if (target.closest('input, textarea, select') || (target instanceof HTMLElement && target.isContentEditable)) {
    return;
  }

  // Allow native selection only when the pointer actually hits selectable text.
  // Empty space in a text container must not establish a browser selection caret.
  const mouse = event as MouseEvent;
  const walker = target.ownerDocument.createTreeWalker(target, NodeFilter.SHOW_TEXT);
  const range = target.ownerDocument.createRange();
  while (walker.nextNode()) {
    const text = walker.currentNode;
    const parent = text.parentElement;
    if (!parent || !text.textContent?.trim()) {
      continue;
    }
    const style = getComputedStyle(parent);
    if (style.userSelect === 'none' || style.webkitUserSelect === 'none') {
      continue;
    }
    range.selectNodeContents(text);
    if (
      Array.from(range.getClientRects()).some(
        (rect) =>
          mouse.clientX >= rect.left &&
          mouse.clientX <= rect.right &&
          mouse.clientY >= rect.top &&
          mouse.clientY <= rect.bottom,
      )
    ) {
      return;
    }
  }
  event.preventDefault();
  const root = target.getRootNode();
  if (root instanceof Document || root instanceof ShadowRoot) {
    clearTextFocus(root);
  }
}

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
  root.addEventListener('mousedown', preventBackgroundFocus, true);
  // World clicks are delivered through the game bridge rather than DOM events.
  const releasePointerDown = selene.input.onPointerDown(({ clientX, clientY }) => {
    const domRoot = target.getRootNode();
    if (!(domRoot instanceof Document || domRoot instanceof ShadowRoot)) {
      return;
    }
    const hit = domRoot.elementFromPoint(clientX, clientY);
    if (!hit || !target.contains(hit)) {
      clearTextFocus(domRoot);
    }
  });
  return () => {
    releasePointerDown();
    root.removeEventListener('mousedown', preventBackgroundFocus, true);
    app.unmount();
  };
}

if (import.meta.env.DEV && document.querySelector('#illarion-ui')) {
  mount(document, createMockSeleneUiApi());
}
