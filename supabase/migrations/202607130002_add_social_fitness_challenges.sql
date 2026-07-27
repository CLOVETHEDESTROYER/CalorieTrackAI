create table if not exists public.social_profiles (
    user_id uuid primary key references auth.users(id) on delete cascade,
    display_name text not null check (char_length(trim(display_name)) between 1 and 40),
    friend_code text not null default upper(substr(replace(extensions.uuid_generate_v4()::text, '-', ''), 1, 8)),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint social_profiles_friend_code_format check (friend_code ~ '^[A-Z0-9]{8}$'),
    constraint social_profiles_friend_code_key unique (friend_code)
);

create table if not exists public.friendships (
    id uuid primary key default extensions.uuid_generate_v4(),
    requester_id uuid not null references auth.users(id) on delete cascade,
    addressee_id uuid not null references auth.users(id) on delete cascade,
    status text not null default 'pending' check (status in ('pending', 'accepted', 'declined')),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint friendships_no_self_request check (requester_id <> addressee_id)
);

create unique index if not exists friendships_unique_pair
    on public.friendships (least(requester_id, addressee_id), greatest(requester_id, addressee_id));
create index if not exists friendships_requester_status_idx
    on public.friendships (requester_id, status);
create index if not exists friendships_addressee_status_idx
    on public.friendships (addressee_id, status);

create table if not exists public.fitness_challenges (
    id uuid primary key default extensions.uuid_generate_v4(),
    challenger_id uuid not null references auth.users(id) on delete cascade,
    challenged_id uuid not null references auth.users(id) on delete cascade,
    challenge_type text not null check (challenge_type in ('push_up', 'squat', 'jumping_jack')),
    challenger_session_id uuid not null references public.movement_challenge_sessions(id) on delete restrict,
    challenged_session_id uuid references public.movement_challenge_sessions(id) on delete restrict,
    challenger_rep_count integer not null default 0 check (challenger_rep_count >= 0),
    challenged_rep_count integer check (challenged_rep_count >= 0),
    target_rep_count integer not null default 1 check (target_rep_count > 0),
    winner_id uuid references auth.users(id) on delete set null,
    status text not null default 'pending' check (status in ('pending', 'completed', 'declined')),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    completed_at timestamptz,
    constraint fitness_challenges_no_self_challenge check (challenger_id <> challenged_id)
);

create index if not exists fitness_challenges_challenged_status_idx
    on public.fitness_challenges (challenged_id, status, created_at desc);
create index if not exists fitness_challenges_challenger_created_idx
    on public.fitness_challenges (challenger_id, created_at desc);

create or replace function public.create_social_profile_for_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    insert into public.social_profiles (user_id, display_name)
    values (new.user_id, left(coalesce(nullif(trim(new.name), ''), 'Athlete'), 40))
    on conflict (user_id) do update
        set display_name = excluded.display_name,
            updated_at = now();
    return new;
end;
$$;

revoke all on function public.create_social_profile_for_user() from public, anon, authenticated;

drop trigger if exists create_social_profile_after_user_profile on public.user_profiles;
create trigger create_social_profile_after_user_profile
    after insert or update of name on public.user_profiles
    for each row execute function public.create_social_profile_for_user();

insert into public.social_profiles (user_id, display_name)
select user_id, left(coalesce(nullif(trim(name), ''), 'Athlete'), 40)
from public.user_profiles
on conflict (user_id) do update
set display_name = excluded.display_name,
    updated_at = now();

create or replace function public.search_social_profile_by_friend_code(p_friend_code text)
returns table (user_id uuid, display_name text, friend_code text)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
    if (select auth.uid()) is null then
        return;
    end if;

    return query
    select profile.user_id, profile.display_name, profile.friend_code
    from public.social_profiles profile
    where profile.friend_code = upper(trim(p_friend_code))
      and profile.user_id <> (select auth.uid())
    limit 1;
end;
$$;

revoke all on function public.search_social_profile_by_friend_code(text) from public, anon;
grant execute on function public.search_social_profile_by_friend_code(text) to authenticated;

create or replace function public.validate_friendship_change()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
    if tg_op = 'INSERT' then
        if (select auth.uid()) is null or new.requester_id <> (select auth.uid()) then
            raise exception 'friend requests must be created by the requester';
        end if;
        new.status := 'pending';
    elsif tg_op = 'UPDATE' then
        if (select auth.uid()) is null or old.addressee_id <> (select auth.uid()) then
            raise exception 'only the addressee can answer a friend request';
        end if;
        if old.status <> 'pending' or new.status not in ('accepted', 'declined') then
            raise exception 'invalid friend request transition';
        end if;
        new.requester_id := old.requester_id;
        new.addressee_id := old.addressee_id;
        new.created_at := old.created_at;
        new.updated_at := now();
    end if;
    return new;
