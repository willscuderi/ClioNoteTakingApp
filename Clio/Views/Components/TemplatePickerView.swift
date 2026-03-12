import SwiftUI

struct TemplatePickerView: View {
    @Binding var selectedTemplate: SummaryTemplate

    private let templates = SummaryTemplate.all

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(templates) { template in
                    Button {
                        selectedTemplate = template
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: template.icon)
                                .font(.system(size: 11))
                            Text(template.name)
                                .font(.system(size: 12))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            selectedTemplate.id == template.id
                                ? Color.accentColor.opacity(0.15)
                                : Color(nsColor: .controlBackgroundColor)
                        )
                        .foregroundStyle(
                            selectedTemplate.id == template.id
                                ? Color.accentColor
                                : .primary
                        )
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .strokeBorder(
                                    selectedTemplate.id == template.id
                                        ? Color.accentColor.opacity(0.3)
                                        : Color(nsColor: .separatorColor),
                                    lineWidth: 1
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
        }
    }
}
