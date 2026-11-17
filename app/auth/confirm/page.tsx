import AccountForm from '../account-form';
export const dynamic='force-dynamic';
export default async function Confirm({searchParams}:{searchParams:Promise<Record<string,string|string[]|undefined>>}){const p=await searchParams;return <AccountForm mode="confirm" tokenHash={typeof p.token_hash==='string'?p.token_hash:''} tokenType={typeof p.type==='string'?p.type:''} />}
