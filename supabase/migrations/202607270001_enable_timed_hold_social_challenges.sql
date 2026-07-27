-- Social challenges use a single integer score column. For rep tests it is reps;
-- for planks it is the verified whole hold seconds. Keep that derivation on the
-- server so clients cannot claim a score that does not match their saved session.
set lock_timeout = '5s';

alter table public.fitness_challenges
    drop constraint if exists fitness_challenges_challenge_type_check;

alter table public.fitness_challenges
    add constraint fitness_challenges_challenge_type_check
    check (challenge_type in ('push_up', 'squat', 'jumping_jack', 'plank')) not valid;

alter table public.fitness_challenges
    validate constraint fitness_challenges_challenge_type_check;

alter table public.shared_challenge_invites
    drop constraint if exists shared_challenge_invites_challenge_type_check;

alter table public.shared_challenge_invites
    add constraint shared_challenge_invites_challenge_type_check
    check (challenge_type in ('push_up', 'squat', 'jumping_jack', 'plank')) not valid;

alter table public.shared_challenge_invites
    validate constraint shared_challenge_invites_challenge_type_check;

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
    session_duration numeric;
    session_score integer;
begin
    if tg_op <> 'INSERT' then
        raise exception 'shared challenge invitations cannot be changed directly';
    end if;

    if (select auth.uid()) is null or new.inviter_id <> (select auth.uid()) then
        raise exception 'shared challenge invitations must be created by the challenger';
    end if;

    select user_id, challenge_type, valid_rep_count, duration_seconds
    into session_owner, session_type, session_reps, session_duration
    from public.movement_challenge_sessions
    where id = new.challenger_session_id;

    session_score := case
        when session_type = 'plank' then floor(coalesce(session_duration, 0))::integer
        else coalesce(session_reps, 0)
    end;

    if session_owner is distinct from new.inviter_id
       or session_type is distinct from new.challenge_type
       or session_score < 1 then
        raise exception 'the shared challenge needs a verified session owned by the challenger';
    end if;

    new.invite_code := upper(coalesce(nullif(trim(new.invite_code), ''), substr(replace(extensions.uuid_generate_v4()::text, '-', ''), 1, 12)));
    new.challenger_rep_count := session_score;
    new.target_rep_count := session_score + 1;
    new.claimed_by := null;
    new.status := 'pending';
    new.claimed_at := null;
    new.updated_at := now();
    return new;
end;
$$;

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
    session_duration numeric;
    session_score integer;
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

        select user_id, challenge_type, valid_rep_count, duration_seconds
        into session_owner, session_type, session_reps, session_duration
        from public.movement_challenge_sessions
        where id = new.challenger_session_id;

        session_score := case
            when session_type = 'plank' then floor(coalesce(session_duration, 0))::integer
            else coalesce(session_reps, 0)
        end;

        if session_owner is distinct from new.challenger_id
           or session_type is distinct from new.challenge_type
           or session_score < 1 then
            raise exception 'challenger session does not match this challenge';
        end if;

        new.challenger_rep_count := session_score;
        new.target_rep_count := session_score + 1;
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

            select user_id, challenge_type, valid_rep_count, duration_seconds
            into session_owner, session_type, session_reps, session_duration
            from public.movement_challenge_sessions
            where id = new.challenged_session_id;

            session_score := case
                when session_type = 'plank' then floor(coalesce(session_duration, 0))::integer
                else coalesce(session_reps, 0)
            end;

            if session_owner is distinct from new.challenged_id
               or session_type is distinct from old.challenge_type
               or session_score < 1 then
                raise exception 'response session does not match this challenge';
            end if;

            new.challenged_rep_count := session_score;
            new.status := 'completed';
            new.completed_at := now();
            new.winner_id := case
                when session_score >= old.target_rep_count then new.challenged_id
                else old.challenger_id
            end;
        end if;
    end if;

    new.updated_at := now();
    return new;
end;
$$;
