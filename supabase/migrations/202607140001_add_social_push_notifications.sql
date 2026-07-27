alter table public.coach_user_settings
    add column if not exists social_notifications boolean not null default true;

create table if not exists public.push_device_tokens (
    device_token text primary key,
    user_id uuid not null references auth.users(id) on delete cascade,
    platform text not null default 'ios' check (platform = 'ios'),
    environment text not null check (environment in ('sandbox', 'production')),
    app_bundle_id text not null,
    is_active boolean not null default true,
    last_seen_at timestamptz not null default now(),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint push_device_tokens_hex_format check (device_token ~ '^[0-9a-f]{64,200}$')
);

create index if not exists push_device_tokens_user_active_idx
    on public.push_device_tokens (user_id, is_active);

alter table public.push_device_tokens enable row level security;

drop policy if exists "Users can view own push devices" on public.push_device_tokens;
create policy "Users can view own push devices" on public.push_device_tokens
    for select to authenticated
    using (user_id = (select auth.uid()));

drop policy if exists "Users can remove own push devices" on public.push_device_tokens;
create policy "Users can remove own push devices" on public.push_device_tokens
    for delete to authenticated
    using (user_id = (select auth.uid()));

revoke all on table public.push_device_tokens from public, anon, authenticated;
grant select, delete on table public.push_device_tokens to authenticated;

create or replace function public.register_push_device(
    p_device_token text,
    p_environment text,
    p_bundle_id text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
    current_user_id uuid := (select auth.uid());
    normalized_token text := lower(trim(p_device_token));
begin
    if current_user_id is null then
        raise exception 'authentication required';
    end if;
    if normalized_token !~ '^[0-9a-f]{64,200}$' then
        raise exception 'invalid APNs device token';
    end if;
    if p_environment not in ('sandbox', 'production') then
        raise exception 'invalid APNs environment';
    end if;
    if nullif(trim(p_bundle_id), '') is null then
        raise exception 'bundle identifier required';
    end if;

    insert into public.push_device_tokens (
        device_token, user_id, environment, app_bundle_id, is_active, last_seen_at
    ) values (
        normalized_token, current_user_id, p_environment, trim(p_bundle_id), true, now()
    )
    on conflict (device_token) do update
        set user_id = excluded.user_id,
            environment = excluded.environment,
            app_bundle_id = excluded.app_bundle_id,
            is_active = true,
            last_seen_at = now(),
            updated_at = now();
end;
$$;

revoke all on function public.register_push_device(text, text, text) from public, anon;
grant execute on function public.register_push_device(text, text, text) to authenticated;

create or replace function public.unregister_push_device(p_device_token text)
returns void
language sql
security invoker
set search_path = ''
as $$
    delete from public.push_device_tokens
    where device_token = lower(trim(p_device_token))
      and user_id = (select auth.uid());
$$;

revoke all on function public.unregister_push_device(text) from public, anon;
grant execute on function public.unregister_push_device(text) to authenticated;
