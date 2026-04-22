import Disposable from "./disposable.mjs";
import { BehaviorSubject } from "./rx.mjs";
export declare function createObservable(win: Window): BehaviorSubject<number> & Disposable;
