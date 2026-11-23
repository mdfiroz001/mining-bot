import { createClient } from '@supabase/supabase-js';
import { createHmac, timingSafeEqual } from 'node:crypto';
import { z } from 'zod';

export const db = () => {
  const url=process.env.SUPABASE_URL, key=process.env.SUPABASE_SERVICE_ROLE_KEY;
  if(!url||!key) throw new Error('Server configuration incomplete: set Supabase server environment variables.');
  return createClient(url,key,{auth:{persistSession:false,autoRefreshToken:false}});
};
export const json=(res,status,payload)=>res.status(status).setHeader('Content-Type','application/json').setHeader('Cache-Control','no-store').json(payload);
export const method=(req,res,expected)=>{if(req.method!==expected){json(res,405,{error:'Method not allowed'});return false}return true};
export async function telegramUser(req){
 const raw=req.headers['x-telegram-init-data']; if(typeof raw!=='string'||!raw||!process.env.TELEGRAM_BOT_TOKEN)throw Object.assign(new Error('Open this app from Telegram to authenticate.'),{status:401});
 const q=new URLSearchParams(raw),hash=q.get('hash');if(!hash)throw Object.assign(new Error('Invalid Telegram authentication data.'),{status:401});q.delete('hash');
 const data=[...q.entries()].sort(([a],[b])=>a.localeCompare(b)).map(([k,v])=>`${k}=${v}`).join('\n');
 const secret=createHmac('sha256','WebAppData').update(process.env.TELEGRAM_BOT_TOKEN).digest();const expected=createHmac('sha256',secret).update(data).digest('hex');
 const a=Buffer.from(hash,'hex'),b=Buffer.from(expected,'hex');if(a.length!==b.length||!timingSafeEqual(a,b))throw Object.assign(new Error('Telegram authentication signature is invalid.'),{status:401});
 const authDate=Number(q.get('auth_date')||0);if(!authDate||Math.floor(Date.now()/1000)-authDate>86400||authDate>Math.floor(Date.now()/1000)+60)throw Object.assign(new Error('Telegram authentication data expired.'),{status:401});
 let user;try{user=JSON.parse(q.get('user')||'{}')}catch{throw Object.assign(new Error('Invalid Telegram user data.'),{status:401})};if(!Number.isSafeInteger(user.id))throw Object.assign(new Error('Telegram identity missing.'),{status:401});return user;
}
export async function profileFor(telegram){
 const client=db();const username=telegram.username||null;const adminIds=(process.env.ADMIN_TELEGRAM_IDS||'').split(',').map(x=>x.trim());const isAdmin=adminIds.includes(String(telegram.id));const {data,error}=await client.from('profiles').upsert({telegram_id:String(telegram.id),username,first_name:telegram.first_name||null,last_name:telegram.last_name||null,language_code:telegram.language_code||'en',...(isAdmin?{is_admin:true}:{}),last_seen_at:new Date().toISOString()},{onConflict:'telegram_id'}).select().single();if(error)throw error;return {...data,is_admin:data.is_admin||isAdmin};
}
export async function context(req){const t=await telegramUser(req);const profile=await profileFor(t);return {telegram:t,profile,db:db()}}
export async function requireAdmin(req){const c=await context(req);const ids=(process.env.ADMIN_TELEGRAM_IDS||'').split(',').map(x=>x.trim()).filter(Boolean);if(!ids.includes(String(c.telegram.id))&&!c.profile.is_admin)throw Object.assign(new Error('Admin access required.'),{status:403});return c}
export async function handleError(res,e){console.error('API error:',e);return json(res,e.status||500,{error:e.status?e.message:'Request could not be completed. Check server configuration and database migrations.'})}
export const safeId=z.string().uuid();
