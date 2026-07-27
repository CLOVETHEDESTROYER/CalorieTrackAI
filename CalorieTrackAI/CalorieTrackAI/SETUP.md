# My Fatness Tracker Setup Guide

Complete setup instructions for My Fatness Tracker with secure API key management.

## 🚀 Quick Start

### 1. Initial Project Setup

1. **Clone the repository**

   ```bash
   git clone <your-repo-url>
   cd CalorieTrackAI/CalorieTrackAI
   ```

2. **Open in Xcode**
   ```bash
   open CalorieTrackAI.xcodeproj
   ```

### 2. Configure API Keys (Required)

#### Step 1: Create Configuration File

```bash
# From the folder that contains CalorieTrackAI.xcodeproj
cp CalorieTrackAI/Config.xcconfig.template Config.xcconfig
```

#### Step 2: Get Your API Keys

**OpenAI API Key:**

1. Visit [OpenAI Platform](https://platform.openai.com/api-keys)
2. Sign in or create an account
3. Click "Create new secret key"
4. Name it "My Fatness Tracker"
5. Copy the key (starts with `sk-`)

**Supabase Credentials:**

1. Visit [Supabase Dashboard](https://supabase.com/dashboard)
2. Create a new project or select existing
3. Go to Settings → API
4. Copy your Project URL and anon public key or publishable key

Never use the database password, JWT secret, personal access token, or service role key in the iOS app.

#### Step 3: Update Configuration

Edit `Config.xcconfig` with your actual keys:

```bash
// My Fatness Tracker Configuration
SUPABASE_URL = https:/$()/your-project-id.supabase.co
SUPABASE_PUBLISHABLE_KEY = your-supabase-publishable-key-here
SUPABASE_ANON_KEY = your-supabase-anon-key-here
```

Use `SUPABASE_PUBLISHABLE_KEY` for Supabase's newer `sb_publishable_...` keys. Use `SUPABASE_ANON_KEY` only if your dashboard shows legacy anon keys. In `.xcconfig`, write Supabase URLs as `https:/$()/your-project-id.supabase.co` so Xcode does not treat `//` as a comment.

Put the real OpenAI key in Supabase **Edge Functions > Secrets** as `OPENAI_API_KEY` and deploy `mft-ai-coach` with JWT verification enabled. Do not put OpenAI keys in the iOS app bundle.

### 3. Database Setup

1. **Run Supabase Schema**

   - Open Supabase dashboard
   - Go to SQL Editor
   - Copy contents from `supabase_fresh_start.sql`
   - Execute the SQL

2. **Verify Tables Created**
   - Check Table Editor in Supabase
   - Should see base tables: `food_database`, `user_profiles`, `meal_entries`
   - Should see feature tables: `coach_user_settings`, `fitness_plans`, `activity_daily_summaries`, `gym_locations`, `gym_visits`, `peptide_logs`

### 4. Build and Test

1. **Build the project** in Xcode
2. **Run on simulator** or device
3. **Test features:**
   - Create account in app
   - Try AI meal analysis
   - Add some food logs
   - Check data sync

## 🔒 Security Features

### API Key Protection

- ✅ API keys stored in `Config.xcconfig` (not committed to Git)
- ✅ Template file provided for easy setup
- ✅ Comprehensive `.gitignore` prevents accidental commits
- ✅ Runtime validation with helpful error messages

### What's Protected

```
Config.xcconfig          # Your actual API keys (gitignored)
*.xcconfig              # All config files (gitignored)
.env                    # Environment files (gitignored)
```

### What's Safe to Commit

```
CalorieTrackAI/Config.xcconfig.template # Template with instructions
Info.plist              # Uses variables, no actual keys
.gitignore              # Protects sensitive files
```

## 📁 Project Structure

### Configuration Files

```
CalorieTrackAI/
├── CalorieTrackAI.xcodeproj
├── Config.xcconfig            # Your keys (DO NOT COMMIT)
├── CalorieTrackAI/
│   ├── Config.xcconfig.template # Template (safe to commit)
│   ├── Info.plist              # Uses $(VARIABLES)
│   ├── PrivacyInfo.xcprivacy   # App privacy manifest
│   ├── TESTFLIGHT_CHECKLIST.md # Archive and release readiness checklist
│   └── SETUP.md                # This guide
```

The local config lives beside `CalorieTrackAI.xcodeproj` because the Xcode project's base configuration points to `Config.xcconfig` from that folder.

### Core Architecture

```
├── Models/                    # Data structures
├── Views/                     # SwiftUI interfaces
├── ViewModels/               # Business logic
└── Services/                 # API integrations
    ├── SupabaseService.swift # Database & auth
    ├── OpenAIService.swift   # AI features
    ├── HealthKitService.swift # Apple Health activity reads
    ├── GymLocationService.swift # Gym geofences and visits
    ├── FitnessPlanService.swift # Meal/workout plans
    ├── CoachMessageService.swift # Tough-love coach messages
    ├── CoachNotificationService.swift # Local reminders
    ├── PeptideLogStore.swift # Peptide logbook storage
    ├── FoodService.swift     # Food data
    └── BarcodeService.swift  # Food lookup
```

## 🛠️ Advanced Configuration

### Environment-Specific Configurations

For different environments, create separate config files:

**Config-Debug.xcconfig** (Development):

```bash
SUPABASE_URL = https:/$()/dev-project.supabase.co
SUPABASE_PUBLISHABLE_KEY = your-dev-publishable-key
```

**Config-Release.xcconfig** (Production):

```bash
SUPABASE_URL = https:/$()/prod-project.supabase.co
SUPABASE_PUBLISHABLE_KEY = your-prod-publishable-key
```

### Team Setup

1. **Share the template** (committed to Git)
2. **Each developer** creates their own `Config.xcconfig`
3. **Never commit** actual API keys
4. **Use team credentials** or individual dev keys

## 🚨 Troubleshooting

### "Supabase configuration missing" Error

```
⚠️ Supabase configuration missing!
```

**Solution:**

1. Ensure `Config.xcconfig` exists
2. Check Supabase URL and key are correct
3. Verify no typos in variable names

### Password Reset Link Does Not Open the App

In Supabase Dashboard, go to **Authentication** → **URL Configuration** and add:

```text
myfatnesstracker://auth-callback
```

The app registers this URL scheme in `Info.plist` and uses it for Supabase password recovery callbacks.

### "OpenAI API key not configured" Warning

```
⚠️ OpenAI API key not configured!
AI features will be disabled until configured.
```

**Solution:**

1. Get API key from OpenAI Platform
2. Add to `Config.xcconfig`
3. Restart app

### Build Errors

- **Clean build folder**: Product → Clean Build Folder
- **Check config file**: Ensure `Config.xcconfig` exists and has correct format
- **Verify Xcode settings**: Check build configuration is pointing to config file

### Runtime Issues

- **Check network connection**
- **Verify API keys are valid**
- **Monitor API usage limits**
- **Check Supabase project status**

## 💰 Cost Management

### OpenAI Usage

- **Model**: GPT-4o-mini (cost-optimized)
- **Estimated cost**: $5-15/month for regular use
- **Monitor usage**: [OpenAI Usage Dashboard](https://platform.openai.com/usage)

### Supabase Usage

- **Free tier**: 500MB database, 2GB bandwidth
- **Upgrade**: $25/month for larger apps
- **Monitor**: Supabase Dashboard → Settings → Usage

## 🔄 Version Control Best Practices

### What to Commit

```bash
git add CalorieTrackAI/Config.xcconfig.template
git add .gitignore
git add CalorieTrackAI/SETUP.md
git add CalorieTrackAI/TESTFLIGHT_CHECKLIST.md
git add "CalorieTrackAI/*.swift" "CalorieTrackAI/Models/*.swift" "CalorieTrackAI/Services/*.swift" "CalorieTrackAI/Views/**/*.swift"
git add CalorieTrackAI/Info.plist CalorieTrackAI/PrivacyInfo.xcprivacy
```

### What NOT to Commit

```bash
# These should be gitignored automatically
Config.xcconfig
*.xcconfig
.env
secrets.plist
```

### Pre-commit Checklist

- [ ] No API keys in committed files
- [ ] `Config.xcconfig` is gitignored
- [ ] Template file is up to date
- [ ] Setup guide reflects current process

## 📖 Additional Resources

- [Supabase Setup Guide](SUPABASE_SETUP.md)
- [OpenAI Setup Guide](OPENAI_SETUP.md)
- [OpenAI Platform](https://platform.openai.com)
- [Supabase Documentation](https://supabase.com/docs)

## ✅ Verification Checklist

Before starting development:

- [ ] `Config.xcconfig` created and configured
- [ ] Supabase database schema deployed
- [ ] Supabase feature schema deployed
- [ ] App builds without errors
- [ ] Authentication works
- [ ] AI analysis responds correctly
- [ ] Food logging saves to database
- [ ] Coach settings, plans, activity summaries, gym visits, and peptide logs save after login

---

Your app is now securely configured with the required API integrations.
