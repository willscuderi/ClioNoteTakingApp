import SwiftUI

struct ProviderModelButton: View {
    @Binding var selectedProvider: LLMProvider
    @Binding var selectedModelID: String

    private var resolvedModel: LLMModel {
        selectedProvider.availableModels.first(where: { $0.id == selectedModelID })
            ?? selectedProvider.defaultModel
    }

    var body: some View {
        Menu {
            Section("Provider") {
                ForEach(LLMProvider.allCases) { provider in
                    Button {
                        selectedProvider = provider
                        selectedModelID = provider.defaultModel.id
                    } label: {
                        HStack {
                            Label(provider.displayName, systemImage: provider.iconName)
                            if provider == selectedProvider {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
            Section("Model") {
                ForEach(selectedProvider.availableModels) { model in
                    Button {
                        selectedModelID = model.id
                    } label: {
                        HStack {
                            Text("\(model.displayName) \(model.tierLabel)")
                            if model.id == selectedModelID {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: selectedProvider.iconName)
                    .font(.system(size: 12))
                Text(resolvedModel.displayName)
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
