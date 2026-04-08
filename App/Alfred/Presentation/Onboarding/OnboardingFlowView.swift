import SwiftUI

struct OnboardingFlowView: View {
    @Environment(AppContainer.self) private var container
    @State private var viewModel = OnboardingViewModel()
    @Binding var isPresented: Bool

    var body: some View {
        VStack {
            // Progress dots
            HStack(spacing: 8) {
                ForEach(0..<viewModel.totalSteps, id: \.self) { index in
                    Circle()
                        .fill(index <= viewModel.currentStep ? Color.blue : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.top)

            TabView(selection: $viewModel.currentStep) {
                WelcomeStepView(onNext: { viewModel.next() })
                    .tag(0)
                PreferencesStepView(preferences: $viewModel.preferences, onNext: { viewModel.next() }, onSkip: { viewModel.skip() })
                    .tag(1)
                ProactivityStepView(preferences: $viewModel.preferences, onNext: { viewModel.next() }, onSkip: { viewModel.skip() })
                    .tag(2)
                GuestAccessStepView(preferences: $viewModel.preferences, onNext: { viewModel.next() }, onSkip: { viewModel.skip() })
                    .tag(3)
                IntegrationsStepView(integrations: viewModel.integrations, onNext: { viewModel.next() }, onSkip: { viewModel.skip() })
                    .tag(4)
                CompletionStepView(isSubmitting: viewModel.isSubmitting, onFinish: {
                    Task {
                        await viewModel.submit()
                        isPresented = false
                    }
                })
                    .tag(5)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: viewModel.currentStep)
        }
        .interactiveDismissDisabled()
        .onAppear {
            viewModel.configure(with: container)
        }
    }
}
