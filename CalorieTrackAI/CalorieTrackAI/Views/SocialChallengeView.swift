import SwiftUI

struct SocialChallengeView: View {
    @Environment(\.showAuth) private var showAuth
    @ObservedObject private var store = SocialChallengeStore.shared
    @EnvironmentObject private var socialLinkRouter: SocialLinkRouter
    @State private var friendCode = ""
    @State private var inviteCode = ""
    @State private var activeChallenge: FitnessChallenge?
    @State private var showingFriendQR = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                MFTPageHeader(
                    kicker: "Competition",
                    title: "Set the number.",
                    subtitle: "Send verified reps. Take the lead. Make them earn it back."
                )

                if store.isAvailable {
                    identityBand

                    if !store.incomingFriendRequests.isEmpty {
                        friendRequestsSection
                    }

                    if !store.incomingChallenges.isEmpty {
                        incomingChallengesSection
                    }

                    standingsSection

                    if !store.outgoingChallenges.isEmpty || !store.completedChallenges.isEmpty {
                        challengeHistorySection
                    }
                } else {
                    signInState
                }
            }
            .padding(16)
        }
        .background(MFTTheme.background.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(MFTTheme.background, for: .navigationBar)
        .mftPageChrome()
        .task {
            await store.refresh()
            await handlePendingRoute()
        }
        .refreshable { await store.refresh() }
        .onChange(of: socialLinkRouter.pendingRoute) { _, route in
            guard route != nil else { return }
            Task { await handlePendingRoute() }
        }
        .fullScreenCover(item: $activeChallenge, onDismiss: {
            Task { await store.refresh() }
        }) { challenge in
            PushUpChallengeView(
                challengeType: challenge.challenge_type,
                respondingToChallenge: challenge
            )
        }
        .alert("Competition", isPresented: noticeIsPresented) {
            Button("OK") { store.clearMessages() }
        } message: {
            Text(store.errorMessage ?? store.confirmationMessage ?? "")
        }
        .sheet(isPresented: $showingFriendQR) {
            if let profile = store.profile {
                SocialQRCodeSheet(
                    title: "Add \(profile.display_name)",
                    subtitle: "Scan this with the Camera app, then send the friend request in My Fatness Tracker.",
                    value: SocialShareText.friendURL(code: profile.friend_code)?.absoluteString ?? profile.friend_code
                )
            }
        }
    }

    private var identityBand: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "person.2.fill")
                    .font(.title2)
                    .foregroundColor(MFTTheme.accent)
                    .frame(width: 44, height: 44)
                    .background(MFTTheme.elevatedSurface, in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(store.profile?.display_name ?? "Your team")
                        .font(.headline)
                        .fontWeight(.black)
                    Text("FRIEND CODE  \(store.profile?.friend_code ?? "--------")")
                        .font(.caption.monospaced())
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if let code = store.profile?.friend_code {
                    ShareLink(item: SocialShareText.friendMessage(name: store.profile?.display_name ?? "me", code: code)) {
                        Image(systemName: "square.and.arrow.up")
                            .frame(width: 38, height: 38)
                            .background(MFTTheme.surface, in: Circle())
                    }
                    .accessibilityLabel("Share friend code")

                    Button {
                        showingFriendQR = true
                    } label: {
                        Image(systemName: "qrcode")
                            .frame(width: 38, height: 38)
                            .background(MFTTheme.surface, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Show friend QR code")
                }
            }

            HStack(spacing: 10) {
                TextField("Enter 8-character code", text: $friendCode)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .font(.body.monospaced())
                    .padding(.horizontal, 12)
                    .frame(height: 46)
                    .background(MFTTheme.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(MFTTheme.divider, lineWidth: 1)
                    }
                    .onChange(of: friendCode) { _, newValue in
                        friendCode = String(newValue.uppercased().filter { $0.isLetter || $0.isNumber }.prefix(8))
                    }

                Button {
                    let code = friendCode
                    Task {
                        await store.addFriend(friendCode: code)
                        if store.errorMessage == nil { friendCode = "" }
                    }
                } label: {
                    Image(systemName: "person.badge.plus")
                        .font(.headline)
                        .foregroundColor(.black)
                        .frame(width: 46, height: 46)
                        .background(MFTTheme.accent, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .disabled(friendCode.count != 8 || store.isLoading)
                .opacity(friendCode.count == 8 ? 1 : 0.45)
                .accessibilityLabel("Send friend request")
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("REDEEM A SHARED CHALLENGE")
                    .font(.caption.monospaced())
                    .fontWeight(.black)
                    .foregroundColor(.secondary)

                HStack(spacing: 10) {
                    TextField("12-character challenge code", text: $inviteCode)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .font(.body.monospaced())
                        .padding(.horizontal, 12)
                        .frame(height: 46)
                        .background(MFTTheme.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(MFTTheme.divider, lineWidth: 1)
                        }
                        .onChange(of: inviteCode) { _, newValue in
                            inviteCode = String(newValue.uppercased().filter { $0.isLetter || $0.isNumber }.prefix(12))
                        }

                    Button {
                        let code = inviteCode
                        Task {
                            if let challenge = await store.redeemSharedChallengeInvite(code: code) {
                                inviteCode = ""
                                activeChallenge = challenge
                            }
                        }
                    } label: {
                        Image(systemName: "bolt.fill")
                            .font(.headline)
                            .foregroundColor(.black)
                            .frame(width: 46, height: 46)
                            .background(MFTTheme.accent, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .disabled(inviteCode.count != 12 || store.isLoading)
                    .opacity(inviteCode.count == 12 ? 1 : 0.45)
                    .accessibilityLabel("Redeem shared challenge")
                }
            }
        }
        .padding(16)
        .mftPanel(accent: MFTTheme.accent)
    }

    private var friendRequestsSection: some View {
        socialSection(title: "Friend requests", count: store.incomingFriendRequests.count) {
            ForEach(store.incomingFriendRequests) { friendship in
                let profile = store.profile(for: friendship.requester_id)
                HStack(spacing: 12) {
                    avatar(for: profile)

                    Text(profile?.display_name ?? "Athlete")
                        .font(.subheadline)
                        .fontWeight(.bold)

                    Spacer()

                    Button {
                        Task { await store.answerFriendRequest(friendship, accept: false) }
                    } label: {
                        Image(systemName: "xmark")
                            .frame(width: 34, height: 34)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Decline friend request")

                    Button {
                        Task { await store.answerFriendRequest(friendship, accept: true) }
                    } label: {
                        Image(systemName: "checkmark")
                            .fontWeight(.bold)
                            .foregroundColor(.black)
                            .frame(width: 36, height: 36)
                            .background(MFTTheme.accent, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Accept friend request")
                }
                .padding(.vertical, 10)
            }
        }
    }

    private var incomingChallengesSection: some View {
        socialSection(title: "Your move", count: store.incomingChallenges.count) {
            ForEach(store.incomingChallenges) { challenge in
                let challenger = store.profile(for: challenge.challenger_id)
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        avatar(for: challenger)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(challenger?.display_name ?? "A friend")
                                .font(.subheadline)
                                .fontWeight(.bold)
                            Text(challenge.isTimedHold
                                ? "sent a \(challenge.challengerScoreDisplay) plank hold"
                                : "sent \(challenge.challengerScoreDisplay) \(challenge.challenge_type.shortTitle.lowercased())")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text("BEAT \(challenge.challengerScoreDisplay)")
                            .font(.caption.monospacedDigit())
                            .fontWeight(.black)
                            .foregroundColor(MFTTheme.challengeAccent(challenge.challenge_type))
                    }

                    HStack(spacing: 10) {
                        Button("Decline") {
                            Task { await store.declineChallenge(challenge) }
                        }
                        .buttonStyle(.bordered)
                        .tint(.secondary)

                        Button {
                            activeChallenge = challenge
                        } label: {
                            Label("Start Attempt", systemImage: "camera.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(MFTTheme.challengeAccent(challenge.challenge_type))
                        .foregroundStyle(.black)
                    }
                }
                .padding(.vertical, 12)
            }
        }
    }

    private var standingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Head-to-head")
                .font(.headline)
                .fontWeight(.black)

            if store.standings.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "person.2")
                        .font(.title2)
                        .foregroundColor(MFTTheme.blue)
                    Text("Add a friend to start competing.")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    if !store.outgoingFriendRequests.isEmpty {
                        Text("\(store.outgoingFriendRequests.count) request waiting for an answer")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .background(MFTTheme.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                VStack(spacing: 0) {
                    ForEach(store.standings) { standing in
                        HStack(spacing: 12) {
                            avatar(for: standing.friend)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(standing.friend.display_name)
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                Text(standing.leadText)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if standing.openChallenges > 0 {
                                Text("\(standing.openChallenges) OPEN")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(MFTTheme.amber)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)

                        if standing.id != store.standings.last?.id {
                            Divider().padding(.leading, 62)
                        }
                    }
                }
                .background(MFTTheme.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(MFTTheme.divider, lineWidth: 1)
                }
            }
        }
    }

    private var challengeHistorySection: some View {
        socialSection(title: "Challenge activity", count: nil) {
            ForEach(Array((store.outgoingChallenges + store.completedChallenges).prefix(8))) { challenge in
                let opponent = store.profile(for: challenge.opponentId(for: store.currentUserId ?? UUID()))
                HStack(spacing: 12) {
                    Image(systemName: challenge.challenge_type.icon)
                        .foregroundColor(MFTTheme.challengeAccent(challenge.challenge_type))
                        .frame(width: 36, height: 36)
                        .background(MFTTheme.challengeAccent(challenge.challenge_type).opacity(0.12), in: Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text(opponent?.display_name ?? "Friend")
                            .font(.subheadline)
                            .fontWeight(.bold)
                        Text(challengeSummary(challenge))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text(challenge.resultText(for: store.currentUserId ?? UUID()).uppercased())
                        .font(.caption)
                        .fontWeight(.black)
                        .foregroundColor(challengeResultColor(challenge))
                }
                .padding(.vertical, 10)
            }
        }
    }

    private var signInState: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.badge.gearshape")
                .font(.system(size: 42))
                .foregroundColor(MFTTheme.accent)
            Text("Competition needs an account")
                .font(.title3)
                .fontWeight(.black)
            Text("Sign in to get a friend code, send verified sets, and keep a head-to-head record.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Sign In or Create Account") {
                showAuth.wrappedValue = true
            }
            .buttonStyle(.borderedProminent)
            .tint(MFTTheme.accent)
            .foregroundStyle(.black)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 42)
        .background(MFTTheme.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func socialSection<Content: View>(
        title: String,
        count: Int?,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.headline)
                    .fontWeight(.black)
                Spacer()
                if let count {
                    Text("\(count)")
                        .font(.caption.monospacedDigit())
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                }
            }

            VStack(spacing: 0) {
                content()
            }
            .padding(.horizontal, 14)
            .background(MFTTheme.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(MFTTheme.divider, lineWidth: 1)
            }
        }
    }

    private func avatar(for profile: SocialProfile?) -> some View {
        Text(profile?.display_name.prefix(1).uppercased() ?? "?")
            .font(.subheadline)
            .fontWeight(.black)
            .foregroundColor(.white)
            .frame(width: 40, height: 40)
            .background(MFTTheme.performance, in: Circle())
            .overlay { Circle().stroke(MFTTheme.accent.opacity(0.7), lineWidth: 1.5) }
    }

    private func challengeSummary(_ challenge: FitnessChallenge) -> String {
        if challenge.status == .pending {
            return challenge.isTimedHold
                ? "Waiting on a \(challenge.targetScoreDisplay) plank hold"
                : "Waiting on \(challenge.targetScoreDisplay) \(challenge.challenge_type.shortTitle.lowercased())"
        }
        if challenge.isTimedHold {
            return "\(challenge.challengerScoreDisplay) vs \(challenge.challengedScoreDisplay) plank hold"
        }
        return "\(challenge.challengerScoreDisplay) vs \(challenge.challengedScoreDisplay) \(challenge.challenge_type.shortTitle.lowercased())"
    }

    private func challengeResultColor(_ challenge: FitnessChallenge) -> Color {
        guard challenge.status == .completed, let currentUserId = store.currentUserId else {
            return .secondary
        }
        return challenge.winner_id == currentUserId ? MFTTheme.accent : .red
    }

    private var noticeIsPresented: Binding<Bool> {
        Binding(
            get: { store.errorMessage != nil || store.confirmationMessage != nil },
            set: { if !$0 { store.clearMessages() } }
        )
    }

    private func handlePendingRoute() async {
        guard let route = socialLinkRouter.consume() else { return }

        switch route {
        case let .friend(code):
            friendCode = code
        case let .challenge(code):
            inviteCode = code
            if let challenge = await store.redeemSharedChallengeInvite(code: code) {
                inviteCode = ""
                activeChallenge = challenge
            }
        }
    }
}

struct SendChallengeView: View {
    @Environment(\.showAuth) private var showAuth
    @ObservedObject private var store = SocialChallengeStore.shared

    let session: MovementChallengeSession
    let onDismiss: () -> Void
    let onChallengeSent: () -> Void
    @State private var sendingTo: UUID?
    @State private var sharedInvite: SharedChallengeInvite?
    @State private var isCreatingSharedInvite = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    scoreBand
                    shareInviteSection

                    if !store.isAvailable {
                        signInPrompt
                    } else if store.friends.isEmpty {
                        ContentUnavailableView(
                            "No Friends Yet",
                            systemImage: "person.2",
                            description: Text("Add a friend from Competition before sending this set.")
                        )
                        .frame(minHeight: 220)
                    } else {
                        ForEach(store.friends) { friend in
                            Button {
                                sendingTo = friend.id
                                Task {
                                    await store.sendChallenge(session: session, to: friend)
                                    sendingTo = nil
                                    if store.errorMessage == nil { onChallengeSent() }
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    Text(friend.display_name.prefix(1).uppercased())
                                        .fontWeight(.black)
                                        .foregroundColor(.white)
                                        .frame(width: 42, height: 42)
                                        .background(MFTTheme.performance, in: Circle())

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(friend.display_name)
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        Text(session.challengeType.isTimedHold
                                            ? "Send target: \(session.competitionTargetDisplay) hold"
                                            : "Send target: \(session.competitionTargetDisplay) reps")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    if sendingTo == friend.id {
                                        ProgressView()
                                    } else {
                                        Image(systemName: "paperplane.fill")
                                            .foregroundColor(MFTTheme.accent)
                                    }
                                }
                                .padding(14)
                                .background(MFTTheme.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(MFTTheme.divider, lineWidth: 1)
                                }
                            }
                            .buttonStyle(.plain)
                            .disabled(sendingTo != nil)
                        }
                    }
                }
                .padding(16)
            }
            .background(MFTTheme.background.ignoresSafeArea())
            .navigationTitle("Challenge a Friend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { onDismiss() }
                }
            }
            .task { await store.refresh() }
        }
    }

    private var scoreBand: some View {
        HStack(spacing: 14) {
            Image(systemName: session.challengeType.icon)
                .font(.title2)
                .foregroundColor(MFTTheme.challengeAccent(session.challengeType))
                .frame(width: 48, height: 48)
                .background(MFTTheme.performance, in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(session.challengeType.isTimedHold
                    ? "\(session.competitionScoreDisplay) verified plank hold"
                    : "\(session.competitionScoreDisplay) verified \(session.challengeType.shortTitle.lowercased())")
                    .font(.headline)
                    .fontWeight(.black)
                Text(session.challengeType.isTimedHold
                    ? "Your friend must hold for \(session.competitionTargetDisplay) to win."
                    : "Your friend must hit \(session.competitionTargetDisplay) to win.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MFTTheme.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var shareInviteSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("SEND OUTSIDE THE APP")
                .font(.caption.monospaced())
                .fontWeight(.black)
                .foregroundColor(.secondary)

            if let sharedInvite {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("CODE  \(sharedInvite.invite_code)")
                            .font(.subheadline.monospaced())
                            .fontWeight(.black)
                        Text("One athlete can claim it in the next 7 days.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    ShareLink(item: SocialShareText.challengeMessage(sharedInvite)) {
                        Image(systemName: "message.fill")
                            .font(.headline)
                            .foregroundColor(.black)
                            .frame(width: 44, height: 44)
                            .background(MFTTheme.accent, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .accessibilityLabel("Share challenge by Messages or another app")
                }
            } else {
                Button {
                    isCreatingSharedInvite = true
                    Task {
                        sharedInvite = await store.createSharedChallengeInvite(session: session)
                        isCreatingSharedInvite = false
                    }
                } label: {
                    Label(isCreatingSharedInvite ? "Preparing invite..." : "Create Shareable Challenge", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(MFTTheme.accent)
                .disabled(isCreatingSharedInvite || store.isLoading)
            }
        }
        .padding(14)
        .background(MFTTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(MFTTheme.divider, lineWidth: 1)
        }
    }

    private var signInPrompt: some View {
        VStack(spacing: 14) {
            Text("Sign in to send this verified set.")
                .font(.headline)
            Button("Sign In") { showAuth.wrappedValue = true }
                .buttonStyle(.borderedProminent)
                .tint(MFTTheme.accent)
                .foregroundStyle(.black)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }
}
