# Social Push Notification Setup

The app, database, and `social-push` Edge Function are wired for APNs. The remaining credentials must come from Apple Developer because the `.p8` private key is shown only once and must never be committed to Git.

1. In Apple Developer, enable **Push Notifications** for the App ID `com.hyperlabsAI.CalorieTrackAI`.
2. Create an APNs authentication key under **Certificates, Identifiers & Profiles > Keys** and download the `.p8` file.
3. In Supabase **Edge Functions > Secrets**, add:
   - `APNS_KEY_ID`: the Key ID shown by Apple.
   - `APNS_TEAM_ID`: `67AR6NPQWB`.
   - `APNS_PRIVATE_KEY`: the complete contents of the `.p8` file, including the BEGIN and END lines.
4. In Xcode, keep automatic signing enabled and refresh signing so the provisioning profile includes the `aps-environment` entitlement.
5. Install a TestFlight build on a physical device, enable notifications, sign in, and send a friend challenge from a second account.

Simulator push testing does not produce a normal production APNs device registration. Use physical devices or TestFlight for the final delivery test.
