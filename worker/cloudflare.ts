import handler from 'vinext/server/fetch-handler';
export default {async fetch(request:Request,env:Cloudflare.Env,ctx:ExecutionContext){const response=await handler.fetch(request,env,ctx);const out=new Response(response.body,response);out.headers.set('Referrer-Policy','no-referrer');out.headers.set('X-Content-Type-Options','nosniff');return out;}};