end;
$$;

drop trigger if exists validate_friendship_change_trigger on public.friendships;
create trigger validate_friendship_change_trigger
    before insert or update on public.friendships
    for each row execute function public.validate_friendship_change();

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
begin
    if tg_op = 'INSERT' then
        if (select auth.uid()) is null or new.challenger_id <> (select auth.uid()) then
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

drop trigger if exists validate_fitness_challenge_change_trigger on public.fitness_challenges;
create trigger validate_fitness_challenge_change_trigger
    before insert or update on public.fitness_challenges
    for each row execute function public.validate_fitness_challenge_change();

alter table public.social_profiles enable row level security;
alter table public.friendships enable row level security;
alter table public.fitness_challenges enable row level security;

drop policy if exists "Users can view relevant social profiles" on public.social_profiles;
create policy "Users can view relevant social profiles" on public.social_profiles
    for select to authenticated
    using (
        user_id = (select auth.uid())
        or exists (
            select 1 from public.friendships friendship
            where friendship.status in ('pending', 'accepted')
              and (
                  (friendship.requester_id = (select auth.uid()) and friendship.addressee_id = social_profiles.user_id)
                  or (friendship.addressee_id = (select auth.uid()) and friendship.requester_id = social_profiles.user_id)
              )
        )
    );

drop policy if exists "Users can insert own social profile" on public.social_profiles;
create policy "Users can insert own social profile" on public.social_profiles
    for insert to authenticated
    with check (user_id = (select auth.uid()));

drop policy if exists "Users can update own social profile" on public.social_profiles;
create policy "Users can update own social profile" on public.social_profiles
    for update to authenticated
    using (user_id = (select auth.uid()))
    with check (user_id = (select auth.uid()));

drop policy if exists "Friends can view their relationship" on public.friendships;
create policy "Friends can view their relationship" on public.friendships
    for select to authenticated
    using ((select auth.uid()) in (requester_id, addressee_id));

drop policy if exists "Users can send friend requests" on public.friendships;
create policy "Users can send friend requests" on public.friendships
    for insert to authenticated
    with check (requester_id = (select auth.uid()) and addressee_id <> (select auth.uid()));

drop policy if exists "Addressees can answer friend requests" on public.friendships;
create policy "Addressees can answer friend requests" on public.friendships
    for update to authenticated
    using (addressee_id = (select auth.uid()) and status = 'pending')
    with check (addressee_id = (select auth.uid()));

drop policy if exists "Friends can remove relationships" on public.friendships;
create policy "Friends can remove relationships" on public.friendships
    for delete to authenticated
    using ((select auth.uid()) in (requester_id, addressee_id));

drop policy if exists "Participants can view fitness challenges" on public.fitness_challenges;
create policy "Participants can view fitness challenges" on public.fitness_challenges
    for select to authenticated
    using ((select auth.uid()) in (challenger_id, challenged_id));

drop policy if exists "Friends can create verified fitness challenges" on public.fitness_challenges;
create policy "Friends can create verified fitness challenges" on public.fitness_challenges
    for insert to authenticated
    with check (
        challenger_id = (select auth.uid())
        and challenged_id <> (select auth.uid())
        and exists (
            select 1 from public.friendships friendship
            where friendship.status = 'accepted'
              and (
                  (friendship.requester_id = challenger_id and friendship.addressee_id = challenged_id)
                  or (friendship.requester_id = challenged_id and friendship.addressee_id = challenger_id)
              )
        )
    );

drop policy if exists "Challenged users can answer fitness challenges" on public.fitness_challenges;
create policy "Challenged users can answer fitness challenges" on public.fitness_challenges
    for update to authenticated
    using (challenged_id = (select auth.uid()) and status = 'pending')
    with check (challenged_id = (select auth.uid()));

revoke all on table public.social_profiles, public.friendships, public.fitness_challenges from anon;
revoke all on table public.social_profiles, public.friendships, public.fitness_challenges from authenticated;

grant select, insert on table public.social_profiles to authenticated;
grant update (display_name) on table public.social_profiles to authenticated;
grant select, insert, delete on table public.friendships to authenticated;
grant update (status) on table public.friendships to authenticated;
grant select, insert on table public.fitness_challenges to authenticated;
grant update (challenged_session_id, status) on table public.fitness_challenges to authenticated;
