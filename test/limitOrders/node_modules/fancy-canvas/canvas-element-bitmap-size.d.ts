import Disposable from './disposable.js';
import { Size } from './size.js';
export declare type BitmapSizeChangedListener = (this: Binding, oldSize: Size, newSize: Size) => void;
export declare type BitmapSizeTransformer = (bitmapSize: Size, canvasElementClientSize: Size) => {
    width: number;
    height: number;
};
export declare type SuggestedBitmapSizeChangedListener = (this: Binding, oldSize: Size | null, newSize: Size | null) => void;
export interface Binding extends Disposable {
    readonly canvasElement: HTMLCanvasElement;
    /**
     * Canvas element client size in CSS pixels
     */
    readonly canvasElementClientSize: Size;
    resizeCanvasElement(clientSize: {
        width: number;
        height: number;
    }): void;
    readonly bitmapSize: Size;
    subscribeBitmapSizeChanged(listener: BitmapSizeChangedListener): void;
    unsubscribeBitmapSizeChanged(listener: BitmapSizeChangedListener): void;
    readonly suggestedBitmapSize: Size | null;
    subscribeSuggestedBitmapSizeChanged(listener: SuggestedBitmapSizeChangedListener): void;
    unsubscribeSuggestedBitmapSizeChanged(listener: SuggestedBitmapSizeChangedListener): void;
    applySuggestedBitmapSize(): void;
}
export interface DevicePixelContentBoxBindingTargetOptions {
    allowResizeObserver?: boolean;
}
export declare type BindingTarget = {
    type: 'device-pixel-content-box';
    transform?: BitmapSizeTransformer;
    options?: DevicePixelContentBoxBindingTargetOptions;
};
export declare function bindTo(canvasElement: HTMLCanvasElement, target: BindingTarget): Binding;
