import SwiftUI

struct WatchRolePickerView: View {
    let onAdult: () -> Void
    let onChild: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.indigo, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 58, height: 58)
                    Image(systemName: "figure.2.and.child.holdinghands")
                        .font(.title2)
                        .foregroundStyle(.white)
                }

                Text("Who are you?")
                    .font(.headline)

                Text("Pick your place in the orbit.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button("I’m an adult", action: onAdult)
                    .buttonStyle(.borderedProminent)
                    .tint(.indigo)

                Button("I’m a child", action: onChild)
                    .buttonStyle(.bordered)
                    .tint(.pink)
            }
        }
    }
}

struct WatchAdultView: View {
    let onBack: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Image(systemName: "cup.and.saucer.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.orange)

                Text("Nothing interesting\nfor now")
                    .font(.headline)
                    .multilineTextAlignment(.center)

                Text("Adult discovery lives on the iPhone.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button("Choose again", action: onBack)
                    .font(.caption)
            }
        }
    }
}
