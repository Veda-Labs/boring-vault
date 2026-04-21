import { Size } from "./size.mjs";
import { Binding as CanvasElementBitmapSizeBinding } from "./canvas-element-bitmap-size.mjs";
/**
 * @experimental
 */
export interface MediaCoordinatesRenderingScope {
    readonly context: CanvasRenderingContext2D;
    readonly mediaSize: Size;
}
/**
 * @experimental
 */
export interface BitmapCoordinatesRenderingScope {
    readonly context: CanvasRenderingContext2D;
    readonly mediaSize: Size;
    readonly bitmapSize: Size;
    readonly horizontalPixelRatio: number;
    readonly verticalPixelRatio: number;
}
/**
 * @experimental
 */
export declare class CanvasRenderingTarget2D {
    private readonly _context;
    private readonly _mediaSize;
    private readonly _bitmapSize;
    constructor(context: CanvasRenderingContext2D, mediaSize: Size, bitmapSize: Size);
    useMediaCoordinateSpace<T>(f: (scope: MediaCoordinatesRenderingScope) => T): T;
    useBitmapCoordinateSpace<T>(f: (scope: BitmapCoordinatesRenderingScope) => T): T;
    private get _horizontalPixelRatio();
    private get _verticalPixelRatio();
}
/**
 * @experimental
 */
export declare function createCanvasRenderingTarget2D(binding: CanvasElementBitmapSizeBinding, contextOptions?: CanvasRenderingContext2DSettings): CanvasRenderingTarget2D;
/**
 * @experimental
 */
export declare function tryCreateCanvasRenderingTarget2D(binding: CanvasElementBitmapSizeBinding, contextOptions?: CanvasRenderingContext2DSettings): CanvasRenderingTarget2D | null;
