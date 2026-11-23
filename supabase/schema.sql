-- MINING BOT schema v1. Apply in Supabase SQL Editor as project owner.
create extension if not exists pgcrypto;
do $$ begin create type account_state as enum ('pending','active','suspended','rejected'); exception when duplicate_object then null; end $$;
do $$ begin create type review_state as enum ('pending','approved','rejected'); exception when duplicate_object then null; end $$;
do $$ begin create type txn_kind as enum ('mining_reward','task_reward','quiz_reward','game_reward','ad_reward','referral_reward','plan_purchase','deposit','withdrawal','admin_adjustment'); exception when duplicate_object then null; end $$;
create table if not exists profiles (
 id uuid primary key default gen_random_uuid(), telegram_id text not null unique, username text, first_name text, last_name text, language_code text default 'en', display_name text,
 account_status account_state not null default 'pending', is_admin boolean not null default false, referral_code text not null unique default upper(substr(encode(gen_random_bytes(8),'hex'),1,10)), referred_by uuid references profiles(id),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(), last_seen_at timestamptz
);
create table if not exists admin_users(profile_id uuid primary key references profiles(id), role text not null default 'admin', created_at timestamptz not null default now());
create table if not exists wallets(profile_id uuid primary key references profiles(id), available_balance numeric(20,6) not null default 0 check(available_balance>=0), pending_balance numeric(20,6) not null default 0 check(pending_balance>=0), lifetime_earnings numeric(20,6) not null default 0, updated_at timestamptz not null default now());
create table if not exists wallet_transactions(id uuid primary key default gen_random_uuid(),profile_id uuid not null references profiles(id),transaction_type txn_kind not null,amount numeric(20,6) not null,description text,idempotency_key text not null unique,reference_id uuid,created_at timestamptz not null default now());
create index if not exists wallet_tx_profile_date on wallet_transactions(profile_id,created_at desc);
create table if not exists app_settings(key text primary key,value jsonb not null,updated_at timestamptz not null default now());
create table if not exists mining_sessions(id uuid primary key default gen_random_uuid(),profile_id uuid not null references profiles(id),started_at timestamptz not null default now(),ends_at timestamptz not null,claimed_at timestamptz,earned_amount numeric(20,6) not null default 0,rate_per_minute numeric(20,6) not null,session_duration_seconds integer not null,created_at timestamptz not null default now());
create index if not exists mining_sessions_user_start on mining_sessions(profile_id,started_at desc);
create unique index if not exists one_unclaimed_mining_session on mining_sessions(profile_id) where claimed_at is null;
create table if not exists mining_claims(id uuid primary key default gen_random_uuid(),session_id uuid not null unique references mining_sessions(id),profile_id uuid not null references profiles(id),amount numeric(20,6) not null,created_at timestamptz not null default now());
create table if not exists tasks(id uuid primary key default gen_random_uuid(),title text not null,description text,task_type text not null,task_link text,reward_amount numeric(20,6) not null default 0,starts_at timestamptz not null default now(),ends_at timestamptz not null default (now()+interval '30 days'),daily_limit integer,completion_limit integer,verification_method text not null default 'manual',status text not null default 'active',created_at timestamptz not null default now(),updated_at timestamptz not null default now());
create table if not exists task_submissions(id uuid primary key default gen_random_uuid(),profile_id uuid not null references profiles(id),task_id uuid not null references tasks(id),status review_state not null default 'pending',proof text,reviewed_by uuid references profiles(id),reviewed_at timestamptz,created_at timestamptz not null default now(),unique(profile_id,task_id));
create table if not exists quizzes(id uuid primary key default gen_random_uuid(),title text not null,language text default 'en',topic text,difficulty text default 'easy',starts_at timestamptz,ends_at timestamptz,attempt_limit integer default 1,points_correct numeric(20,6) default 0,points_wrong numeric(20,6) default 0,is_active boolean default false,created_at timestamptz default now());
create table if not exists quiz_questions(id uuid primary key default gen_random_uuid(),quiz_id uuid not null references quizzes(id) on delete cascade,question text not null,options jsonb not null,correct_option integer not null,explanation text,created_at timestamptz default now());
create table if not exists quiz_attempts(id uuid primary key default gen_random_uuid(),quiz_id uuid not null references quizzes(id),profile_id uuid not null references profiles(id),started_at timestamptz not null default now(),submitted_at timestamptz,answers jsonb,score numeric(20,6),unique(quiz_id,profile_id,started_at));
create table if not exists games(id uuid primary key default gen_random_uuid(),name text not null,game_type text not null,config jsonb not null default '{}',daily_limit integer default 1,cooldown_seconds integer default 0,is_active boolean default false);
create table if not exists game_sessions(id uuid primary key default gen_random_uuid(),game_id uuid not null references games(id),profile_id uuid not null references profiles(id),server_result jsonb,started_at timestamptz default now(),completed_at timestamptz,reward numeric(20,6) default 0);
create table if not exists ad_settings(id uuid primary key default gen_random_uuid(),provider text not null,config jsonb not null default '{}',reward numeric(20,6) default 0,daily_limit integer default 0,is_active boolean default false);
create table if not exists ad_completions(id uuid primary key default gen_random_uuid(),profile_id uuid not null references profiles(id),provider_ref text unique,status text not null default 'pending',verified_at timestamptz,created_at timestamptz default now());
create table if not exists plans(id uuid primary key default gen_random_uuid(),name text not null,price numeric(20,6) default 0,duration_days integer default 30,mining_rate_multiplier numeric(10,4) default 1,config jsonb default '{}',is_active boolean default true,created_at timestamptz default now());
create table if not exists user_plans(id uuid primary key default gen_random_uuid(),profile_id uuid not null references profiles(id),plan_id uuid not null references plans(id),status text not null default 'pending',starts_at timestamptz,expires_at timestamptz,payment_ref text,created_at timestamptz default now());
create table if not exists account_activations(id uuid primary key default gen_random_uuid(),profile_id uuid not null references profiles(id),method text not null,status review_state not null default 'pending',payment_ref text,activation_code text,reviewed_by uuid references profiles(id),created_at timestamptz default now());
create table if not exists payment_methods(id uuid primary key default gen_random_uuid(),name text not null,currency text,config jsonb default '{}',is_active boolean default true);
create table if not exists deposits(id uuid primary key default gen_random_uuid(),profile_id uuid not null references profiles(id),amount numeric(20,6) not null,method_id uuid references payment_methods(id),transaction_ref text,status review_state not null default 'pending',created_at timestamptz default now());
create table if not exists withdrawals(id uuid primary key default gen_random_uuid(),profile_id uuid not null references profiles(id),amount numeric(20,6) not null,fee numeric(20,6) not null default 0,payment_method text not null,destination text not null,status text not null default 'pending',admin_ref text,created_at timestamptz default now(),updated_at timestamptz default now());
create table if not exists referrals(id uuid primary key default gen_random_uuid(),referrer_profile_id uuid not null references profiles(id),referred_profile_id uuid not null unique references profiles(id),status text not null default 'pending',reward numeric(20,6) default 0,created_at timestamptz default now());
create table if not exists notifications(id uuid primary key default gen_random_uuid(),profile_id uuid references profiles(id),title text not null,body text not null,read_at timestamptz,created_at timestamptz default now());
create table if not exists support_tickets(id uuid primary key default gen_random_uuid(),profile_id uuid not null references profiles(id),subject text not null,message text not null,status text not null default 'open',created_at timestamptz default now());
create table if not exists audit_logs(id uuid primary key default gen_random_uuid(),actor_profile_id uuid references profiles(id),action text not null,entity_type text,entity_id uuid,details jsonb default '{}',created_at timestamptz not null default now());

