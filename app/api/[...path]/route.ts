import {env} from 'cloudflare:workers';
import {protectedRoute} from '../../../server/auth.mjs';
import {handle} from '../../../server/api.mjs';
export const dynamic='force-dynamic';
export async function GET(request:Request){return protectedRoute(request,env,(actor:{userId:string;email:string;displayName:string})=>handle(request,env,actor))}
export async function POST(request:Request){return protectedRoute(request,env,(actor:{userId:string;email:string;displayName:string})=>handle(request,env,actor))}
