import SwiftUI

struct WelcomeStepView: View {
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "brain.head.profile")
                .font(.system(size: 80))
                .foregroundStyle(.blue)
            Text("Welcome to Alfred")
                .font(.largeTitle.bold())
            Text("Your ambient intelligent assistant")
                .font(.title3)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Get Started", action: onNext)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .padding()
    }
}

struct PreferencesStepView: View {
    @Binding var preferences: UserPreferences
    let onNext: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("Basic Preferences")
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading) {
                    Text("Wake Time").font(.headline)
                    TextField("e.g., 7:00 AM", text: Binding(
                        get: { preferences.wakeTime ?? "" },
                        set: { preferences.wakeTime = $0.isEmpty ? nil : $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading) {
                    Text("Work Address").font(.headline)
                    TextField("Optional", text: Binding(
                        get: { preferences.workAddress ?? "" },
                        set: { preferences.workAddress = $0.isEmpty ? nil : $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading) {
                    Text("Dietary Restrictions").font(.headline)
                    TextField("Optional", text: Binding(
                        get: { preferences.dietaryRestrictions ?? "" },
                        set: { preferences.dietaryRestrictions = $0.isEmpty ? nil : $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                }
            }

            Spacer()
            OnboardingButtons(onNext: onNext, onSkip: onSkip)
        }
        .padding()
    }
}

struct ProactivityStepView: View {
    @Binding var preferences: UserPreferences
    let onNext: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Text("Proactivity Level")
                .font(.title2.bold())
            Text("How proactive should Alfred be?")
                .foregroundStyle(.secondary)

            Picker("Level", selection: $preferences.proactivityLevel) {
                Text("Conservative").tag(UserPreferences.ProactivityLevel.conservative)
                Text("Moderate").tag(UserPreferences.ProactivityLevel.moderate)
                Text("Opinionated").tag(UserPreferences.ProactivityLevel.opinionated)
            }
            .pickerStyle(.segmented)

            Group {
                switch preferences.proactivityLevel {
                case .conservative:
                    Text("Only responds when asked. Minimal suggestions.")
                case .moderate:
                    Text("Offers helpful suggestions based on context.")
                case .opinionated:
                    Text("Actively provides recommendations and reminders.")
                }
            }
            .foregroundStyle(.secondary)
            .font(.callout)

            Spacer()
            OnboardingButtons(onNext: onNext, onSkip: onSkip)
        }
        .padding()
    }
}

struct GuestAccessStepView: View {
    @Binding var preferences: UserPreferences
    let onNext: () -> Void
    let onSkip: () -> Void

    private let availableControls = [
        "Lighting control",
        "Media playback",
        "Temperature control",
        "Door locks",
        "Appliance control",
    ]

    var body: some View {
        VStack(spacing: 20) {
            Text("Guest Access")
                .font(.title2.bold())
            Text("What can guests control?")
                .foregroundStyle(.secondary)

            VStack(spacing: 0) {
                ForEach(availableControls, id: \.self) { control in
                    Toggle(control, isOn: Binding(
                        get: { preferences.guestControls.contains(control) },
                        set: { enabled in
                            if enabled {
                                preferences.guestControls.append(control)
                            } else {
                                preferences.guestControls.removeAll { $0 == control }
                            }
                        }
                    ))
                    .padding(.vertical, 4)
                }
            }

            Spacer()
            OnboardingButtons(onNext: onNext, onSkip: onSkip)
        }
        .padding()
    }
}

struct IntegrationsStepView: View {
    let integrations: [Integration]
    let onNext: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("Integrations")
                .font(.title2.bold())
            Text("Configure later in Settings")
                .foregroundStyle(.secondary)

            if integrations.isEmpty {
                Text("No integrations available")
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(integrations) { integration in
                    HStack {
                        Text(integration.name.capitalized)
                        Spacer()
                        if integration.configured {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Spacer()
            OnboardingButtons(onNext: onNext, onSkip: onSkip)
        }
        .padding()
    }
}

struct CompletionStepView: View {
    let isSubmitting: Bool
    let onFinish: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "checkmark.circle")
                .font(.system(size: 80))
                .foregroundStyle(.green)
            Text("You're All Set!")
                .font(.largeTitle.bold())
            Text("Alfred is ready to assist you.")
                .foregroundStyle(.secondary)
            Spacer()
            Button(action: onFinish) {
                if isSubmitting {
                    ProgressView()
                } else {
                    Text("Start Using Alfred")
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isSubmitting)
        }
        .padding()
    }
}

// Shared buttons for onboarding steps
private struct OnboardingButtons: View {
    let onNext: () -> Void
    let onSkip: () -> Void

    var body: some View {
        HStack {
            Button("Skip", action: onSkip)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Next", action: onNext)
                .buttonStyle(.borderedProminent)
        }
    }
}
