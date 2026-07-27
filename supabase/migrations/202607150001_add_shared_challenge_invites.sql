-- One-time invitations make it possible to challenge someone before they are an in-app friend.
-- The invite never stores camera footage or pose data; it references the existing verified session.

create table if not exists public.shared_challenge_invites (
    id uuid primary key default extensions.uuid_generate_v4(),
    invite_code text not null unique default upper(substr(replace(extensions.uuid_generate_v4()::text, '-', ''), 1, 12)),
    inviter_id uuid not null references auth.users(id) on delete cascade,
    challenger_session_id uuid not null references public.movement_challenge_sessions(id) on delete restrict,
    challenge_type text not null check (challenge_type in ('push_up', 'squat', 'jumping_jack')),
    challenger_rep_count integer not null default 0 check (challenger_rep_count > 0),
    target_rep_count integer not null default 1 check (target_rep_count > 0),
    claimed_by uuid references auth.users(id) on delete set null,
    status text not null default 'pending' check (status in ('pending', 'claimed', 'expired', 'cancelled')),
    expires_at timestamptz not null default (now() + interval '7 days'),
    created_at timestamptz not null default now(),
    claimed_at timestamptz,
    updated_at timestamptz not null default now()
);

create index if not exists shared_challenge_invites_inviter_created_idx
    on public.shared_challenge_invites (inviter_id, created_at desc);
create index if not exists shared_challenge_invites_claimed_by_idx
    on public.shared_challenge_invites (claimed_by, created_at desc)
    where claimed_by is not null;

create or replace function public.validate_shared_challenge_invite_change()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
    session_owner uuid;
    session_type text;
    session_reps integer;
begin
    if tg_op <> 'INSERT' then
        raise exception 'shared challenge invitations cannot be changed directly';
    end if;

    if (select auth.uid()) is null or new.inviter_id <> (select auth.uid()) then
        raise exception 'shared challenge invitations must be created by the challenger';
    end if;

    select user_id, challenge_type, valid_rep_count
    into session_owner, session_type, session_reps
    from public.movement_challenge_sessions
    where id = new.challenger_session_id;

    if session_owner is distinct from new.inviter_id
       or session_type is distinct from new.challenge_type
       or coalesce(session_reps, 0) < 1 then
        raise exception 'the shared challenge needs a verified session owned by the challenger';
    end if;

    new.invite_code := upper(coalesce(nullif(trim(new.invite_code), ''), substr(replace(extensions.uuid_generate_v4()::text, '-', ''), 1, 12)));
    new.challenger_rep_count := session_reps;
    new.target_rep_count := session_reps + 1;
    new.claimed_by := null;
    new.status := 'pending';
    new.claimed_at := null;
    new.updated_at := now();
    return new;
end;
$$;

drop trigger if exists validate_shared_challenge_invite_change_trigger on public.shared_challenge_invites;
create trigger validate_shared_challenge_invite_change_trigger
    before insert or update on public.shared_challenge_invites
    for each row execute function public.validate_shared_challenge_invite_change();

-- A redeemed invitation is the one narrow exception to the normal "friends only" challenge insert.
-- The security-definer function below sets this transaction-local context after locking and claiming
-- the invitation. Direct client inserts still remain restricted by RLS.
create or replace function public.validate_fitness_challenge_change()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
    session_owner uuid;
    session_type text;
    session_reps integer;
    shared_invite_id uuid;
    uses_shared_invite boolean := false;
