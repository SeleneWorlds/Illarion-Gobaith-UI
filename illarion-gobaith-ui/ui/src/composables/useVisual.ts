import { onUnmounted, ref, toValue, watch, type MaybeRefOrGetter } from 'vue';
import { resolveClientAsset } from '../clientAssets';
import { useSelene, type VisualDefinition, type VisualFrameDefinition } from '../selene';

export interface RenderLayer {
  texture: string;
  offsetX: number;
  offsetY: number;
  flipX: boolean;
  flipY: boolean;
}

export const useVisual = (
  identifier: MaybeRefOrGetter<string | undefined>,
  seed: MaybeRefOrGetter<string> = '',
  withoutOffset: MaybeRefOrGetter<boolean> = false,
  animation: MaybeRefOrGetter<string | undefined> = undefined,
) => {
  const selene = useSelene();

  const layers = ref<RenderLayer[]>([]);
  let generation = 0;
  let animationFrame = 0;
  let animationStarted = 0;
  let animationDuration = 0;
  let frames: RenderLayer[][] = [];
  let frameRequest: number | undefined;

  const hash = (value: string) => {
    let result = 0;
    for (let index = 0; index < value.length; index++) {
      result = (Math.imul(31, result) + value.charCodeAt(index)) | 0;
    }
    return Math.abs(result);
  };
  const asFrame = (frame: string | VisualFrameDefinition, parent: VisualDefinition): VisualFrameDefinition =>
    typeof frame === 'string' ? { ...parent, texture: frame } : { ...parent, ...frame };
  const makeLayer = async (frame: VisualFrameDefinition): Promise<RenderLayer | undefined> =>
    frame.texture
      ? {
          texture: await resolveClientAsset(selene, frame.texture),
          offsetX: toValue(withoutOffset) ? 0 : (frame.offsetX ?? 0),
          offsetY: toValue(withoutOffset) ? 0 : (frame.offsetY ?? 0),
          flipX: frame.flipX ?? false,
          flipY: frame.flipY ?? false,
        }
      : undefined;
  const selectedAnimation = (definition: VisualDefinition) => {
    const name = toValue(animation);
    return (name ? definition.animations?.[name] : undefined) ?? Object.values(definition.animations ?? {})[0];
  };
  const definitionFrames = (definition: VisualDefinition): VisualFrameDefinition[] => {
    if (definition.frames?.length) {
      return definition.frames.map((frame) => asFrame(frame, definition));
    }
    if (definition.type === 'variants' && definition.textures?.length) {
      return [
        asFrame(
          definition.textures[hash(toValue(seed) || toValue(identifier) || '') % definition.textures.length],
          definition,
        ),
      ];
    }
    if (definition.textures?.length) {
      return definition.textures.map((texture) => asFrame(texture, definition));
    }
    if (definition.texture) {
      return [definition];
    }
    const animation = selectedAnimation(definition);
    if (animation?.frames?.length) {
      return animation.frames.map((frame) => asFrame(frame, { ...definition, ...animation }));
    }
    return animation?.textures?.map((texture) => asFrame(texture, { ...definition, ...animation })) ?? [];
  };
  const stop = () => {
    if (frameRequest !== undefined) {
      cancelAnimationFrame(frameRequest);
    }
    frameRequest = undefined;
  };
  const tick = (now: number) => {
    if (frames.length < 2) {
      return;
    }
    const index = Math.floor((now - animationStarted) / ((animationDuration * 1000) / frames.length)) % frames.length;
    if (index !== animationFrame) {
      animationFrame = index;
      layers.value = frames[index];
    }
    frameRequest = requestAnimationFrame(tick);
  };
  const load = async () => {
    const current = ++generation;
    stop();
    layers.value = [];
    if (!toValue(identifier)) {
      return;
    }
    try {
      const visualIdentifier = toValue(identifier);
      if (!visualIdentifier) {
        return;
      }
      const definition = await selene.visuals.getDefinition(visualIdentifier);
      const definitions = definition.layers?.length ? definition.layers : [definition];
      const layerFrames = await Promise.all(
        definitions.map(async (part) => {
          const result = await Promise.all(definitionFrames(part).map(makeLayer));
          return result.filter((layer): layer is RenderLayer => Boolean(layer));
        }),
      );
      const count = Math.max(0, ...layerFrames.map((value) => value.length));
      const loadedFrames = Array.from({ length: count }, (_, index) =>
        layerFrames.flatMap((value) => value[index % value.length] ?? []),
      );
      if (current !== generation) {
        return;
      }
      frames = loadedFrames;
      animationDuration = definition.duration ?? selectedAnimation(definition)?.duration ?? 1;
      animationStarted = performance.now();
      animationFrame = 0;
      layers.value = frames[0] ?? [];
      if (frames.length > 1) {
        frameRequest = requestAnimationFrame(tick);
      }
    } catch (error) {
      console.warn('[Selene visual]', toValue(identifier), error);
    }
  };
  watch(
    () => [toValue(identifier), toValue(seed), toValue(withoutOffset), toValue(animation)],
    () => void load(),
    { immediate: true },
  );
  onUnmounted(() => {
    generation++;
    stop();
  });

  return layers;
};
