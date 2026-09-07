// TODO deslop, this type info should be imported from a package instead of duplicated in UIs
import { inject, type InjectionKey } from 'vue';

export type ClientNetworkPayload = Record<string, unknown>;
export interface Coordinate { x: number; y: number; z: number }
export interface MapTile extends Coordinate { visualMetadata: Readonly<Record<string, unknown>> }
export interface SelenePointerEvent {
  clientX: number;
  clientY: number;
  button: number;
  shiftKey: boolean;
  coordinate: Coordinate;
}

export interface SeleneUiApi {
  readonly apiVersion: number;
  readonly resolveAsset: (path: string) => string;
  readonly visuals: {
    getDefinition(identifier: string): Promise<VisualDefinition>;
  };
  readonly storage: {
    load(key: string): Promise<string | null>;
    save(key: string, value: string): Promise<void>;
  };
  readonly input: {
    captureKeys(...keys: string[]): () => void;
    captureText(): () => void;
    passThroughKeys(...keys: string[]): () => void;
    isPassthroughKey(key: string): boolean;
    onPointerDown(callback: (event: SelenePointerEvent) => void): () => void;
    onPointerUp(callback: (event: SelenePointerEvent) => void): () => void;
  };
  readonly network: {
    sendToServer(payloadId: string, payload?: ClientNetworkPayload): void;
    onPayload(payloadId: string, callback: (payload: ClientNetworkPayload) => void): () => void;
  };
  readonly world: {
    getCameraCoordinate(): Coordinate;
    getMapTiles(): MapTile[];
    onCameraCoordinateChanged(callback: (coordinate: Coordinate) => void): () => void;
    onMapChanged(callback: () => void): () => void;
  };
}

export const seleneKey: InjectionKey<SeleneUiApi> = Symbol('selene-api');

export const useSelene = (): SeleneUiApi => {
  const selene = inject(seleneKey);
  if (!selene) throw new Error('Selene API was not provided.');
  return selene;
};

export interface VisualFrameDefinition {
  texture?: string;
  duration?: number;
  offsetX?: number;
  offsetY?: number;
  flipX?: boolean;
  flipY?: boolean;
}

export interface VisualDefinition extends VisualFrameDefinition {
  type?: string;
  textures?: string[];
  frames?: Array<string | VisualFrameDefinition>;
  animations?: Record<string, VisualFrameDefinition & { textures?: string[]; frames?: Array<string | VisualFrameDefinition> }>;
  layers?: VisualDefinition[];
  instanced?: boolean;
}
