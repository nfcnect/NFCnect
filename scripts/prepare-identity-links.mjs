// Run locally against an operator-reviewed manifest. No account auto-link by email.
import {readFileSync,writeFileSync} from 'node:fs';
const [input,output]=process.argv.slice(2);
if(!input||!output)throw Error('Usage: node scripts/prepare-identity-links.mjs reviewed-manifest.json output.sql');
const rows=JSON.parse(readFileSync(input,'utf8'));if(!Array.isArray(rows)||!rows.length)throw Error('Provide a nonempty reviewed manifest.');
const quote=s=>"'"+s.replaceAll("'","''")+"'";
const ids=new Set(),actors=new Set();const statements=[];
for(const row of rows){const {supabase_user_id,actor_id,verified_email,verification_reference,ownership_verified,email_confirmed}=row;if(ownership_verified!==true||email_confirmed!==true||!/^([a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})$/i.test(supabase_user_id)||typeof actor_id!=='string'||!actor_id||actor_id.startsWith('supabase:')||typeof verified_email!=='string'||!/^\S+@\S+\.\S+$/.test(verified_email)||typeof verification_reference!=='string'||verification_reference.length<3||verification_reference.length>300)throw Error('Every mapping needs a confirmed Supabase subject, legacy actor, and independent ownership-verification reference.');if(ids.has(supabase_user_id)||actors.has(actor_id))throw Error('Duplicate mapping.');ids.add(supabase_user_id);actors.add(actor_id);statements.push('INSERT INTO identity_links(supabase_user_id,actor_id,verified_email,verification_reference) VALUES('+[supabase_user_id,actor_id,verified_email.toLowerCase(),verification_reference].map(quote).join(',')+');');}
writeFileSync(output,statements.join('\n')+'\n',{mode:0o600});console.log('Prepared '+rows.length+' reviewed mappings. Apply only to the correct imported database; keep the manifest and SQL private.');
