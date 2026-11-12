// Reconstruct remaining credit batches from the immutable ledger. Expiration
// writes use a member-ledger version check in the same D1 transaction as spending.
export function replayPoints(events){
 const state={lots:[],debt:0,expired:new Map()};
 const sorted=()=>state.lots.filter(l=>l.remaining>0).sort((a,b)=>(a.expires_at||'9999').localeCompare(b.expires_at||'9999')||a.order-b.order);
 function spend(n,preferred){if(preferred){const lot=state.lots.find(l=>l.id===preferred);if(lot){const used=Math.min(n,lot.remaining);lot.remaining-=used;n-=used}}for(const l of sorted()){const used=Math.min(n,l.remaining);l.remaining-=used;n-=used;if(!n)break}state.debt+=n}
 for(const e of events){
  if(e.kind==='purchase'||e.kind==='cancellation'){
   let n=e.delta;if(n<0)throw Error('Invalid points credit.');const paid=Math.min(n,state.debt);state.debt-=paid;n-=paid;
   state.lots.push({id:e.kind+':'+e.source_id,purchase_id:e.kind==='purchase'?e.source_id:null,remaining:n,earned_at:e.credit_created||e.created_at,expires_at:e.validity_days===null||e.validity_days===undefined?null:new Date(new Date(e.credit_created||e.created_at).getTime()+e.validity_days*86400000).toISOString(),order:e.version});
  }else if(e.kind==='expiration'){
   for(const item of JSON.parse(e.expiry_details||'[]')){const lot=state.lots.find(l=>l.id===item.id);if(!lot||item.points>lot.remaining||item.points<0)throw Error('Points expiration reconciliation failed.');lot.remaining-=item.points;if(lot.purchase_id)state.expired.set(lot.purchase_id,(state.expired.get(lot.purchase_id)||0)+item.points)}
  }else if(e.kind==='refund'){
   const offset=e.refund_offset||0;state.expired.set(e.purchase_id,Math.max(0,(state.expired.get(e.purchase_id)||0)-offset));spend(Math.max(0,-e.delta-offset),'purchase:'+e.purchase_id);
  }else if(e.kind==='expired_refund_offset'){
   // Already applied with its linked refund above; it is not a new earned lot.
  }else if(e.delta<0)spend(-e.delta);else if(e.delta!==0)throw Error('Unrecognized points ledger credit.');
 }
 return state;
}
export function expiringBatches(state,asOf){return state.lots.filter(l=>l.remaining>0&&l.expires_at&&l.expires_at<=asOf).map(l=>({id:l.id,points:l.remaining}))}
export function applyExpiration(state,details){for(const x of details){const l=state.lots.find(l=>l.id===x.id);l.remaining-=x.points;if(l.purchase_id)state.expired.set(l.purchase_id,(state.expired.get(l.purchase_id)||0)+x.points)}}
export function validitySummary(state){const batches=state.lots.filter(l=>l.remaining>0).sort((a,b)=>(a.expires_at||'9999').localeCompare(b.expires_at||'9999')||a.order-b.order).map(l=>({points:l.remaining,earned_at:l.earned_at,expires_at:l.expires_at}));const next=batches.find(l=>l.expires_at)?.expires_at||null;return {batches,next_expiry:next,expiring_points:next?batches.filter(l=>l.expires_at===next).reduce((s,l)=>s+l.points,0):0,no_expiry_points:batches.filter(l=>!l.expires_at).reduce((s,l)=>s+l.points,0)}}
export function pointEngine(db){
 const q=(sql,...v)=>db.prepare(sql).bind(...v);
 async function snapshot(id,b,asOf){const {results}=await q(`SELECT l.*,l.rowid AS version,p.validity_days AS purchase_validity,p.created_at AS purchase_created,c.validity_days AS cancellation_validity,c.created_at AS cancellation_created,f.purchase_id,ch.details AS expiry_details,COALESCE((SELECT delta FROM ledger o WHERE o.kind='expired_refund_offset' AND o.source_id=f.id AND o.business_id=l.business_id),0) AS refund_offset FROM ledger l LEFT JOIN purchases p ON l.kind='purchase' AND p.id=l.source_id LEFT JOIN cancellations c ON l.kind='cancellation' AND c.id=l.source_id LEFT JOIN refunds f ON l.kind='refund' AND f.id=l.source_id LEFT JOIN point_checks ch ON l.kind='expiration' AND ch.id=l.source_id WHERE l.membership_id=? AND l.business_id=? ORDER BY l.rowid`,id,b).all();const events=results.map(e=>({...e,validity_days:e.kind==='purchase'?e.purchase_validity:e.cancellation_validity,credit_created:e.kind==='purchase'?e.purchase_created:e.cancellation_created}));const state=replayPoints(events);if(state.lots.reduce((n,l)=>n+l.remaining,0)-state.debt!==events.reduce((n,e)=>n+e.delta,0))throw Error('Points ledger requires reconciliation.');const details=expiringBatches(state,asOf);applyExpiration(state,details);return {state,details,version:events.at(-1)?.version||0}}
 async function transact(id,b,build,asOf=new Date().toISOString()){
  for(let attempt=0;attempt<4;attempt++){
   const s=await snapshot(id,b,asOf),check=q('INSERT INTO point_checks(id,business_id,membership_id,expected_version,expired_points,details,as_of) VALUES(?,?,?,?,?,?,?)',crypto.randomUUID(),b,id,s.version,s.details.reduce((n,x)=>n+x.points,0),JSON.stringify(s.details),asOf);
   try{return await db.batch([check,...await build(s.state)])}catch(e){if(String(e).includes('points_changed')&&attempt<3)continue;throw e}
  }
 }
 async function settle(id,b,asOf=new Date().toISOString()){
  const s=await snapshot(id,b,asOf);if(s.details.length)await transact(id,b,async()=>[],asOf);const current=await snapshot(id,b,asOf);return validitySummary(current.state);
 }
 return {transact,settle,snapshot};
}
