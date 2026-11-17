import {env} from 'cloudflare:workers';
import {protectedRoute} from '../../../server/auth.mjs';
import {configuration,verification} from '../../../server/documents.mjs';
export const dynamic='force-dynamic';
export async function GET(request:Request){return protectedRoute(request,env,async()=>{const v=new URL(request.url).searchParams.get('file')==='verification';return new Response(v?verification:configuration,{headers:{'Content-Type':'text/markdown; charset=utf-8','Content-Disposition':'attachment; filename="NFCnect-'+(v?'Verification':'Configuration')+'.md"','Cache-Control':'no-store'}})})}
