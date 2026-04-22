import Disposable from './disposable.js';
import { BehaviorSubject } from './rx.js';
export declare function createObservable(win: Window): BehaviorSubject<number> & Disposable;
