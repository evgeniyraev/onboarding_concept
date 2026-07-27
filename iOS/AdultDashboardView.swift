import SwiftUI

struct AdultDashboardView: View {
    let onLogout: () -> Void
    @State private var showingDiscovery = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        welcomeCard

                        VStack(alignment: .leading, spacing: 12) {
                            Text("YOUR FAMILY")
                                .font(.caption.weight(.heavy))
                                .tracking(1.4)
                                .foregroundStyle(.secondary)

                            emptyFamilyCard
                        }

                        discoveryTip
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Family orbit")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Log out", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                            onLogout()
                        }
                    } label: {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showingDiscovery) {
                ParentDiscoveryView()
            }
        }
    }

    private var welcomeCard: some View {
        ZStack(alignment: .bottomTrailing) {
            LinearGradient(
                colors: [.indigo, Color(red: 0.49, green: 0.35, blue: 0.92)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(.white.opacity(0.11))
                .frame(width: 180, height: 180)
                .offset(x: 38, y: 58)

            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundStyle(.white.opacity(0.20))
                .padding(28)

            VStack(alignment: .leading, spacing: 12) {
                Text("Hello, grown-up 👋")
                    .font(.system(size: 28, weight: .bold, design: .rounded))

                Text("Someone nearby is ready\nto join your orbit.")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.82))

                Button {
                    showingDiscovery = true
                } label: {
                    Label("Add child", systemImage: "plus")
                        .font(.headline)
                        .foregroundStyle(.indigo)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(.white, in: Capsule())
                }
                .padding(.top, 8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
            .foregroundStyle(.white)
        }
        .frame(minHeight: 250)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .shadow(color: .indigo.opacity(0.24), radius: 20, y: 12)
    }

    private var emptyFamilyCard: some View {
        HStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Color.indigo.opacity(0.10))
                    .frame(width: 58, height: 58)
                Image(systemName: "person.2.badge.plus")
                    .font(.title2)
                    .foregroundStyle(.indigo)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Room for someone")
                    .font(.headline)
                Text("Add a child to see them here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(18)
        .background(.background, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var discoveryTip: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "wifi")
                .foregroundStyle(.blue)
            Text("For the best discovery results, keep both devices nearby, unlocked, and connected to the same Wi‑Fi network.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 4)
    }
}
