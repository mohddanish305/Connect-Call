export interface Env {
  SERVICE_NAME?: string;
  FIREBASE_PROJECT_ID?: string;
  AGORA_APP_ID?: string;
  AGORA_APP_CERTIFICATE?: string;
  AGORA_TOKEN_EXPIRY_SECONDS?: string;
  ENVIRONMENT?: string;
}

export interface VerifiedUser {
  uid: string;
  email?: string;
  name?: string;
  isTestToken?: boolean;
  [key: string]: unknown;
}

export interface Variables {
  user: VerifiedUser;
}
