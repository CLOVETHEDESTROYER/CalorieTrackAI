create index if not exists fitness_challenges_challenger_session_idx
    on public.fitness_challenges (challenger_session_id);
create index if not exists fitness_challenges_challenged_session_idx
    on public.fitness_challenges (challenged_session_id)
    where challenged_session_id is not null;
create index if not exists fitness_challenges_winner_idx
    on public.fitness_challenges (winner_id)
    where winner_id is not null;
