import { env } from 'cloudflare:workers';
import { getChatGPTUser } from '../../chatgpt-auth';
import { handle } from '../../../server/api.mjs';
export const dynamic='force-dynamic';
export async function GET(request:Request){return handle(request,env,await getChatGPTUser())}
export async function POST(request:Request){return handle(request,env,await getChatGPTUser())}
