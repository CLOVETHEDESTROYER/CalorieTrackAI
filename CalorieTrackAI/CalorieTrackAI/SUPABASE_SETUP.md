# Supabase Setup Guide for My Fatness Tracker

This guide will help you integrate the Supabase backend with the My Fatness Tracker Swift app.

## 🚀 Quick Start

### 1. Create Supabase Project

1. Go to [supabase.com](https://supabase.com) and create an account
2. Click "New Project"
3. Choose your organization and enter:
   - **Name**: My Fatness Tracker
   - **Database Password**: (choose a strong password)
   - **Region**: Choose closest to your users
4. Wait for project creation (2-3 minutes)

### 2. Get Your Credentials

1. In your Supabase dashboard, go to **Settings** → **API**
2. Copy these values:
   - **Project URL**: `https://your-project.supabase.co`
   - **Anon Public Key** or **Publishable Key**

Do not use the database password, JWT secret, personal access token, or service role key in the iOS app.

### 3. Set Up Database

1. Go to **SQL Editor** in your Supabase dashboard
2. Copy the entire contents of `supabase_fresh_start.sql`
3. Paste and run the SQL query
4. Verify tables were created in **Table Editor**

The older two-file setup still exists for reference, but new projects should use `supabase_fresh_start.sql`.

The bootstrap enables RLS, grants the signed-in `authenticated` role access to the app tables through Supabase's generated Data API, and keeps `anon` blocked from user-owned data. Coach meal reminders default to enabled so fresh accounts match the app's tough-love breakfast/lunch/dinner accountability behavior.

### 4. Add Supabase to Xcode

1. In Xcode, go to **File** → **Add Package Dependencies**
2. Enter: `https://github.com/supabase/supabase-swift`
3. Choose **Up to Next Major Version** (2.0.0)
4. Click **Add Package**

### 5. Configure Your App

Do not hardcode keys in Swift. From the folder that contains `CalorieTrackAI.xcodeproj`, create `Config.xcconfig` from the template:

```bash
cp CalorieTrackAI/Config.xcconfig.template Config.xcconfig
```

Then set:

```xcconfig
SUPABASE_URL = https:/$()/your-project-id.supabase.co
SUPABASE_PUBLISHABLE_KEY = your-supabase-publishable-key-here
SUPABASE_ANON_KEY = your-supabase-anon-key-here
```

Use `SUPABASE_PUBLISHABLE_KEY` if your dashboard shows a key that starts with `sb_publishable_`. If your dashboard only shows legacy keys, put the anon public key in `SUPABASE_ANON_KEY`. Keep `OPENAI_API_KEY` in Supabase Edge Function secrets for `mft-ai-coach`, never in the iOS app. Never put the service role key in the iOS app. In `.xcconfig`, write Supabase URLs as `https:/$()/your-project-id.supabase.co` so Xcode does not treat `//` as a comment.

### 6. Configure Auth Redirects

In Supabase Dashboard, go to **Authentication** → **URL Configuration** and add this redirect URL:

```text
myfatnesstracker://auth-callback
```

The iOS app registers the `myfatnesstracker` URL scheme and uses that callback for password reset links.

If Apple Developer asks for web callback values while setting up a Services ID, use:

```text
Domain: tlbdjexawwfpeuykumbv.supabase.co
Callback URL: https://tlbdjexawwfpeuykumbv.supabase.co/auth/v1/callback
```

### 7. Configure Sign in with Apple

The iOS app uses native Sign in with Apple and passes Apple's identity token to Supabase.

1. In Apple Developer, enable **Sign in with Apple** for the app identifier `com.hyperlabsAI.CalorieTrackAI`.
2. Regenerate or refresh the provisioning profile Xcode uses for archive so it includes the Apple sign-in entitlement.
3. In Supabase Dashboard, go to **Authentication** → **Providers** → **Apple** for project `tlbdjexawwfpeuykumbv` and enable the provider.
4. Add `com.hyperlabsAI.CalorieTrackAI` to the Apple provider **Client IDs** list. Native iOS-only sign-in uses the app bundle ID and does not require storing an Apple OAuth secret in the iOS app.
5. Test on a real device signed into iCloud. Apple only returns the user's full name on the first authorization, so the app stores that initial name in the profile table when available.

## 🔧 Features Included

### ✅ Authentication

- Email/password signup and login
- Native Sign in with Apple through Supabase Auth
- Automatic session management
- Password reset emails with an in-app new-password sheet
- Row Level Security (RLS) for data protection

### ✅ Data Models

- **MealEntry**: Enhanced food logging with meal types
- **UserProfile**: Complete user profile management
- **FoodItem**: Comprehensive food database
- **CoachUserSettingsRecord**: Coach tone and notification settings
- **FitnessPlanRecord**: Generated meal/workout plans
- **ActivityDailySummaryRecord**: HealthKit-derived daily rollups
- **GymLocationRecord/GymVisitRecord**: Saved gyms and geofence visits
- **PeptideLogRecord**: User-entered peptide logbook calculations

### ✅ Real-time Features

- Live sync across devices
- Automatic data synchronization
- Offline support with sync

### ✅ Food Database

- OpenFoodFacts API integration
- Barcode scanning with database lookup
- Custom food creation
- Smart search functionality

## 📱 Usage Examples

### Authentication

```swift
// Sign up new user
try await SupabaseService.shared.signUp(
    email: "user@example.com",
    password: "password123",
    name: "John Doe"
)

// Sign in existing user
try await SupabaseService.shared.signIn(
    email: "user@example.com",
    password: "password123"
)
```

### Food Logging

```swift
// Create meal entry
let mealEntry = MealEntry(
    food_name: "Banana",
    calories: 89,
    protein: 1.1,
    carbohydrates: 23,
    fat: 0.3,
    meal_type: .breakfast
)

// Save to database
try await SupabaseService.shared.saveMealEntry(mealEntry)
```

### Food Search

```swift
// Search food database
let foods = try await SupabaseService.shared.searchFoods(query: "apple")

// Barcode lookup
let food = try await BarcodeService.shared.lookupFood(barcode: "1234567890")
```

## 🔒 Security Features

### Row Level Security (RLS)

- Users can only access their own data
- Automatic user ID filtering
- Secure API access
- Explicit Data API grants for signed-in users, with anonymous access revoked for user-owned tables

### Data Validation

- Input validation on all fields
- Proper data types and constraints
- Error handling and user feedback

## 🌐 Offline Support

The app includes comprehensive offline support:

1. **Local Storage**: Uses UserDefaults for offline access
2. **Auto-Sync**: Syncs data when connection returns
3. **Fallback**: Works without internet connection
4. **Migration**: Seamlessly moves offline data to Supabase

## 📊 Database Schema

### Tables Created:

- `food_database` - Global food information
- `user_profiles` - User profile data
- `meal_entries` - User's food logs
- `coach_user_settings` - Coach tone and notification preferences
- `fitness_plans` - Generated meal and workout plans
- `activity_daily_summaries` - HealthKit-derived daily activity summaries
- `gym_locations` - User-saved gym geofences
- `gym_visits` - Manual and geofence gym check-ins
- `peptide_logs` - User-entered peptide calculator logs

### Key Features:

- UUID primary keys
- Automatic timestamps
- Data validation constraints
- Performance indexes
- Full-text search capability

## 🔗 API Integration

### OpenFoodFacts Integration

- Automatic barcode lookup
- 170,000+ products database
- Nutritional information
- Automatic caching in Supabase

### Real-time Subscriptions

```swift
// Subscribe to meal entry changes
SupabaseService.shared.subscribeToMealEntries { entries in
    // Update UI with new data
}
```

## 🚨 Troubleshooting

### Common Issues:

1. **"No such table" error**

   - Run the SQL setup script in Supabase dashboard

2. **Authentication errors**

   - Check your Supabase URL and anon key
   - Verify email confirmation settings

3. **Network errors**

   - Check internet connection
   - Verify Supabase project is active

4. **RLS policy errors**
   - Ensure user is authenticated
   - Check policy permissions in Supabase

## 📈 Next Steps

After setup, you can enhance the app with:

1. **Remote Push Notifications**: Server-triggered reminders beyond current local notifications
2. **Image Recognition**: Food photo analysis
3. **Apple Watch App**: Faster coach and logging surfaces
4. **Social Features**: Share progress with friends
5. **Analytics**: Advanced nutrition insights

## 💡 Tips

- Test authentication flow before building UI
- Use the sample data for testing
- Monitor Supabase logs for debugging
- Set up environment variables for production

## 🆘 Support

- [Supabase Documentation](https://supabase.com/docs)
- [Swift Package Documentation](https://github.com/supabase/supabase-swift)
- Check Supabase dashboard logs for errors
- Use the SQL Editor for database queries

---

Your app now has the Supabase backend tables needed for authentication, nutrition tracking, coaching, plans, activity rollups, gym check-ins, and peptide logbook sync.
