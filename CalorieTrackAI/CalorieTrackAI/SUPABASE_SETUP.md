# Supabase Setup Guide for CalTrack AI

This guide will help you integrate Supabase backend with your CalTrack AI Swift app.

## 🚀 Quick Start

### 1. Create Supabase Project

1. Go to [supabase.com](https://supabase.com) and create an account
2. Click "New Project"
3. Choose your organization and enter:
   - **Name**: CalTrack AI
   - **Database Password**: (choose a strong password)
   - **Region**: Choose closest to your users
4. Wait for project creation (2-3 minutes)

### 2. Get Your Credentials

1. In your Supabase dashboard, go to **Settings** → **API**
2. Copy these values:
   - **Project URL**: `https://your-project.supabase.co`
   - **Anon Public Key**: `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...`

### 3. Set Up Database

1. Go to **SQL Editor** in your Supabase dashboard
2. Copy the entire contents of `supabase_setup.sql`
3. Paste and run the SQL query
4. Verify tables were created in **Table Editor**

### 4. Add Supabase to Xcode

1. In Xcode, go to **File** → **Add Package Dependencies**
2. Enter: `https://github.com/supabase/supabase-swift`
3. Choose **Up to Next Major Version** (2.0.0)
4. Click **Add Package**

### 5. Configure Your App

1. Open `Services/SupabaseService.swift`
2. Replace the placeholder values:

```swift
private init() {
    // Replace with your actual Supabase URL and anon key
    let supabaseURL = URL(string: "https://your-project.supabase.co")!
    let supabaseKey = "your-anon-key-here"

    self.client = SupabaseClient(
        supabaseURL: supabaseURL,
        supabaseKey: supabaseKey
    )
    // ... rest of init
}
```

## 🔧 Features Included

### ✅ Authentication

- Email/password signup and login
- Automatic session management
- Password reset functionality
- Row Level Security (RLS) for data protection

### ✅ Data Models

- **MealEntry**: Enhanced food logging with meal types
- **UserProfile**: Complete user profile management
- **FoodItem**: Comprehensive food database
- **NutritionSummary**: Analytics and reporting

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

1. **Push Notifications**: Meal reminders
2. **Image Recognition**: Food photo analysis
3. **HealthKit Integration**: Sync with Apple Health
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

🎉 **Congratulations!** Your CalTrack AI app now has a powerful Supabase backend with user authentication, real-time data sync, and comprehensive nutrition tracking capabilities.