begin
    if tg_op = 'INSERT' then
        if (select auth.uid()) is null then
            raise exception 'sign in is required to create a challenge';
        end if;

        uses_shared_invite := current_setting('app.shared_challenge_claim', true) = 'on';
        if uses_shared_invite then
            shared_invite_id := nullif(current_setting('app.shared_challenge_invite_id', true), '')::uuid;
            if shared_invite_id is null or not exists (
                select 1
                from public.shared_challenge_invites invite
                where invite.id = shared_invite_id
                  and invite.inviter_id = new.challenger_id
                  and invite.challenger_session_id = new.challenger_session_id
                  and invite.challenge_type = new.challenge_type
                  and invite.claimed_by = (select auth.uid())
                  and invite.status = 'claimed'
            ) then
                raise exception 'shared challenge invitation is not valid';
            end if;
            if new.challenged_id <> (select auth.uid()) then
                raise exception 'shared challenge must be claimed by the recipient';
            end if;
        elsif new.challenger_id <> (select auth.uid()) then
            raise exception 'challenges must be created by the challenger';
        end if;

        select user_id, challenge_type, valid_rep_count
        into session_owner, session_type, session_reps
        from public.movement_challenge_sessions
        where id = new.challenger_session_id;

        if session_owner is distinct from new.challenger_id or session_type is distinct from new.challenge_type then
            raise exception 'challenger session does not match this challenge';
        end if;

        new.challenger_rep_count := session_reps;
        new.target_rep_count := session_reps + 1;
        new.challenged_session_id := null;
        new.challenged_rep_count := null;
        new.winner_id := null;
        new.status := 'pending';
        new.completed_at := null;
    elsif tg_op = 'UPDATE' then
        if (select auth.uid()) is null or old.challenged_id <> (select auth.uid()) then
            raise exception 'only the challenged friend can answer';
        end if;
        if old.status <> 'pending' then
            raise exception 'this challenge is already closed';
        end if;

        new.challenger_id := old.challenger_id;
        new.challenged_id := old.challenged_id;
        new.challenge_type := old.challenge_type;
        new.challenger_session_id := old.challenger_session_id;
        new.challenger_rep_count := old.challenger_rep_count;
        new.target_rep_count := old.target_rep_count;
        new.created_at := old.created_at;

        if new.status = 'declined' then
            new.challenged_session_id := null;
            new.challenged_rep_count := null;
            new.winner_id := null;
            new.completed_at := now();
        else
            if new.challenged_session_id is null then
                raise exception 'a verified movement session is required';
            end if;

            select user_id, challenge_type, valid_rep_count
            into session_owner, session_type, session_reps
            from public.movement_challenge_sessions
            where id = new.challenged_session_id;

            if session_owner is distinct from new.challenged_id or session_type is distinct from old.challenge_type then
                raise exception 'response session does not match this challenge';
            end if;

            new.challenged_rep_count := session_reps;
            new.status := 'completed';
            new.completed_at := now();
            new.winner_id := case
                when session_reps >= old.target_rep_count then new.challenged_id
                else old.challenger_id
            end;
        end if;
    end if;

    new.updated_at := now();
    return new;
end;
$$;

create or replace function public.redeem_shared_fitness_challenge(p_invite_code text)
returns public.fitness_challenges
language plpgsql
security definer
set search_path = ''
as $$
declare
    invite public.shared_challenge_invites%rowtype;
    created_challenge public.fitness_challenges%rowtype;
begin
    if (select auth.uid()) is null then
        raise exception 'sign in is required to redeem a challenge';
    end if;

    select *
    into invite
    from public.shared_challenge_invites
    where invite_code = upper(trim(p_invite_code))
    for update;

    if not found then
        raise exception 'challenge invitation not found';
    end if;
    if invite.inviter_id = (select auth.uid()) then
        raise exception 'you cannot redeem your own challenge';
    end if;
    if invite.status <> 'pending' or invite.claimed_by is not null then
        raise exception 'this challenge invitation was already claimed';
    end if;
    if invite.expires_at <= now() then
        update public.shared_challenge_invites
        set status = 'expired', updated_at = now()
        where id = invite.id;
        raise exception 'this challenge invitation expired';
    end if;

    update public.shared_challenge_invites
    set claimed_by = (select auth.uid()),
        status = 'claimed',
        claimed_at = now(),
        updated_at = now()
    where id = invite.id;

    perform set_config('app.shared_challenge_claim', 'on', true);
    perform set_config('app.shared_challenge_invite_id', invite.id::text, true);

    insert into public.fitness_challenges (
        challenger_id,
        challenged_id,
        challenge_type,
        challenger_session_id
    ) values (
        invite.inviter_id,
        (select auth.uid()),
        invite.challenge_type,
        invite.challenger_session_id
    )
    returning * into created_challenge;

    return created_challenge;
end;
$$;

revoke all on function public.redeem_shared_fitness_challenge(text) from public, anon;
grant execute on function public.redeem_shared_fitness_challenge(text) to authenticated;

alter table public.shared_challenge_invites enable row level security;

create policy "Inviters and claimants can view shared challenge invitations"
    on public.shared_challenge_invites
    for select to authenticated
    using ((select auth.uid()) in (inviter_id, claimed_by));

create policy "Users can create their own shared challenge invitations"
    on public.shared_challenge_invites
    for insert to authenticated
    with check (inviter_id = (select auth.uid()));

revoke all on table public.shared_challenge_invites from anon;
revoke all on table public.shared_challenge_invites from authenticated;
grant select, insert on table public.shared_challenge_invites to authenticated;

drop policy if exists "Users can view relevant social profiles" on public.social_profiles;
create policy "Users can view relevant social profiles" on public.social_profiles
    for select to authenticated
    using (
        user_id = (select auth.uid())
        or exists (
            select 1
            from public.friendships friendship
            where friendship.status in ('pending', 'accepted')
              and (
                  (friendship.requester_id = (select auth.uid()) and friendship.addressee_id = social_profiles.user_id)
                  or (friendship.addressee_id = (select auth.uid()) and friendship.requester_id = social_profiles.user_id)
              )
        )
        or exists (
            select 1
            from public.fitness_challenges challenge
            where social_profiles.user_id in (challenge.challenger_id, challenge.challenged_id)
              and (select auth.uid()) in (challenge.challenger_id, challenge.challenged_id)
        )
    );
