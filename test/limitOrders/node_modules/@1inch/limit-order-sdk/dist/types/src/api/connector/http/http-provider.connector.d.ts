export type Headers = Record<string, string>;
export interface HttpProviderConnector {
    get<T>(url: string, headers: Headers): Promise<T>;
    post<T>(url: string, data: unknown, headers: Headers): Promise<T>;
}
