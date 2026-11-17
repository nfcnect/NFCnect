import {env} from 'cloudflare:workers';
import {authAction} from '../../../server/auth.mjs';
export const dynamic='force-dynamic';
export async function POST(request:Request){return authAction(request,env)}
