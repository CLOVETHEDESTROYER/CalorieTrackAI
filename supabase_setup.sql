-- CalTrack AI Supabase Database Schema
-- Run this SQL in your Supabase SQL Editor to set up the database

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Food database table (global food information)
CREATE TABLE food_database (
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

-- User profiles table
CREATE TABLE user_profiles (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    age INTEGER CHECK (age > 0 AND age < 150),
    weight DECIMAL CHECK (weight > 0),
    height DECIMAL CHECK (height > 0),
    activity_level TEXT DEFAULT 'sedentary' CHECK (activity_level IN ('sedentary', 'lightly active', 'moderately active', 'very active')),
    goal_type TEXT DEFAULT 'maintain' CHECK (goal_type IN ('lose weight', 'maintain weight', 'gain weight')),
    daily_calorie_goal DECIMAL DEFAULT 2000 CHECK (daily_calorie_goal > 0),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Meal entries table (user's food logs)
CREATE TABLE meal_entries (
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
    meal_type TEXT DEFAULT 'snack' CHECK (meal_type IN ('breakfast', 'lunch', 'dinner', 'snack')),
    consumed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    notes TEXT,
    image_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for better performance
CREATE INDEX idx_food_database_barcode ON food_database(barcode);
CREATE INDEX idx_food_database_name ON food_database USING gin(to_tsvector('english', name));
CREATE INDEX idx_meal_entries_user_consumed ON meal_entries(user_id, consumed_at);
CREATE INDEX idx_meal_entries_user_meal_type ON meal_entries(user_id, meal_type);

-- Row Level Security (RLS) policies
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE meal_entries ENABLE ROW LEVEL SECURITY;

-- User profiles policies
CREATE POLICY "Users can view own profile" ON user_profiles
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own profile" ON user_profiles
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own profile" ON user_profiles
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own profile" ON user_profiles
    FOR DELETE USING (auth.uid() = user_id);

-- Meal entries policies
CREATE POLICY "Users can view own meal entries" ON meal_entries
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own meal entries" ON meal_entries
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own meal entries" ON meal_entries
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own meal entries" ON meal_entries
    FOR DELETE USING (auth.uid() = user_id);

-- Food database is readable by all authenticated users
CREATE POLICY "Authenticated users can read food database" ON food_database
    FOR SELECT USING (auth.role() = 'authenticated');

-- Only authenticated users can add to food database
CREATE POLICY "Authenticated users can add foods" ON food_database
    FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- Functions and triggers
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Add updated_at triggers
CREATE TRIGGER update_user_profiles_updated_at 
    BEFORE UPDATE ON user_profiles 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_meal_entries_updated_at 
    BEFORE UPDATE ON meal_entries 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_food_database_updated_at 
    BEFORE UPDATE ON food_database 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- Insert some sample food data
INSERT INTO food_database (name, brand, barcode, calories_per_100g, protein_per_100g, carbohydrates_per_100g, fat_per_100g, verified) VALUES
('Red Apple', 'Fresh Produce', '1234567890', 52, 0.3, 14, 0.2, true),
('Banana', 'Fresh Produce', '0987654321', 89, 1.1, 23, 0.3, true),
('Greek Yogurt', 'Dairy Co.', '1122334455', 76, 8.8, 5.3, 2.7, true),
('Brown Rice', 'Grain Co.', '5544332211', 362, 7.9, 77, 2.9, true),
('Chicken Breast', 'Poultry Farm', '9988776655', 165, 31, 0, 3.6, true),
('Broccoli', 'Green Vegetables', '1357924680', 34, 2.8, 7, 0.4, true),
('Almonds', 'Nuts & More', '2468135790', 579, 21, 22, 50, true),
('Salmon Fillet', 'Ocean Fresh', '1122334456', 208, 20, 0, 13, true);

-- Create a function to search foods by name
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
$$ LANGUAGE plpgsql SECURITY DEFINER; 