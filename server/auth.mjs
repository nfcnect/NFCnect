// Independent hosting boundary. Never trust identity headers, JSON roles, or an
// unverified JWT payload. Supabase /user verifies each access token remotely.
export class AuthError extends Error { constructor(status,message){super(message);this.status=status;} }
const error=(status,message)=>{throw new AuthError(status,message);};
const noStore={'Cache-Control':'no-store, private','Referrer-Policy':'no-referrer','X-Content-Type-Options':'nosniff','Vary':'Cookie'};
export function siteOrigin(env){
 let u;try{u=new URL(env.SITE_ORIGIN);}catch{error(503,'The site address is not configured.');}
 if(u.username||u.password||u.pathname!=='/'||u.search||u.hash||!(u.protocol==='https:'||u.protocol==='http:'&&['localhost','127.0.0.1','[::1]'].includes(u.hostname)))error(503,'The site address is not configured.');
 return u.origin;
}
export {safeReturn} from '../lib/auth-return.mjs';
import {safeReturn} from '../lib/auth-return.mjs';
function settings(env){let u;try{u=new URL(env.SUPABASE_URL);}catch{error(503,'Sign-in is not configured.');}if(u.protocol!=='https:'||u.username||u.password||u.pathname!=='/'||u.search||u.hash||!env.SUPABASE_PUBLISHABLE_KEY)error(503,'Sign-in is not configured.');return {base:u.origin+'/auth/v1',key:env.SUPABASE_PUBLISHABLE_KEY};}
async function provider(env,path,{body,access,method=body?'POST':'GET'}={}){
 const {base,key}=settings(env);let r;try{r=await fetch(base+path,{method,headers:{apikey:key,...(access?{Authorization:'Bearer '+access}:{}),...(body?{'Content-Type':'application/json'}:{})},body:body?JSON.stringify(body):undefined,signal:AbortSignal.timeout(10000),redirect:'error'});}catch{error(503,'Sign-in is temporarily unavailable.');}
 let data;try{data=await r.json();}catch{data={};}if(r.status>=500)error(503,'Sign-in is temporarily unavailable.');return {ok:r.ok,status:r.status,data};
}
function readCookies(request){const result={};for(const part of (request.headers.get('cookie')||'').split(';')){const i=part.indexOf('=');if(i>0){const k=part.slice(0,i).trim();if(k==='nfcnect_access'||k==='nfcnect_refresh')try{result[k]=decodeURIComponent(part.slice(i+1));}catch{}}}return result;}
function cookie(name,value,age,origin){return name+'='+encodeURIComponent(value)+'; Path=/; HttpOnly; SameSite=Lax; Max-Age='+age+(origin.startsWith('https:')?'; Secure':'');}
function sessionCookies(session,origin){if(!session?.access_token||!session?.refresh_token)error(401,'Sign in again to continue.');return [cookie('nfcnect_access',session.access_token,3600,origin),cookie('nfcnect_refresh',session.refresh_token,2592000,origin)];}
export function clearCookies(env){const origin=siteOrigin(env);return ['nfcnect_access','nfcnect_refresh'].map(n=>cookie(n,'',0,origin));}
function verifiedUser(user){return user&&/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(user.id)&&typeof user.email==='string'&&user.email_confirmed_at&&!user.is_anonymous;}
export async function authenticate(request,env){
 const origin=siteOrigin(env),cookies=readCookies(request);let access=cookies.nfcnect_access,changed=[];
 let result=access?await provider(env,'/user',{access}):null;
 if(!result?.ok&&cookies.nfcnect_refresh){
  const refreshed=await provider(env,'/token?grant_type=refresh_token',{body:{refresh_token:cookies.nfcnect_refresh}});
  if(refreshed.ok){access=refreshed.data.access_token;changed=sessionCookies(refreshed.data,origin);result=await provider(env,'/user',{access});}
 }
 if(!result?.ok||!verifiedUser(result.data))error(401,'Sign in with a confirmed email to continue.');
 const user=result.data;let userId='supabase:'+user.id;
 // Legacy mappings are installed by an operator after ownership verification.
 // Emails/metadata supplied by the browser can never create a mapping.
 if(!env.DB)error(503,'Database is not configured.');
 const link=await env.DB.prepare('SELECT actor_id FROM identity_links WHERE supabase_user_id=?').bind(user.id).first();
 if(link)userId=link.actor_id;
 return {actor:{userId,email:user.email.toLowerCase(),displayName:user.email,authSubject:user.id},cookies:changed,access};
}
export function withCookies(response,cookies=[]){const out=new Response(response.body,response);for(const c of cookies)out.headers.append('Set-Cookie',c);return out;}
export function authFailure(e){return new Response(JSON.stringify({error:e.status?e.message:'Sign-in could not be completed.'}),{status:e.status||500,headers:{...noStore,'Content-Type':'application/json'}});}
export async function protectedRoute(request,env,handler){try{const session=await authenticate(request,env);return withCookies(await handler(session.actor),session.cookies);}catch(e){return authFailure(e);}}
async function limit(request,env){if(!env.DB)error(503,'Database is not configured.');const minute=Math.floor(Date.now()/60000),ip=request.headers.get('cf-connecting-ip')||'local';const bytes=await crypto.subtle.digest('SHA-256',new TextEncoder().encode('auth:'+ip+':'+minute));const key=Array.from(new Uint8Array(bytes),n=>n.toString(16).padStart(2,'0')).join('');const row=await env.DB.prepare('INSERT INTO rate_limits(key,count,expires) VALUES(?,1,?) ON CONFLICT(key) DO UPDATE SET count=count+1 RETURNING count').bind(key,minute*60+120).first();if(row.count>20)error(429,'Too many sign-in attempts. Try again in one minute.');}
export async function authAction(request,env){
 try{
  const origin=siteOrigin(env);if(request.method!=='POST')error(405,'Use POST.');if(request.headers.get('origin')!==origin||request.headers.get('sec-fetch-site')==='cross-site')error(403,'Request origin rejected.');
  if(!request.headers.get('content-type')?.startsWith('application/json'))error(415,'JSON required.');const raw=await request.text();if(raw.length>12000)error(413,'Request too large.');let input;try{input=JSON.parse(raw);}catch{error(400,'Invalid request.');}if(!input||typeof input!=='object'||Array.isArray(input))error(400,'Invalid request.');
  await limit(request,env);const action=input.action;let message='',cookies=[],next=safeReturn(input.next);
  if(action==='signin'||action==='signup'||action==='recover'){
   const email=typeof input.email==='string'?input.email.trim().toLowerCase():'';if(email.length>254||!/^\S+@\S+\.\S+$/.test(email))error(400,'Enter a valid email.');
   if(action!=='recover'&&(typeof input.password!=='string'||input.password.length>256||input.password.length<(action==='signup'?12:1)))error(400,action==='signup'?'Use at least 12 characters for your password.':'Enter your password.');
   if(action==='signin'){const r=await provider(env,'/token?grant_type=password',{body:{email,password:input.password}});if(!r.ok||!verifiedUser(r.data.user))error(401,'Sign-in failed. Check your email, password, and email confirmation.');cookies=sessionCookies(r.data,origin);}
   if(action==='signup'){const r=await provider(env,'/signup',{body:{email,password:input.password}});if(!r.ok)error(r.status===429?429:400,'Registration could not be completed. Try again or sign in if you already have an account.');message='Check your email to confirm your account, then sign in.';next='/auth?mode=signin';}
   if(action==='recover'){await provider(env,'/recover',{body:{email}});message='If the account can receive a reset email, a link has been sent.';next=null;}
  }else if(action==='confirm'){
   if(!['email','recovery'].includes(input.type)||typeof input.token_hash!=='string'||!/^[A-Za-z0-9_-]{20,256}$/.test(input.token_hash))error(400,'This confirmation link is invalid.');
   const r=await provider(env,'/verify',{body:{token_hash:input.token_hash,type:input.type}});if(!r.ok||!verifiedUser(r.data.user))error(400,'This confirmation link is invalid or expired. Request a new one.');cookies=sessionCookies(r.data,origin);next=input.type==='recovery'?'/auth?mode=reset':'/';
  }else if(action==='password'){
   if(typeof input.password!=='string'||input.password.length<12||input.password.length>256)error(400,'Use at least 12 characters for your password.');const session=await authenticate(request,env);const r=await provider(env,'/user',{method:'PUT',access:session.access,body:{password:input.password}});if(!r.ok)error(400,'The password could not be updated. Request a fresh reset link.');cookies=session.cookies;message='Password updated.';next='/';
  }else if(action==='signout'){
   const access=readCookies(request).nfcnect_access;if(access)try{await provider(env,'/logout',{method:'POST',access});}catch{}cookies=clearCookies(env);next='/auth?mode=signin';
  }else error(400,'Invalid account action.');
  return withCookies(new Response(JSON.stringify({ok:true,message,next}),{headers:{...noStore,'Content-Type':'application/json'}}),cookies);
 }catch(e){return authFailure(e);}
}
