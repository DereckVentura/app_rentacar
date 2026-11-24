declare namespace Cloudflare {
  interface Env {
    DB?: D1Database;
    BUCKET?: R2Bucket;
    AUTH_SECRET: string;
    UPLOAD_SECRET: string;
    OPENAI_API_KEY?: string;
    ADMIN_BOOTSTRAP_EMAIL?: string;
    ADMIN_BOOTSTRAP_PASSWORD_HASH?: string;
  }
}
