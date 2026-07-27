-- My Fatness Tracker fresh Supabase bootstrap
-- Run this once in a new Supabase project's SQL Editor.
-- Safe to rerun for policy/function/index refreshes, but it does not migrate
-- incompatible existing tables. Use it for fresh projects or empty databases.

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- MARK: - Core Food Tracker Tables

CREATE TABLE IF NOT EXISTS food_database (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    brand TEXT,
    barcode TEXT UNIQUE,
    calories_per_100g DECIMAL NOT NULL CHECK (calories_per_100g >= 0),
    protein_per_100g DECIMAL DEFAULT 0 CHECK (protein_per_100g >= 0),
    carbohydrates_per_100g DECIMAL DEFAULT 0 CHECK (carbohydrates_per_100g >= 0),
    fat_per_100g DECIMAL DEFAULT 0 CHECK (fat_per_100g >= 0),
    fiber_per_100g DECIMAL CHECK (fiber_per_100g >= 0),
    sugar_per_100g DECIMAL CHECK (sugar_per_100g >= 0),
    sodium_per_100g DECIMAL CHECK (sodium_per_100g >= 0),
    verified BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS user_profiles (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    age INTEGER CHECK (age > 0 AND age < 150),
    weight DECIMAL CHECK (weight > 0),
    height DECIMAL CHECK (height > 0),
    activity_level TEXT DEFAULT 'sedentary'
        CHECK (activity_level IN ('sedentary', 'lightly active', 'moderately active', 'very active')),
    goal_type TEXT DEFAULT 'maintain'
        CHECK (goal_type IN ('lose weight', 'maintain weight', 'gain weight')),
    daily_calorie_goal DECIMAL DEFAULT 2000 CHECK (daily_calorie_goal > 0),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS meal_entries (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    food_id UUID REFERENCES food_database(id),
    food_name TEXT NOT NULL,
    calories DECIMAL NOT NULL CHECK (calories >= 0),
    protein DECIMAL DEFAULT 0 CHECK (protein >= 0),
    carbohydrates DECIMAL DEFAULT 0 CHECK (carbohydrates >= 0),
    fat DECIMAL DEFAULT 0 CHECK (fat >= 0),
    serving_size TEXT DEFAULT '100g',
    serving_quantity DECIMAL DEFAULT 1.0 CHECK (serving_quantity > 0),
    meal_type TEXT DEFAULT 'snack'
        CHECK (meal_type IN ('breakfast', 'lunch', 'dinner', 'snack')),
    consumed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    notes TEXT,
    image_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- MARK: - My Fatness Tracker Feature Tables

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

-- MARK: - Indexes

CREATE INDEX IF NOT EXISTS idx_food_database_barcode ON food_database(barcode);
CREATE INDEX IF NOT EXISTS idx_food_database_name
    ON food_database USING gin(to_tsvector('english', name));
CREATE INDEX IF NOT EXISTS idx_meal_entries_user_consumed
    ON meal_entries(user_id, consumed_at DESC);
CREATE INDEX IF NOT EXISTS idx_meal_entries_user_meal_type
    ON meal_entries(user_id, meal_type);
CREATE INDEX IF NOT EXISTS idx_meal_entries_food_id
    ON meal_entries(food_id);
CREATE INDEX IF NOT EXISTS idx_fitness_plans_user_active
    ON fitness_plans(user_id, is_active, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_activity_daily_summaries_user_date
    ON activity_daily_summaries(user_id, activity_date DESC);
CREATE INDEX IF NOT EXISTS idx_gym_locations_user
    ON gym_locations(user_id, name);
CREATE INDEX IF NOT EXISTS idx_gym_visits_user_arrived
    ON gym_visits(user_id, arrived_at DESC);
CREATE INDEX IF NOT EXISTS idx_gym_visits_location
    ON gym_visits(gym_location_id);
CREATE INDEX IF NOT EXISTS idx_peptide_logs_user_logged
    ON peptide_logs(user_id, logged_at DESC);
CREATE INDEX IF NOT EXISTS idx_peptide_logs_user_status
    ON peptide_logs(user_id, status, logged_at DESC);
CREATE INDEX IF NOT EXISTS idx_movement_challenge_sessions_user_started
    ON movement_challenge_sessions(user_id, started_at DESC);

-- MARK: - Data API Grants

REVOKE ALL ON TABLE
    food_database,
    user_profiles,
    meal_entries,
    coach_user_settings,
    fitness_plans,
    activity_daily_summaries,
    movement_challenge_sessions,
    gym_locations,
    gym_visits,
    peptide_logs
FROM anon;

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE
    user_profiles,
    meal_entries,
    coach_user_settings,
    fitness_plans,
    activity_daily_summaries,
    movement_challenge_sessions,
    gym_locations,
    gym_visits,
    peptide_logs
TO authenticated;

GRANT SELECT, INSERT ON TABLE food_database TO authenticated;

-- MARK: - Row Level Security

ALTER TABLE food_database ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE meal_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE coach_user_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE fitness_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE activity_daily_summaries ENABLE ROW LEVEL SECURITY;
ALTER TABLE movement_challenge_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE gym_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE gym_visits ENABLE ROW LEVEL SECURITY;
ALTER TABLE peptide_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can read food database" ON food_database;
CREATE POLICY "Authenticated users can read food database" ON food_database
    FOR SELECT TO authenticated
    USING (true);

DROP POLICY IF EXISTS "Authenticated users can add foods" ON food_database;
CREATE POLICY "Authenticated users can add foods" ON food_database
    FOR INSERT TO authenticated
    WITH CHECK (verified = false);

DROP POLICY IF EXISTS "Users can view own profile" ON user_profiles;
CREATE POLICY "Users can view own profile" ON user_profiles
    FOR SELECT TO authenticated
    USING ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can insert own profile" ON user_profiles;
CREATE POLICY "Users can insert own profile" ON user_profiles
    FOR INSERT TO authenticated
    WITH CHECK ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can update own profile" ON user_profiles;
CREATE POLICY "Users can update own profile" ON user_profiles
    FOR UPDATE TO authenticated
    USING ((select auth.uid()) = user_id)
    WITH CHECK ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can delete own profile" ON user_profiles;
CREATE POLICY "Users can delete own profile" ON user_profiles
    FOR DELETE TO authenticated
    USING ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can manage own meal entries" ON meal_entries;
CREATE POLICY "Users can manage own meal entries" ON meal_entries
    FOR ALL TO authenticated
    USING ((select auth.uid()) = user_id)
    WITH CHECK ((select auth.uid()) = user_id);

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

-- MARK: - Functions And Triggers

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

CREATE OR REPLACE FUNCTION create_user_profile(
    p_user_id TEXT,
    p_name TEXT,
    p_age TEXT,
    p_weight TEXT,
    p_height TEXT,
    p_activity_level TEXT DEFAULT 'sedentary',
    p_goal_type TEXT DEFAULT 'maintain',
    p_daily_calorie_goal TEXT DEFAULT '2000'
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, auth
AS $$
DECLARE
    requested_user_id UUID := p_user_id::UUID;
BEGIN
    IF requested_user_id <> (select auth.uid()) THEN
        RAISE EXCEPTION 'Cannot create a profile for another user';
    END IF;

    INSERT INTO user_profiles (
        user_id,
        name,
        age,
        weight,
        height,
        activity_level,
        goal_type,
        daily_calorie_goal
    ) VALUES (
        requested_user_id,
        p_name,
        p_age::INTEGER,
        p_weight::DECIMAL,
        p_height::DECIMAL,
        p_activity_level,
        p_goal_type,
        p_daily_calorie_goal::DECIMAL
    )
    ON CONFLICT (user_id) DO UPDATE SET
        name = EXCLUDED.name,
        age = EXCLUDED.age,
        weight = EXCLUDED.weight,
        height = EXCLUDED.height,
        activity_level = EXCLUDED.activity_level,
        goal_type = EXCLUDED.goal_type,
        daily_calorie_goal = EXCLUDED.daily_calorie_goal,
        updated_at = NOW();
END;
$$;

CREATE OR REPLACE FUNCTION search_foods(search_query TEXT)
RETURNS TABLE (
    id UUID,
    name TEXT,
    brand TEXT,
    barcode TEXT,
    calories_per_100g DECIMAL,
    protein_per_100g DECIMAL,
    carbohydrates_per_100g DECIMAL,
    fat_per_100g DECIMAL,
    fiber_per_100g DECIMAL,
    sugar_per_100g DECIMAL,
    sodium_per_100g DECIMAL,
    verified BOOLEAN,
    created_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        f.id,
        f.name,
        f.brand,
        f.barcode,
        f.calories_per_100g,
        f.protein_per_100g,
        f.carbohydrates_per_100g,
        f.fat_per_100g,
        f.fiber_per_100g,
        f.sugar_per_100g,
        f.sodium_per_100g,
        f.verified,
        f.created_at
    FROM food_database f
    WHERE
        f.name ILIKE '%' || search_query || '%'
        OR f.brand ILIKE '%' || search_query || '%'
    ORDER BY
        CASE WHEN f.verified THEN 0 ELSE 1 END,
        f.name;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;

REVOKE ALL ON FUNCTION update_updated_at_column() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION create_user_profile(TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION search_foods(TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION create_user_profile(TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION search_foods(TEXT) TO authenticated;

DROP TRIGGER IF EXISTS update_user_profiles_updated_at ON user_profiles;
CREATE TRIGGER update_user_profiles_updated_at
    BEFORE UPDATE ON user_profiles
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_meal_entries_updated_at ON meal_entries;
CREATE TRIGGER update_meal_entries_updated_at
    BEFORE UPDATE ON meal_entries
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_food_database_updated_at ON food_database;
CREATE TRIGGER update_food_database_updated_at
    BEFORE UPDATE ON food_database
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

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

-- MARK: - Starter Foods

INSERT INTO food_database (
    name,
    brand,
    barcode,
    calories_per_100g,
    protein_per_100g,
    carbohydrates_per_100g,
    fat_per_100g,
    verified
) VALUES
    ('Red Apple', 'Fresh Produce', '1234567890', 52, 0.3, 14, 0.2, true),
    ('Banana', 'Fresh Produce', '0987654321', 89, 1.1, 23, 0.3, true),
    ('Greek Yogurt', 'Dairy Co.', '1122334455', 76, 8.8, 5.3, 2.7, true),
    ('Brown Rice', 'Grain Co.', '5544332211', 362, 7.9, 77, 2.9, true),
    ('Chicken Breast', 'Poultry Farm', '9988776655', 165, 31, 0, 3.6, true),
    ('Broccoli', 'Green Vegetables', '1357924680', 34, 2.8, 7, 0.4, true),
    ('Almonds', 'Nuts & More', '2468135790', 579, 21, 22, 50, true),
    ('Salmon Fillet', 'Ocean Fresh', '1122334456', 208, 20, 0, 13, true)
ON CONFLICT (barcode) DO UPDATE SET
    name = EXCLUDED.name,
    brand = EXCLUDED.brand,
    calories_per_100g = EXCLUDED.calories_per_100g,
    protein_per_100g = EXCLUDED.protein_per_100g,
    carbohydrates_per_100g = EXCLUDED.carbohydrates_per_100g,
    fat_per_100g = EXCLUDED.fat_per_100g,
    verified = EXCLUDED.verified,
    updated_at = NOW();
