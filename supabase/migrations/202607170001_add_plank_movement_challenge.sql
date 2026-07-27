set lock_timeout = '5s';

alter table public.movement_challenge_sessions
    drop constraint if exists movement_challenge_sessions_challenge_type_check;

alter table public.movement_challenge_sessions
    add constraint movement_challenge_sessions_challenge_type_check
    check (challenge_type in ('push_up', 'squat', 'jumping_jack', 'plank'))
    not valid;

alter table public.movement_challenge_sessions
    validate constraint movement_challenge_sessions_challenge_type_check;
