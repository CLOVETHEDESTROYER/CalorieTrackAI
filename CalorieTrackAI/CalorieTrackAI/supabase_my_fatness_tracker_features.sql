-- My Fatness Tracker feature tables
-- Run after the base My Fatness Tracker Supabase setup.

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Coach tone and notification preferences. Stored separately from the core
-- profile so App Store-sensitive tone choices remain user-controlled.
CREATE TABLE IF NOT EXISTS coach_user_settings (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    coach_enabled BOOLEAN NOT NULL DEFAULT true,
    severity TEXT NOT NULL DEFAULT 'fullRoast'
        CHECK (severity IN ('mild', 'spicy', 'fullRoast')),
    food_roast_threshold_percent DECIMAL NOT NULL DEFAULT 75
        CHECK (food_roast_threshold_percent >= 0 AND food_roast_threshold_percent <= 100),
    active_start_hour INTEGER NOT NULL DEFAULT 8
        CHECK (active_start_hour >= 0 AND active_start_hour <= 23),
    active_end_hour INTEGER NOT NULL DEFAULT 22
        CHECK (active_end_hour >= 0 AND active_end_hour <= 23),
    allow_explicit_body_shame BOOLEAN NOT NULL DEFAULT true,
    daily_workout_reminder BOOLEAN NOT NULL DEFAULT true,
    meal_reminders BOOLEAN NOT NULL DEFAULT true,
    weekly_reports BOOLEAN NOT NULL DEFAULT true,
    peptide_reminders BOOLEAN NOT NULL DEFAULT true,
    breakfast_time TEXT NOT NULL DEFAULT '08:00',
    lunch_time TEXT NOT NULL DEFAULT '12:30',
    dinner_time TEXT NOT NULL DEFAULT '18:30',
    workout_time TEXT NOT NULL DEFAULT '18:00',
    weekly_report_weekday INTEGER NOT NULL DEFAULT 2
        CHECK (weekly_report_weekday >= 1 AND weekly_report_weekday <= 7),
    weekly_report_time TEXT NOT NULL DEFAULT '08:30',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE coach_user_settings
    ADD COLUMN IF NOT EXISTS peptide_reminders BOOLEAN NOT NULL DEFAULT true;
ALTER TABLE coach_user_settings
    ALTER COLUMN meal_reminders SET DEFAULT true;

-- Local plan builder output. The generated structure is stored as JSONB so the
-- SwiftUI plan can evolve without a migration for every meal/exercise card.
CREATE TABLE IF NOT EXISTS fitness_plans (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    goal TEXT NOT NULL CHECK (goal IN ('lose weight', 'maintain weight', 'gain weight')),
    calorie_target DECIMAL NOT NULL CHECK (calorie_target > 0),
    protein_goal DECIMAL NOT NULL DEFAULT 0 CHECK (protein_goal >= 0),
    carbs_goal DECIMAL NOT NULL DEFAULT 0 CHECK (carbs_goal >= 0),
    fat_goal DECIMAL NOT NULL DEFAULT 0 CHECK (fat_goal >= 0),
    step_goal INTEGER NOT NULL DEFAULT 10000 CHECK (step_goal > 0),
    training_days_per_week INTEGER NOT NULL DEFAULT 4
        CHECK (training_days_per_week >= 1 AND training_days_per_week <= 7),
    plan_payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    coach_note TEXT,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_fitness_plans_user_active
    ON fitness_plans(user_id, is_active, created_at DESC);

-- HealthKit-derived daily rollups. Raw HealthKit samples should stay in Health;
-- this table only stores user-visible daily summaries for cross-device progress.
CREATE TABLE IF NOT EXISTS activity_daily_summaries (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    activity_date DATE NOT NULL,
    steps INTEGER NOT NULL DEFAULT 0 CHECK (steps >= 0),
    step_goal INTEGER NOT NULL DEFAULT 10000 CHECK (step_goal > 0),
    active_energy_calories DECIMAL NOT NULL DEFAULT 0 CHECK (active_energy_calories >= 0),
    exercise_minutes DECIMAL NOT NULL DEFAULT 0 CHECK (exercise_minutes >= 0),
    workout_count INTEGER NOT NULL DEFAULT 0 CHECK (workout_count >= 0),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE (user_id, activity_date)
);

CREATE INDEX IF NOT EXISTS idx_activity_daily_summaries_user_date
    ON activity_daily_summaries(user_id, activity_date DESC);

CREATE TABLE IF NOT EXISTS movement_challenge_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    challenge_type TEXT NOT NULL DEFAULT 'push_up' CHECK (challenge_type IN ('push_up', 'squat', 'jumping_jack', 'plank')),
    started_at TIMESTAMP WITH TIME ZONE NOT NULL,
    ended_at TIMESTAMP WITH TIME ZONE NOT NULL,
    duration_seconds DECIMAL NOT NULL DEFAULT 0 CHECK (duration_seconds >= 0),
    valid_rep_count INTEGER NOT NULL DEFAULT 0 CHECK (valid_rep_count >= 0),
    rejected_rep_count INTEGER NOT NULL DEFAULT 0 CHECK (rejected_rep_count >= 0),
    points_awarded INTEGER NOT NULL DEFAULT 0 CHECK (points_awarded >= 0),
    analysis_version TEXT NOT NULL DEFAULT 'pushup-strict-v1',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_movement_challenge_sessions_user_started
    ON movement_challenge_sessions(user_id, started_at DESC);

CREATE TABLE IF NOT EXISTS gym_locations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    name TEXT NOT NULL,
    chain TEXT,
    address TEXT,
    latitude DECIMAL NOT NULL,
    longitude DECIMAL NOT NULL,
    radius_meters DECIMAL NOT NULL DEFAULT 160 CHECK (radius_meters > 0),
    entrance_latitude DOUBLE PRECISION,
    entrance_longitude DOUBLE PRECISION,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE gym_locations
    ADD COLUMN IF NOT EXISTS address TEXT;

ALTER TABLE gym_locations
    ADD COLUMN IF NOT EXISTS entrance_latitude DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS entrance_longitude DOUBLE PRECISION;

CREATE INDEX IF NOT EXISTS idx_gym_locations_user
    ON gym_locations(user_id, name);

CREATE TABLE IF NOT EXISTS gym_visits (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    gym_location_id UUID REFERENCES gym_locations(id) ON DELETE SET NULL,
    gym_name TEXT NOT NULL,
    arrived_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    departed_at TIMESTAMP WITH TIME ZONE,
    source TEXT NOT NULL DEFAULT 'manual' CHECK (source IN ('manual', 'geofence')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_gym_visits_user_arrived
    ON gym_visits(user_id, arrived_at DESC);

-- GLP/peptide tracker logs. This stores calculations and user-entered notes,
-- not medical recommendations.
CREATE TABLE IF NOT EXISTS peptide_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    peptide_name TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'logged' CHECK (status IN ('logged', 'planned', 'skipped')),
    vial_amount_mg DECIMAL NOT NULL CHECK (vial_amount_mg > 0),
    bac_water_ml DECIMAL NOT NULL CHECK (bac_water_ml > 0),
    label_amount_mcg DECIMAL NOT NULL CHECK (label_amount_mcg > 0),
    draw_volume_ml DECIMAL NOT NULL CHECK (draw_volume_ml > 0),
    syringe_units DECIMAL NOT NULL CHECK (syringe_units > 0),
    site TEXT,
    notes TEXT,
    scheduled_at TIMESTAMP WITH TIME ZONE,
    logged_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE peptide_logs
    ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'logged' CHECK (status IN ('logged', 'planned', 'skipped'));
ALTER TABLE peptide_logs
    ADD COLUMN IF NOT EXISTS site TEXT;
ALTER TABLE peptide_logs
    ADD COLUMN IF NOT EXISTS scheduled_at TIMESTAMP WITH TIME ZONE;

CREATE INDEX IF NOT EXISTS idx_peptide_logs_user_logged
    ON peptide_logs(user_id, logged_at DESC);
CREATE INDEX IF NOT EXISTS idx_peptide_logs_user_status
    ON peptide_logs(user_id, status, logged_at DESC);

-- Data API grants. RLS controls which rows each signed-in user can touch;
-- grants make these tables reachable through Supabase's generated API.
REVOKE ALL ON TABLE
    coach_user_settings,
    fitness_plans,
    activity_daily_summaries,
    movement_challenge_sessions,
    gym_locations,
    gym_visits,
    peptide_logs
FROM anon;

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE
    coach_user_settings,
    fitness_plans,
    activity_daily_summaries,
    movement_challenge_sessions,
    gym_locations,
    gym_visits,
    peptide_logs
TO authenticated;

ALTER TABLE coach_user_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE fitness_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE activity_daily_summaries ENABLE ROW LEVEL SECURITY;
ALTER TABLE movement_challenge_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE gym_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE gym_visits ENABLE ROW LEVEL SECURITY;
ALTER TABLE peptide_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can manage own coach settings" ON coach_user_settings;
CREATE POLICY "Users can manage own coach settings" ON coach_user_settings
    FOR ALL TO authenticated
    USING ((select auth.uid()) = user_id)
    WITH CHECK ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can manage own fitness plans" ON fitness_plans;
CREATE POLICY "Users can manage own fitness plans" ON fitness_plans
    FOR ALL TO authenticated
    USING ((select auth.uid()) = user_id)
    WITH CHECK ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can manage own activity summaries" ON activity_daily_summaries;
CREATE POLICY "Users can manage own activity summaries" ON activity_daily_summaries
    FOR ALL TO authenticated
    USING ((select auth.uid()) = user_id)
    WITH CHECK ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can manage own movement challenge sessions" ON movement_challenge_sessions;
CREATE POLICY "Users can manage own movement challenge sessions" ON movement_challenge_sessions
    FOR ALL TO authenticated
    USING ((select auth.uid()) = user_id)
    WITH CHECK ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can manage own gym locations" ON gym_locations;
CREATE POLICY "Users can manage own gym locations" ON gym_locations
    FOR ALL TO authenticated
    USING ((select auth.uid()) = user_id)
    WITH CHECK ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can manage own gym visits" ON gym_visits;
CREATE POLICY "Users can manage own gym visits" ON gym_visits
    FOR ALL TO authenticated
    USING ((select auth.uid()) = user_id)
    WITH CHECK ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can manage own peptide logs" ON peptide_logs;
CREATE POLICY "Users can manage own peptide logs" ON peptide_logs
    FOR ALL TO authenticated
    USING ((select auth.uid()) = user_id)
    WITH CHECK ((select auth.uid()) = user_id);

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION update_updated_at_column() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS update_coach_user_settings_updated_at ON coach_user_settings;
CREATE TRIGGER update_coach_user_settings_updated_at
    BEFORE UPDATE ON coach_user_settings
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_fitness_plans_updated_at ON fitness_plans;
CREATE TRIGGER update_fitness_plans_updated_at
    BEFORE UPDATE ON fitness_plans
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_activity_daily_summaries_updated_at ON activity_daily_summaries;
CREATE TRIGGER update_activity_daily_summaries_updated_at
    BEFORE UPDATE ON activity_daily_summaries
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_movement_challenge_sessions_updated_at ON movement_challenge_sessions;
CREATE TRIGGER update_movement_challenge_sessions_updated_at
    BEFORE UPDATE ON movement_challenge_sessions
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_gym_locations_updated_at ON gym_locations;
CREATE TRIGGER update_gym_locations_updated_at
    BEFORE UPDATE ON gym_locations
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_gym_visits_updated_at ON gym_visits;
CREATE TRIGGER update_gym_visits_updated_at
    BEFORE UPDATE ON gym_visits
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_peptide_logs_updated_at ON peptide_logs;
CREATE TRIGGER update_peptide_logs_updated_at
    BEFORE UPDATE ON peptide_logs
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
