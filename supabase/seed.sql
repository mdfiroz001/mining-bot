-- Safe starter configuration only. No demo users, fake balances, or paid plans are inserted.
insert into app_settings(key,value) values
 ('mining_rate_per_minute','0.1'::jsonb),
 ('mining_duration_seconds','3600'::jsonb),
 ('mining_daily_limit','1'::jsonb),
 ('currency_code','"COIN"'::jsonb),
 ('activation_required','true'::jsonb)
on conflict(key) do nothing;
insert into plans(name,price,duration_days,mining_rate_multiplier,config,is_active)
select 'FREE',0,0,1,'{}'::jsonb,true
where not exists(select 1 from plans where name='FREE');
