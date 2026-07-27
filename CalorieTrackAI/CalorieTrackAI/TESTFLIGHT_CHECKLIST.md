# TestFlight Readiness Checklist

Use this before creating the signed archive for My Fatness Tracker.

## Local Configuration

- From the folder that contains `CalorieTrackAI.xcodeproj`, create `Config.xcconfig` with `cp CalorieTrackAI/Config.xcconfig.template Config.xcconfig`.
- Set `SUPABASE_URL` and either `SUPABASE_PUBLISHABLE_KEY` or `SUPABASE_ANON_KEY`.
- Use the Supabase publishable key or legacy anon public key only. Never ship the service role key.
- For TestFlight AI meal analysis and meal planning, set `OPENAI_API_KEY` in Supabase **Edge Functions > Secrets**, not in the iOS app bundle.
- Deploy the `mft-ai-coach` Edge Function with JWT verification enabled so signed-in users call OpenAI through Supabase.
- Confirm the archived app Info.plist does not contain `OPENAI_API_KEY` or an `sk-` OpenAI key.
- Confirm `Config.xcconfig` remains gitignored.
- `MFT_UNLOCK_FEATURES_FOR_TESTING` is currently enabled in `Info.plist` so TestFlight can exercise manual food logging before subscription gates are added back.

## Supabase Migration

For a new project, run this in the Supabase SQL editor:

1. `supabase_fresh_start.sql`

The older `supabase_setup.sql` plus `supabase_my_fatness_tracker_features.sql` path is kept for reference, but the fresh-start script is the one to use for a clean project.

In Supabase Auth URL Configuration, add this redirect URL for password reset and email auth callbacks:

- `myfatnesstracker://auth-callback`

For native Sign in with Apple:

- Enable **Sign in with Apple** on the Apple Developer App ID for `com.hyperlabsAI.CalorieTrackAI`.
- Refresh the provisioning profile used for archive so it contains the Sign in with Apple entitlement.
- In Supabase Dashboard, enable **Authentication > Providers > Apple** for project `tlbdjexawwfpeuykumbv`.
- In the Apple provider **Client IDs** list, add `com.hyperlabsAI.CalorieTrackAI`. The iOS app sends Apple's native identity token to Supabase using this bundle ID.
- If Apple Developer asks for web settings while configuring a Services ID, use domain `tlbdjexawwfpeuykumbv.supabase.co` and return/callback URL `https://tlbdjexawwfpeuykumbv.supabase.co/auth/v1/callback`.
- Native iOS-only Sign in with Apple does not require adding an Apple OAuth secret to the app.
- Test on a real iPhone signed into iCloud. Apple only sends the user's full name on the first authorization.

Verify these feature tables exist:

- `coach_user_settings`
- `fitness_plans`
- `activity_daily_summaries`
- `gym_locations`
- `gym_visits`
- `peptide_logs`

Verify the Edge Function exists:

- `mft-ai-coach` with `verify_jwt = true`
- Supabase secret `OPENAI_API_KEY`

After logging into the app, smoke test:

- Coach tone settings save and reload.
- Password reset email opens the app and shows the new-password sheet.
- Notification settings save and reload.
- Plan builder saves a generated plan.
- Activity tab syncs a daily summary after Health permission is granted.
- Gym location save creates a geofence and syncs the gym.
- Peptide / GLP logbook math saves and reloads.
- Planned peptide / GLP log entries schedule local log reminders when notification permission and peptide reminders are enabled.

## Real Device Pass

HealthKit and region monitoring are not fully proven by simulator builds. Test on an iPhone before upload:

- Guest/dev mode:
  - Launch while signed out and confirm the "Testing Mode" notice appears on the Log tab.
  - Confirm manual food logging is usable while signed out when `MFT_UNLOCK_FEATURES_FOR_TESTING` is enabled.
