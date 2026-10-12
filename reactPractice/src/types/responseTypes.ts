export interface UserDetails {
    id: string,
    name: string;
    email: string;
    roles: string[]
}

export interface AuthResponse {
    accessToken: string,
    userDetails: UserDetails | null;
}