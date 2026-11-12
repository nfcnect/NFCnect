// Integration test of the request handler against Miniflare D1.
// Identities are test harness inputs, never a shipped login bypass.
import assert from 'node:assert/strict';
import {Miniflare} from 'miniflare';
import {readFileSync,readdirSync} from 'node:fs';
import {handle} from '../server/api.mjs';
const mf=new Miniflare({modules:true,script:'export default {fetch(){return new Response("Test worker")}}',d1Databases:['DB']});
const db=await mf.getD1Database('DB');
for(const name of readdirSync(new URL('../drizzle/',import.meta.url)).filter(n=>n.endsWith('.sql')).sort()){for(const stmt of readFileSync(new URL('../drizzle/'+name,import.meta.url),'utf8').split('--> statement-breakpoint').map(x=>x.trim()).filter(Boolean)){await db.prepare(stmt).run()}}
const env={DB:db,SITE_ORIGIN:'http://127.0.0.1:4173',BOOTSTRAP_ADMIN_EMAIL:'owner@example.com'};
const origin='http://127.0.0.1:4173';
const owner={id:'runtime-owner',email:'owner@example.com'},alice={id:'runtime-alice',email:'alice-runtime@example.com'},bob={id:'runtime-bob',email:'bob-runtime@example.com'};
async function call(actor,path,body,key=crypto.randomUUID()){const r=await handle(new Request(origin+'/api/'+path,{method:body?'POST':'GET',headers:body?{'Origin':origin,'Content-Type':'application/json','Idempotency-Key':key}:{},body:body?JSON.stringify(body):undefined}),env,actor?{userId:actor.id,email:actor.email,displayName:actor.id}:null);return {status:r.status,data:await r.json()}}
try{
assert.equal((await call(null,'me')).status,401);
let me=await call(owner,'me');assert.equal(me.status,200,JSON.stringify(me));if(!me.data.setupExists)assert.equal((await call(owner,'setup',{name:'LOCAL TEST ONLY'})).status,200);
const b='nfcnect-pilot',enroll=await call(owner,'enroll',{business_id:b,name:'Local runtime test',email:alice.email});assert.equal(enroll.status,200,JSON.stringify(enroll));const m=enroll.data.membership_id,card=new URL(enroll.data.card_url).searchParams.get('card'),invite=new URL(enroll.data.claim_url).searchParams.get('claim');
assert.equal((await call(bob,'claim',{token:invite})).status,404);assert.equal((await call(alice,'claim',{token:invite})).status,200);assert.equal((await call(bob,'member?card='+card)).status,404);
const purchase={business_id:b,membership_id:m,receipt:'LOCAL-'+crypto.randomUUID(),amount_centavos:100000,paid:true},key=crypto.randomUUID();
const credits=await Promise.all([call(owner,'purchase',purchase,key),call(owner,'purchase',purchase,key)]);assert.ok(credits.every(x=>x.status===200),JSON.stringify(credits));assert.equal(credits[0].data.id,credits[1].data.id);assert.equal((await call(alice,'member?card='+card)).data.membership.balance,20);
const workspace=(await call(owner,'workspace?business='+b)).data,reward=workspace.rewards.find(r=>r.points===20);
const r1=(await call(alice,'request',{business_id:b,membership_id:m,reward_id:reward.id})).data.id,r2=(await call(alice,'request',{business_id:b,membership_id:m,reward_id:reward.id})).data.id;
const results=await Promise.all([call(owner,'redeem',{business_id:b,request_id:r1,basket_centavos:10000,confirmed:true}),call(owner,'redeem',{business_id:b,request_id:r2,basket_centavos:10000,confirmed:true})]);assert.deepEqual(results.map(r=>r.status).sort(),[200,409],JSON.stringify(results));assert.equal((await call(alice,'member?card='+card)).data.membership.balance,0);
const refund={business_id:b,purchase_id:credits[0].data.id,amount_centavos:100000,reason:'LOCAL TEST full reversal'},fk=crypto.randomUUID();assert.equal((await call(owner,'refund',refund,fk)).status,200);assert.equal((await call(owner,'refund',refund,fk)).status,200);assert.equal((await call(alice,'member?card='+card)).data.membership.balance,-20);
assert.equal((await call(owner,'card',{business_id:b,membership_id:m,reason:'LOCAL TEST replacement'})).status,200);assert.equal((await call(alice,'member?card='+card)).status,404);
const before=(await db.prepare('SELECT * FROM ledger WHERE membership_id=? ORDER BY id').bind(m).all()).results;
assert.equal((await call(owner,'anonymize',{business_id:b,membership_id:m,confirmation:'ANONYMIZE',verified:true})).status,200);
assert.equal((await call(alice,'member?id='+m)).status,404);
assert.equal((await db.prepare('SELECT display_name FROM memberships WHERE id=?').bind(m).first()).display_name,'Anonymized member');
assert.deepEqual((await db.prepare('SELECT * FROM ledger WHERE membership_id=? ORDER BY id').bind(m).all()).results,before);
assert.equal((await db.prepare('SELECT COUNT(*) n FROM invitations WHERE membership_id=?').bind(m).first()).n,0);
assert.equal((await call(owner,'validity',{business_id:b,validity_days:1})).status,200);
const expEnrollment=(await call(owner,'enroll',{business_id:b,name:'Expiry runtime test',email:bob.email})).data;
assert.equal((await call(bob,'claim',{token:new URL(expEnrollment.claim_url).searchParams.get('claim')})).status,200);
const expiryMember=expEnrollment.membership_id,purchaseId=crypto.randomUUID(),policy=await db.prepare('SELECT * FROM businesses WHERE id=?').bind(b).first();
await db.prepare('INSERT INTO purchases(id,business_id,membership_id,receipt,amount_centavos,step_centavos,rule_version,points,validity_days,actor_id,idempotency_key,payload_hash,created_at) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?)').bind(purchaseId,b,expiryMember,'EXPIRE-'+crypto.randomUUID(),100000,5000,policy.rule_version,20,1,owner.id,crypto.randomUUID(),'test',new Date(Date.now()-2*86400000).toISOString()).run();
assert.equal((await call(bob,'member?id='+expiryMember)).data.membership.balance,0);
assert.equal((await call(bob,'member?id='+expiryMember)).data.membership.balance,0);
assert.equal((await db.prepare("SELECT COUNT(*) n FROM ledger WHERE membership_id=? AND kind='expiration'").bind(expiryMember).first()).n,1);
assert.equal((await call(owner,'refund',{business_id:b,purchase_id:purchaseId,amount_centavos:100000,reason:'Expired purchase refund'})).status,200);
assert.equal((await call(bob,'member?id='+expiryMember)).data.membership.balance,0);
const hybrid=(await call(owner,'enroll',{business_id:b,name:'Hybrid runtime',email:alice.email})).data;
assert.equal((await call(alice,'claim',{token:new URL(hybrid.claim_url).searchParams.get('claim')})).status,200);
const hybridCard=new URL(hybrid.card_url).searchParams.get('card'),hybridReceipt='HYBRID-'+crypto.randomUUID(),hybridPaid={business_id:b,membership_id:hybrid.membership_id,entry_method:'nfc',card_token:hybridCard,receipt:hybridReceipt,amount_centavos:15000,paid:true};
assert.equal((await call(owner,'member?card='+hybridCard)).data.membership.balance,0);
assert.equal((await call(owner,'purchase',hybridPaid)).status,200);
assert.equal((await call(owner,'purchase',{...hybridPaid,entry_method:'receipt',card_token:undefined,backup_reason:'reader_unavailable'})).status,409);
await call(owner,'card',{business_id:b,membership_id:hybrid.membership_id,reason:'Runtime replacement'});
assert.equal((await call(owner,'purchase',{...hybridPaid,receipt:hybridReceipt+'-OLD'})).status,409);
assert.equal((await call(owner,'purchase',{...hybridPaid,entry_method:'receipt',card_token:undefined,backup_reason:'forgot_card',receipt:hybridReceipt+'-BACKUP'})).status,200);
assert.equal((await call(alice,'member?id='+hybrid.membership_id)).data.membership.balance,6);
console.log('PASS: request handler + Miniflare D1: authenticated scope, email claims, concurrent purchase retry, competing redemptions, refund retry, negative balance, revoked card and atomic profile anonymization, points expiry and expired-refund offsets and hybrid-entry duplicate protection.');

}finally{await mf.dispose()}