-- Private server-side access only. Mini App API authenticates Telegram initData and uses service role on the server.
do $$ declare t text; begin foreach t in array array['profiles','admin_users','wallets','wallet_transactions','app_settings','mining_sessions','mining_claims','tasks','task_submissions','quizzes','quiz_questions','quiz_attempts','games','game_sessions','ad_settings','ad_completions','plans','user_plans','account_activations','payment_methods','deposits','withdrawals','referrals','notifications','support_tickets','audit_logs'] loop execute format('alter table %I enable row level security',t); execute format('revoke all on %I from anon, authenticated',t); end loop; end $$;

create or replace function ensure_profile_wallet() returns trigger language plpgsql security definer set search_path=public as $$ begin insert into wallets(profile_id) values(new.id) on conflict do nothing; return new; end $$;
drop trigger if exists profile_wallet_insert on profiles;
create trigger profile_wallet_insert after insert on profiles for each row execute function ensure_profile_wallet();

create or replace function start_mining_session(p_profile_id uuid) returns jsonb language plpgsql security definer set search_path=public as $$
declare s mining_sessions; rate numeric; dur integer; lim integer; today_start timestamptz:=date_trunc('day',now()); n integer; begin
 if not exists(select 1 from profiles where id=p_profile_id and account_status='active') then raise exception 'Account activation is required'; end if;
 select coalesce((value#>>'{}')::numeric,0.1) into rate from app_settings where key='mining_rate_per_minute'; rate:=coalesce(rate,0.1);
 select coalesce((value#>>'{}')::integer,60) into dur from app_settings where key='mining_duration_seconds';dur:=coalesce(dur,60);
 select coalesce((value#>>'{}')::integer,1) into lim from app_settings where key='mining_daily_limit';lim:=coalesce(lim,1);
 select count(*) into n from mining_sessions where profile_id=p_profile_id and started_at>=today_start;if n>=lim then raise exception 'Daily mining limit reached';end if;
 if exists(select 1 from mining_sessions where profile_id=p_profile_id and claimed_at is null) then raise exception 'An active or unclaimed mining session already exists';end if;
 insert into mining_sessions(profile_id,started_at,ends_at,rate_per_minute,session_duration_seconds,earned_amount) values(p_profile_id,now(),now()+make_interval(secs=>dur),rate,dur,rate*dur/60.0) returning * into s;
 return jsonb_build_object('id',s.id,'started_at',s.started_at,'ends_at',s.ends_at,'earned_amount',s.earned_amount);
end $$;

create or replace function claim_mining_reward(p_profile_id uuid,p_session_id uuid) returns jsonb language plpgsql security definer set search_path=public as $$
declare s mining_sessions; n integer; lim integer; amount numeric; begin
 select * into s from mining_sessions where id=p_session_id and profile_id=p_profile_id for update;
 if not found then raise exception 'Mining session not found';end if;
 if s.claimed_at is not null then raise exception 'Mining reward already claimed';end if;
 if now()<s.ends_at then raise exception 'Mining session is not complete yet';end if;
 select coalesce((value#>>'{}')::integer,1) into lim from app_settings where key='mining_daily_limit';lim:=coalesce(lim,1);
 select count(*) into n from mining_claims c join mining_sessions m on m.id=c.session_id where c.profile_id=p_profile_id and m.started_at>=date_trunc('day',now());
 if n>=lim then raise exception 'Daily mining claim limit reached';end if;
 amount:=s.earned_amount;
 insert into mining_claims(session_id,profile_id,amount) values(s.id,p_profile_id,amount);
 insert into wallets(profile_id) values(p_profile_id) on conflict do nothing;
 update wallets set available_balance=available_balance+amount,lifetime_earnings=lifetime_earnings+amount,updated_at=now() where profile_id=p_profile_id;
 insert into wallet_transactions(profile_id,transaction_type,amount,description,idempotency_key,reference_id) values(p_profile_id,'mining_reward',amount,'Verified mining session reward','mine:'||s.id,s.id);
 update mining_sessions set claimed_at=now() where id=s.id;
 return jsonb_build_object('session_id',s.id,'amount',amount,'claimed_at',now());
end $$;
revoke all on function start_mining_session(uuid) from public,anon,authenticated;
revoke all on function claim_mining_reward(uuid,uuid) from public,anon,authenticated;
grant execute on function start_mining_session(uuid) to service_role;
grant execute on function claim_mining_reward(uuid,uuid) to service_role;

insert into app_settings(key,value) values ('mining_rate_per_minute','0.1'::jsonb),('mining_duration_seconds','3600'::jsonb),('mining_daily_limit','1'::jsonb),('currency_code','"COIN"'::jsonb),('activation_required','true'::jsonb) on conflict(key) do nothing;
insert into plans(name,price,duration_days,mining_rate_multiplier,config,is_active) select 'FREE',0,0,1,'{}',true where not exists(select 1 from plans where name='FREE');

create or replace function review_task_submission(p_submission_id uuid,p_admin_profile_id uuid,p_decision review_state) returns jsonb language plpgsql security definer set search_path=public as $$
declare s task_submissions; t tasks; begin
 if not exists(select 1 from profiles where id=p_admin_profile_id and is_admin=true) and not exists(select 1 from admin_users where profile_id=p_admin_profile_id) then raise exception 'Admin role required';end if;
 select * into s from task_submissions where id=p_submission_id for update;if not found then raise exception 'Submission not found';end if;if s.status<>'pending' then raise exception 'Submission already reviewed';end if;
 update task_submissions set status=p_decision,reviewed_by=p_admin_profile_id,reviewed_at=now() where id=s.id;
 if p_decision='approved' then
  select * into t from tasks where id=s.task_id;
  insert into wallets(profile_id) values(s.profile_id) on conflict do nothing;
  update wallets set available_balance=available_balance+t.reward_amount,lifetime_earnings=lifetime_earnings+t.reward_amount,updated_at=now() where profile_id=s.profile_id;
  insert into wallet_transactions(profile_id,transaction_type,amount,description,idempotency_key,reference_id) values(s.profile_id,'task_reward',t.reward_amount,'Verified task: '||t.title,'task:'||s.id,s.id);
 end if;
 insert into audit_logs(actor_profile_id,action,entity_type,entity_id,details) values(p_admin_profile_id,'task_submission_'||p_decision,'task_submission',s.id,jsonb_build_object('profile_id',s.profile_id,'task_id',s.task_id));
 return jsonb_build_object('submission_id',s.id,'status',p_decision);
end $$;
revoke all on function review_task_submission(uuid,uuid,review_state) from public,anon,authenticated;
grant execute on function review_task_submission(uuid,uuid,review_state) to service_role;
