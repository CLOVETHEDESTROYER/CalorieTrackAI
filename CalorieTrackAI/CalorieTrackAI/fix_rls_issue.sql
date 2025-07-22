-- Fix RLS Issue for User Registration
-- Run this in your Supabase SQL Editor

-- RPC function to create initial user profile (bypasses RLS)
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
SECURITY DEFINER
AS $$
BEGIN
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
        p_user_id::UUID,
        p_name,
        p_age::INTEGER,
        p_weight::DECIMAL,
        p_height::DECIMAL,
        p_activity_level,
        p_goal_type,
        p_daily_calorie_goal::DECIMAL
    );
END;
$$; 