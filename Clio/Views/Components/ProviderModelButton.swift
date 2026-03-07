import SwiftUI

struct ProviderModelButton: View {
    @Bindable var viewModel: MeetingDetailViewModel

    var body: some View {
        Menu {
            Section("Provider") {
                ForEach(LLMProvider.allCases) { provider in
                    Button {
                        viewModel.selectedLLMProvider = provider
                    } label: {
                        HStack {
                            Label(provider.displayName, systemImage: provider.iconName)
                            if provider == viewModel.selectedLLMProvider {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
            Section("Model") {
                ForEach(viewModel.selectedLLMProvider.availableModels) { model in
                    Button {
                        viewModel.selectedModelID = model.id
                    } label: {
                        HStack {
                            Text("\(model.displayName) \(model.tierLabel)")
                            if model.id == viewModel.selectedModelID {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: viewModel.selectedLLMProvider.iconName)
                    .font(.system(size: 12))
                Text(viewModel.resolvedModel.displayName)
                    .font(.system(size: 13))
                Image(systemName: "chevron.down")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }
}
