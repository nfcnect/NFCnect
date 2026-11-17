import AccountForm from './account-form';
export const dynamic='force-dynamic';
export default async function Auth({searchParams}:{searchParams:Promise<Record<string,string|string[]|undefined>>}){const p=await searchParams;return <AccountForm mode={typeof p.mode==='string'?p.mode:'signin'} next={typeof p.next==='string'?p.next:'/'} />}
