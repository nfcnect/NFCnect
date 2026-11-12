export function parseMembershipLink(value,expectedOrigin){
 if(typeof value!=='string'||value.length>2000)throw Error('Enter a valid membership link.');
 let url;try{url=new URL(value)}catch{throw Error('Enter the complete membership URL.')}
 if(url.origin!==expectedOrigin||url.pathname!=='/'||url.searchParams.getAll('card').length!==1)throw Error('Use a membership card link from this NFCnect website.');
 const token=url.searchParams.get('card');if(!/^[a-f0-9]{64}$/.test(token||''))throw Error('This membership link has an invalid card identifier.');
 return token||'';
}
export function readMembershipRecord(records,expectedOrigin){
 const found=new Set();for(const record of records){if(!['url','absolute-url'].includes(record.recordType))continue;try{found.add(parseMembershipLink(new TextDecoder().decode(record.data),expectedOrigin))}catch{}}
 if(found.size!==1)throw Error(found.size?'This card contains multiple membership links. Ask the administrator to correct it.':'No valid NFCnect membership URL was found on this card.');return [...found][0];
}
