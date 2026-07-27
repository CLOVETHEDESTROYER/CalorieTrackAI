create index if not exists shared_challenge_invites_session_idx
    on public.shared_challenge_invites (challenger_session_id);