- Food logging:
  - Tap **Log > Manual Confession > Food name** and confirm the keyboard appears and text can be typed.
  - Enter a food name, calories, and serving size, then confirm **Log It Anyway** saves the food offline if signed out.
  - Tap **Voice Log**, speak a food name, confirm the live transcript appears, then tap **Stop Voice** and confirm the transcript fills the food name field.
  - Repeat voice logging and let the 10-second timeout finish; confirm the partial transcript is still kept instead of disappearing.
  - Deny microphone or speech permission once and confirm the app shows a clear Voice Log Problem alert.
- Sign in:
  - Confirm **Sign Up / Log In** exposes native Sign in with Apple on a real iPhone signed into iCloud.
  - Sign in with Apple and confirm food logs, coach settings, plans, gym locations, and peptide logs can sync.
- Health permission prompt appears and allows reading steps, workouts, active energy, and exercise minutes.
- Apple Watch data appears in Apple Health, then appears in the Activity tab after sync.
- Location permission prompt appears for gym features, including Always access when enabling saved-gym geofence check-ins.
- Gym check-ins:
  - Search nearby gyms while standing near the intended location and save the exact matching gym result, using address and distance to avoid picking another nearby chain location.
  - Tap **Check Where I Am** and confirm **Last Check-In Test** shows the matched gym, distance, radius, and whether a receipt was logged.
  - Confirm the Saved Gyms header shows **Monitoring X/Y** after Always location access is granted.
  - Enter a saved gym's radius and confirm an automatic **Location check-in** appears in Today's Gym Receipts.
  - Tap **Check Where I Am** again after the first receipt and confirm the diagnostic explains that today's receipt already exists instead of logging duplicates.
  - Test from outside the saved radius and confirm the diagnostic explains the nearest saved gym distance and says no auto check-in happened yet.
- Local coach reminders request notification permission and schedule after opt-in.
- Notification checks:
  - Enable **Profile > Notifications > Workout Accountability** and confirm the settings copy mentions 40-minute movement nudges, step goal checks, and gym receipt reminders.
  - With Health access enabled, walk for a bit, then confirm the next movement nudge is pushed out instead of firing immediately.
  - Leave breakfast/lunch/dinner unlogged past the configured time and confirm the missing-meal reminder uses tough-love copy.
  - Log the meal, reopen Notification settings, and confirm the matching missing-meal reminder is not still pending.
  - Finish the day below step goal and without a gym/workout receipt; confirm step-goal and gym-receipt reminders are scheduled.
- Planned peptide reminders appear as local log prompts only, not medical or dosing guidance.

## App Review Notes

Use review notes that explain:

- The coach tone is user-configurable and can be softened.
- The peptide / GLP feature is a user-entered logbook and arithmetic helper only.
- Planned peptide reminders are optional local log prompts only.
- The app does not recommend, prescribe, encourage, source, sell, or provide protocols for medications, peptides, GLP products, or controlled/regulated substances.
- Users must only enter amounts from a clinician, pharmacy, or product label.
- HealthKit data is read for user-visible activity summaries.
- Location is used for user-saved gym check-ins and geofence visits.
- Health and location purpose strings are present in the archived app Info.plist.
- No tracking domains are declared in the privacy manifest.
- Copy the relevant text from `APP_REVIEW_NOTES.md` into App Store Connect review notes.

## Archive Verification

Before upload:

```bash
xcodebuild -project CalorieTrackAI.xcodeproj -scheme CalorieTrackAI -configuration Release -destination 'generic/platform=iOS' build CODE_SIGNING_ALLOWED=NO
```

Confirm the archived app Info.plist contains:

- `NSHealthShareUsageDescription`
- `NSHealthUpdateUsageDescription`
- `NSLocationWhenInUseUsageDescription`
- `NSLocationAlwaysAndWhenInUseUsageDescription`
- `NSLocationAlwaysUsageDescription`

Then archive in Xcode with signing enabled:

1. Select `Any iOS Device`.
2. Product > Archive.
3. Validate the archive.
4. Generate and review the privacy report.
5. Upload to App Store Connect.
