import { context,handleError,json,method } from './_lib/core.js';
export default async function handler(req,res){if(!method(req,res,'GET'))return;try{const {db,profile}=await context(req);const [{data:wallet},{data:tx},{data:tasks},{data:plan},{data:session},{data:settings},{count:refCount}] = await Promise.all([
 db.from('wallets').select('available_balance,pending_balance,lifetime_earnings').eq('profile_id',profile.id).maybeSingle(),
 db.from('wallet_transactions').select('id,transaction_type,amount,created_at').eq('profile_id',profile.id).order('created_at',{ascending:false}).limit(8),
 db.from('task_submissions').select('id',{count:'exact',head:true}).eq('profile_id',profile.id).eq('status','approved'),
 db.from('user_plans').select('plans(name)').eq('profile_id',profile.id).eq('status','active').maybeSingle(),
 db.from('mining_sessions').select('id,ends_at,claimed_at,earned_amount').eq('profile_id',profile.id).is('claimed_at',null).order('started_at',{ascending:false}).limit(1).maybeSingle(),
 db.from('app_settings').select('key,value'), db.from('referrals').select('id',{count:'exact',head:true}).eq('referrer_profile_id',profile.id)
 ]);
 const cfg=Object.fromEntries((settings||[]).map(x=>[x.key,x.value]));const start=new Date();start.setHours(0,0,0,0);const {data:today}=await db.from('wallet_transactions').select('amount').eq('profile_id',profile.id).gte('created_at',start.toISOString()).gt('amount',0);const todayEarn=(today||[]).reduce((s,x)=>s+Number(x.amount),0);
 const {data:mineTx}=await db.from('wallet_transactions').select('amount').eq('profile_id',profile.id).eq('transaction_type','mining_reward');
 const {count:sessions}=await db.from('mining_sessions').select('id',{count:'exact',head:true}).eq('profile_id',profile.id).gte('started_at',start.toISOString());
 return json(res,200,{profile:{id:profile.id,account_status:profile.account_status,is_admin:profile.is_admin},wallet:wallet||{available_balance:0,pending_balance:0,lifetime_earnings:0},today_earnings:todayEarn,mining:{active:session||null,session_earned:session?.earned_amount||0,total_earned:(mineTx||[]).reduce((s,x)=>s+Number(x.amount),0),sessions_today:sessions||0,daily_limit:Number(cfg.mining_daily_limit||1)},tasks_completed:tasks?.length||0,referrals:{count:refCount||0,link:process.env.TELEGRAM_BOT_USERNAME?`https://t.me/${process.env.TELEGRAM_BOT_USERNAME}?start=${profile.referral_code}`:''},plan:plan?.plans||{name:'FREE'},recent_transactions:tx||[],announcement:null});
 }catch(e){return handleError(res,e)}}
