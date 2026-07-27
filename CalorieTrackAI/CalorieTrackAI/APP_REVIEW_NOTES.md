# App Review Notes

Use this language in App Store Connect review notes for the current TestFlight build.

## Core App

My Fatness Tracker is a calorie, macro, meal-planning, and activity accountability app with a configurable tough-love coach tone. Users can soften or disable the coach voice in settings.

## Peptide / GLP Logbook

The peptide / GLP feature is a user-entered logbook and arithmetic helper only. It records vial-label amounts, BAC water amount, and a user-provided label amount, then calculates concentration and draw volume from those numbers.

Users may mark an entry as planned and, if they enable notifications, receive a local reminder to complete the log. These reminders are log prompts only and do not provide medication, peptide, protocol, sourcing, or dosing guidance.

The app does not recommend, prescribe, encourage, source, sell, or provide protocols for medications, peptides, GLP products, or any controlled/regulated substances. Users must only enter amounts from a licensed clinician, pharmacy, or product label. The feature is not medical advice and is not intended to diagnose, treat, or guide medical decisions.

## Health and Fitness Data

HealthKit data is requested after user permission and is used to show steps, workouts, exercise minutes, and active energy inside the Activity tab. The current build requests read access for activity summaries; the Health update purpose string is included because the app has the HealthKit entitlement and App Store validation requires the purpose string when Health update access may be referenced. Apple Watch data appears after it syncs into Apple Health. Health and fitness data is also used locally to refresh optional movement, step-goal, and workout accountability notifications. Health and fitness data is not used for advertising, marketing, or tracking.

## Location Data

Location is used for user-initiated nearby gym search and user-saved gym geofence check-ins. Users can still log gym visits manually. Saved gym and visit state may be used locally to schedule optional gym-receipt accountability reminders. Location data is not used for advertising, marketing, or tracking.

## Reviewer Setup

The Supabase backend is active for this build. If a demo account is provided, use it to test sync for food logs, coach settings, plan builder, activity summaries, gym locations, and peptide logbook entries.
