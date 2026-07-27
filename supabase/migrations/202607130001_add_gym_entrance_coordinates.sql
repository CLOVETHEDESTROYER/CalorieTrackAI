-- Preserve the MapKit place as the saved gym and optionally store the exact
-- user-confirmed entrance used by the strict automatic arrival policy.
ALTER TABLE public.gym_locations
    ADD COLUMN IF NOT EXISTS address TEXT,
    ADD COLUMN IF NOT EXISTS entrance_latitude DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS entrance_longitude DOUBLE PRECISION;
