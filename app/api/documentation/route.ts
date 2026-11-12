import {getChatGPTUser} from '../../chatgpt-auth';
import {configuration,verification} from '../../../server/documents.mjs';
export async function GET(request:Request){if(!await getChatGPTUser())return new Response('Sign in required.',{status:401});const v=new URL(request.url).searchParams.get('file')==='verification';return new Response(v?verification:configuration,{headers:{'Content-Type':'text/markdown; charset=utf-8','Content-Disposition':'attachment; filename="NFCnect-'+(v?'Verification':'Configuration')+'.md"','Cache-Control':'no-store'}})}
