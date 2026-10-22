import { ref, watch, type MaybeRefOrGetter } from 'vue';
import { useVisual, type RenderLayer } from './useVisual';

export const useVisualCursor = (identifier: MaybeRefOrGetter<string | undefined>) => {
  const layers = useVisual(identifier);
  const cursor = ref<string>();
  const images = new Map<string, Promise<HTMLImageElement>>();
  const rendered = new Map<string, Promise<string>>();

  const loadImage = (texture: string) => {
    let image = images.get(texture);
    if (!image) {
      image = new Promise<HTMLImageElement>((resolve, reject) => {
        const element = new Image();
        element.onload = () => resolve(element);
        element.onerror = () => reject(new Error(`Cursor texture could not be loaded: ${texture}`));
        element.src = texture;
      });
      images.set(texture, image);
    }
    return image;
  };

  const render = async (frame: RenderLayer[]) => {
    // Most cursors can use the resolved texture directly.
    const layer = frame[0]!;
    if (frame.length === 1 && !layer.offsetX && !layer.offsetY && !layer.flipX && !layer.flipY) {
      return `url("${layer.texture}"), auto`;
    }
    const textures = await Promise.all(frame.map((part) => loadImage(part.texture)));
    const left = Math.floor(Math.min(0, ...frame.map((part) => part.offsetX)));
    const top = Math.floor(Math.min(0, ...frame.map((part) => part.offsetY)));
    const right = Math.ceil(Math.max(1, ...frame.map((part, index) => part.offsetX + textures[index]!.naturalWidth)));
    const bottom = Math.ceil(Math.max(1, ...frame.map((part, index) => part.offsetY + textures[index]!.naturalHeight)));
    const canvas = document.createElement('canvas');
    canvas.width = right - left;
    canvas.height = bottom - top;
    const context = canvas.getContext('2d');
    if (!context) {
      throw new Error('Cursor canvas is unavailable');
    }
    frame.forEach((part, index) => {
      const image = textures[index]!;
      context.save();
      context.translate(
        part.offsetX - left + (part.flipX ? image.naturalWidth : 0),
        part.offsetY - top + (part.flipY ? image.naturalHeight : 0),
      );
      context.scale(part.flipX ? -1 : 1, part.flipY ? -1 : 1);
      context.drawImage(image, 0, 0);
      context.restore();
    });
    return `url("${canvas.toDataURL()}") ${-left} ${-top}, auto`;
  };

  watch(
    layers,
    (frame, _previous, onCleanup) => {
      let active = true;
      onCleanup(() => {
        active = false;
      });
      if (!frame.length) {
        cursor.value = undefined;
        return;
      }
      const key = JSON.stringify(frame);
      let result = rendered.get(key);
      if (!result) {
        result = render(frame);
        rendered.set(key, result);
      }
      void result
        .then((value) => {
          if (active) {
            cursor.value = value;
          }
        })
        .catch((error: unknown) => console.warn('[Selene cursor]', error));
    },
    { immediate: true },
  );

  return cursor;
};
