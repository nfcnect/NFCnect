interface CloudflareEnv {
 DB: D1Database;
 SITE_ORIGIN: string;
 SUPABASE_URL: string;
 SUPABASE_PUBLISHABLE_KEY: string;
 BOOTSTRAP_ADMIN_EMAIL: string;
}
declare namespace Cloudflare { interface Env extends CloudflareEnv {} }
