# CalTrack AI Setup Guide

Complete setup instructions for CalTrack AI with secure API key management.

## 🚀 Quick Start

### 1. Initial Project Setup

1. **Clone the repository**

   ```bash
   git clone <your-repo-url>
   cd CalTrackAI
   ```

2. **Open in Xcode**
   ```bash
   open CalTrackAI.xcodeproj
   ```

### 2. Configure API Keys (Required)

#### Step 1: Create Configuration File

```bash
# In the project root directory
cp Config.xcconfig.template Config.xcconfig
```

#### Step 2: Get Your API Keys

**OpenAI API Key:**

1. Visit [OpenAI Platform](https://platform.openai.com/api-keys)
2. Sign in or create an account
3. Click "Create new secret key"
4. Name it "CalTrack AI"
5. Copy the key (starts with `sk-`)

**Supabase Credentials:**

1. Visit [Supabase Dashboard](https://supabase.com/dashboard)
2. Create a new project or select existing
3. Go to Settings → API
4. Copy your Project URL and anon public key

#### Step 3: Update Configuration

Edit `Config.xcconfig` with your actual keys:

```bash
// CalTrack AI Configuration
OPENAI_API_KEY = sk-proj-your-actual-openai-key-here
SUPABASE_URL = https://your-project-id.supabase.co
SUPABASE_ANON_KEY = your-supabase-anon-key-here
```

### 3. Database Setup

1. **Run Supabase Schema**

   - Open Supabase dashboard
   - Go to SQL Editor
   - Copy contents from `supabase_setup.sql`
   - Execute the SQL

2. **Verify Tables Created**
   - Check Table Editor in Supabase
   - Should see: `food_database`, `user_profiles`, `meal_entries`

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
Config.xcconfig.template # Template with instructions
Info.plist              # Uses variables, no actual keys
.gitignore              # Protects sensitive files
```

## 📁 Project Structure

### Configuration Files

```
CalTrackAI/
├── Config.xcconfig.template    # Template (safe to commit)
├── Config.xcconfig            # Your keys (DO NOT COMMIT)
├── Info.plist                 # Uses $(VARIABLES)
├── .gitignore                 # Protects sensitive files
└── SETUP.md                   # This guide
```

### Core Architecture

```
├── Models/                    # Data structures
├── Views/                     # SwiftUI interfaces
├── ViewModels/               # Business logic
└── Services/                 # API integrations
    ├── SupabaseService.swift # Database & auth
    ├── OpenAIService.swift   # AI features
    ├── FoodService.swift     # Food data
    └── BarcodeService.swift  # Food lookup
```

## 🛠️ Advanced Configuration

### Environment-Specific Configurations

For different environments, create separate config files:

**Config-Debug.xcconfig** (Development):

```bash
OPENAI_API_KEY = sk-your-dev-key
SUPABASE_URL = https://dev-project.supabase.co
```

**Config-Release.xcconfig** (Production):

```bash
OPENAI_API_KEY = sk-your-prod-key
SUPABASE_URL = https://prod-project.supabase.co
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
git add Config.xcconfig.template
git add .gitignore
git add SETUP.md
git add "*.swift"
git add Info.plist
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
- [ ] App builds without errors
- [ ] Authentication works
- [ ] AI analysis responds correctly
- [ ] Food logging saves to database

---

🎉 **You're ready to start developing!** Your CalTrack AI app is now securely configured with all necessary API integrations.
