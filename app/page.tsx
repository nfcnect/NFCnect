import Loyalty from './loyalty';
import CardPortal from './card-portal';
export const dynamic='force-dynamic';
export default async function Page({searchParams}:{searchParams:Promise<Record<string,string|string[]|undefined>>}){
 const params=await searchParams;
 // A card URL always renders the isolated membership page. Invalid/empty card
 // values must never fall back to the business dashboard or another account.
 if(Object.prototype.hasOwnProperty.call(params,'card'))return <CardPortal token={typeof params.card==='string'?params.card:''}/>;
 return <Loyalty/>;
}
