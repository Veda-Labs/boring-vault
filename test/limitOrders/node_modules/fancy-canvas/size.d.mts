export declare type Size = Readonly<{
    width: number;
    height: number;
}> & {
    __brand: 'Size';
};
export declare function size({ width, height }: {
    width: number;
    height: number;
}): Size;
export declare function equalSizes(first: {
    width: number;
    height: number;
}, second: {
    width: number;
    height: number;
}): boolean;
