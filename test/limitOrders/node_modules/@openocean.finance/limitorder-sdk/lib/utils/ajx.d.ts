export declare function validateReq<T extends object>(option: T, vo?: any): Promise<string | undefined>;
export declare function get<T extends object, V>(url: string, option: T, vo?: V): Promise<any>;
export declare function post<T extends object, V>(url: string, option: T, vo?: V): Promise<any>;
