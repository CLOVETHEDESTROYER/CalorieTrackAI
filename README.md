# CalTrack AI

Smart Calorie Tracker with Voice and Vision

A modern SwiftUI app that uses MVVM architecture, TabView navigation, **Supabase backend**, and **OpenAI GPT integration** to help users track their nutrition goals with AI-powered features.

## Features

- **Dashboard**: View daily progress, calorie consumption, and macronutrient breakdown
- **Food Logging**: Multiple input methods including manual entry, voice input, barcode scanning, and photo recognition
- **AI Meal Analysis**: Describe meals in natural language and get instant nutrition estimates
- **AI Meal Suggestions**: Get personalized daily meal plans based on your goals and preferences
- **History**: Browse past food logs with date filtering and meal categorization
- **Profile Management**: Customize personal information, activity levels, and calorie goals
- **User Authentication**: Secure email/password authentication with Supabase
- **Real-time Sync**: Data synchronization across devices
- **Offline Support**: Works without internet with automatic sync when online

## Project Structure

```
CalTrackAI/
├── CalTrackAIApp.swift          # Main app entry point with Supabase integration
├── ContentView.swift            # Main TabView navigation (includes AI Assistant tab)
├── Info.plist                   # App configuration and permissions
├── supabase_setup.sql           # Database schema for Supabase
├── SUPABASE_SETUP.md           # Complete Supabase setup guide
├── OPENAI_SETUP.md             # Complete OpenAI integration guide
│
├── Models/
│   ├── Food.swift               # Legacy food data model
│   ├── User.swift               # Legacy user profile model
│   └── MealEntry.swift          # Enhanced meal entry model for Supabase
│
├── Views/
│   ├── DashboardView.swift      # Main dashboard
│   ├── LogFoodView.swift        # Food logging interface with AI Quick Analysis
│   ├── AIFoodAnalysisView.swift # Dedicated AI meal analysis and suggestions
│   ├── HistoryView.swift        # Food history browser
│   ├── ProfileView.swift        # User profile management
│   │
│   ├── Auth/
│   │   └── AuthenticationView.swift # Login/signup flow
│   │
│   ├── Components/
│   │   ├── FoodRowView.swift           # Reusable food item display
│   │   └── CircularProgressView.swift  # Progress indicators and macros
│   │
│   └── Supporting/
│       ├── BarcodeScannerView.swift    # Barcode scanning interface
│       ├── EditProfileView.swift      # Profile editing form
│       └── NotificationSettingsView.swift # Settings screens
│
├── ViewModels/
│   ├── DashboardViewModel.swift    # Dashboard business logic
│   ├── LogFoodViewModel.swift      # Food logging logic
│   ├── HistoryViewModel.swift      # History management
│   └── ProfileViewModel.swift      # Profile management
│
└── Services/
    ├── SupabaseService.swift       # Main Supabase integration
    ├── OpenAIService.swift         # OpenAI GPT API integration
    ├── FoodService.swift           # Food data with Supabase backend
    ├── UserService.swift           # User data with Supabase backend
    ├── VoiceService.swift          # Speech recognition
    └── BarcodeService.swift        # Barcode lookup with OpenFoodFacts API
```

## Architecture

This app follows the **MVVM (Model-View-ViewModel)** pattern with **Supabase backend** and **OpenAI AI integration**:

- **Models**: Data structures for `Food`, `User`, `MealEntry`, `UserProfile`, and AI response models
- **Views**: SwiftUI user interface components with authentication flow and AI assistance
- **ViewModels**: Business logic and state management
- **Services**: Supabase integration, OpenAI API calls, data persistence, and external API integration

## Technologies Used

- **SwiftUI**: Modern declarative UI framework
- **Supabase**: PostgreSQL database with real-time subscriptions
- **OpenAI GPT**: AI-powered meal analysis and meal planning
- **Authentication**: Email/password with Row Level Security
- **Speech Framework**: Voice input recognition
- **AVFoundation**: Camera and microphone access
- **OpenFoodFacts API**: Global food database integration
- **UserDefaults**: Offline storage and fallback
- **TabView**: Navigation structure

