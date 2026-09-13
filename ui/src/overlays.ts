import { inject, type Component, type InjectionKey } from 'vue';

export interface TooltipOptions {
  anchor: HTMLElement;
  title: string;
  description?: string;
  duration?: number;
  offset?: number;
}

export interface TooltipController {
  show(options: TooltipOptions): void;
  hide(): void;
}

export interface MenuOptions {
  label: string;
  anchor?: HTMLElement;
  position?: { x: number; y: number };
}

export interface MenuController {
  open<TResult = unknown>(
    component: Component,
    props: Record<string, unknown>,
    options: MenuOptions,
  ): Promise<TResult | undefined>;
  close(): void;
  isOpen(component?: Component): boolean;
}

export const tooltipControllerKey: InjectionKey<TooltipController> = Symbol('tooltip-controller');
export const menuControllerKey: InjectionKey<MenuController> = Symbol('menu-controller');

export const useTooltip = () => {
  const controller = inject(tooltipControllerKey);
  if (!controller) {
    throw new Error('Tooltip container was not provided.');
  }
  return controller;
};

export const useMenu = () => {
  const controller = inject(menuControllerKey);
  if (!controller) {
    throw new Error('Menu container was not provided.');
  }
  return controller;
};
