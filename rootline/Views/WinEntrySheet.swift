import SwiftUI
import ShroomKit

/// Arcade-style three-letter initials entry, shown when the player's time
/// qualifies for the tier leaderboard.
struct WinEntrySheet: View {
    let timeText: String
    let tierLabel: String
    let groveNumber: Int
    let isRecord: Bool
    @Binding var initials: String
    let onSave: () -> Void
    let onSkip: () -> Void

    @Environment(\.palette) private var palette
    @FocusState private var initialsFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack(spacing: 14) {
                    MyceliumIcon()
                        .frame(width: 44, height: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(isRecord ? "New record!" : "On the board!")
                            .font(.system(.title2, design: .rounded).weight(.semibold))
                            .foregroundStyle(palette.text)
                        Text("\(tierLabel) · Grove #\(groveNumber) · \(timeText)")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(palette.sub)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.top, 4)

                TextField("AAA", text: $initials)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled(true)
                    .multilineTextAlignment(.center)
                    .font(.system(.title, design: .monospaced).weight(.bold))
                    .tracking(6)
                    .foregroundStyle(palette.text)
                    .padding(.vertical, 16)
                    .frame(width: 180)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(palette.tierBg)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(initialsFocused ? palette.accent : palette.tierBorder, lineWidth: 2)
                            )
                    )
                    .focused($initialsFocused)
                    .submitLabel(.done)
                    .onSubmit(onSave)
                    .onChange(of: initials) { _, newValue in
                        let cleaned = ScoreStore.sanitize(newValue == "YOU" ? "" : newValue)
                        // Sanitize but allow empty so the user can clear and retype.
                        let trimmed = String(newValue.uppercased().prefix(3))
                        if trimmed != newValue { initials = trimmed }
                        _ = cleaned
                    }
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Button("Skip", action: onSkip).tint(palette.sub)
                            Spacer()
                            Button("Save", action: onSave)
                                .tint(palette.accent)
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)

                HStack(spacing: 10) {
                    Button(action: onSkip) {
                        Text("Skip")
                            .font(.system(.headline, design: .rounded))
                            .foregroundStyle(palette.text)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 44)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(palette.tierBg)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(palette.tierBorder, lineWidth: 1)
                                    )
                            )
                    }
                    .buttonStyle(.plain)

                    Button(action: onSave) {
                        Text("Save")
                            .font(.system(.headline, design: .rounded))
                            .foregroundStyle(palette.accentText)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 44)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(palette.accent)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .scrollIndicators(.hidden)
        .background(palette.appBg.ignoresSafeArea())
        .onAppear {
            Task {
                try? await Task.sleep(for: .milliseconds(250))
                initialsFocused = true
            }
        }
    }
}