## AI Features

### 🧠 Intelligent Meal Analysis

- **Natural Language Processing**: "I had grilled chicken with rice and vegetables"
- **Nutrition Estimation**: Automatic calorie and macro calculations
- **Confidence Scoring**: AI provides accuracy estimates (60-95%)
- **Quick Integration**: Results auto-fill the food logging form

### 🍽️ Personalized Meal Suggestions

- **Custom Meal Plans**: Daily suggestions based on your goals
- **Dietary Preferences**: Vegetarian, vegan, gluten-free, keto, etc.
- **Cuisine Variety**: Mediterranean, Asian, American, and more
- **Budget Considerations**: Options for every price range
- **Complexity Levels**: Simple 15-min meals to gourmet cooking

### ⚡ Smart Food Recognition

- **Multi-Food Analysis**: Identify multiple foods in one description
- **Portion Estimation**: AI estimates serving sizes
- **Context Understanding**: Considers cooking methods and ingredients

## Backend Features

### 🔐 Authentication

- Email/password signup and login
- Automatic session management
- Password reset functionality
- Secure Row Level Security (RLS)

### 📊 Database

- **meal_entries**: User's food logs with meal types
- **user_profiles**: Complete user profile management
- **food_database**: Global food information with OpenFoodFacts integration

### 🌐 Real-time & Offline

- Live data synchronization across devices
- Offline support with automatic sync
- Real-time subscriptions for instant updates

## Getting Started

### Prerequisites

- Xcode 14.0 or later
- iOS 15.0+ simulator or device
- OpenAI API account (for AI features)
- Supabase account (free tier available)

### 🚀 Quick Setup

**For detailed setup instructions, see [SETUP.md](SETUP.md)**

1. **Clone the Repository**

   ```bash
   git clone <repository>
   cd CalTrackAI
   ```

2. **Configure API Keys (Secure Method)**

   ```bash
   # Copy the configuration template
   cp Config.xcconfig.template Config.xcconfig

   # Edit Config.xcconfig with your actual API keys
   # - OpenAI: https://platform.openai.com/api-keys
   # - Supabase: https://supabase.com/dashboard
   ```

3. **Setup Database**

   - Create Supabase project
   - Run SQL schema from `supabase_setup.sql`
   - Verify tables created

4. **Build and Test**
   - Open project in Xcode
   - Build and run
   - Test AI features and data sync

**🔒 Security Note**: API keys are stored securely in `Config.xcconfig` (gitignored) and loaded via Xcode build configuration.

## Features in Detail

### 🍎 Food Logging

- **Barcode Scanning**: Instant food lookup with OpenFoodFacts API
- **Voice Input**: "I ate a banana for breakfast"
- **Manual Entry**: Complete nutrition information
- **Photo Recognition**: AI-powered food identification (coming soon)

### 📈 Analytics

- Daily calorie and macro tracking
- Weekly/monthly nutrition summaries
- Progress visualization with charts
- Streak tracking and achievements

### 👤 User Management

- Personalized calorie goals based on BMR calculation
- Activity level and goal type customization
- Profile synchronization across devices
- Data export and privacy controls

## API Integration

### OpenFoodFacts API

- 170,000+ verified food products
- Automatic barcode lookup
- Nutritional information caching
- Global food database access

### Supabase Features Used

- **Authentication**: Email verification and session management
- **Database**: PostgreSQL with real-time subscriptions
- **Storage**: Future support for food images
- **Edge Functions**: Server-side nutrition calculations

## Future Enhancements

- **Core ML Integration**: On-device food image recognition
- **HealthKit Sync**: Integration with Apple Health
- **Apple Watch App**: Quick food logging from wrist
- **Social Features**: Share progress and challenges with friends
- **Advanced Analytics**: Detailed nutrition insights and recommendations
- **Push Notifications**: Meal reminders and goal celebrations

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## Security

- All user data is protected by Supabase Row Level Security
- Authentication tokens are automatically managed
- API keys are properly configured for client-side use
- Data validation and sanitization on all inputs

---

🎉 **Ready to track your nutrition journey with AI?** Follow the setup guide and start logging your meals today!
