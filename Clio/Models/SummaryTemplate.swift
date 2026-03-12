import Foundation

struct SummaryTemplate: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let icon: String
    let systemPrompt: String
    let isBuiltIn: Bool

    init(id: UUID = UUID(), name: String, icon: String, systemPrompt: String, isBuiltIn: Bool = false) {
        self.id = id
        self.name = name
        self.icon = icon
        self.systemPrompt = systemPrompt
        self.isBuiltIn = isBuiltIn
    }

    static let builtIn: [SummaryTemplate] = [
        SummaryTemplate(
            name: "Detailed Notes",
            icon: "doc.text",
            systemPrompt: LLMPrompts.summarySystem,
            isBuiltIn: true
        ),
        SummaryTemplate(
            name: "Executive Brief",
            icon: "briefcase",
            systemPrompt: """
            You are a meeting note assistant. Given a meeting transcript, produce a brief executive summary. Include:

            ## Executive Summary
            3-5 bullet points covering the most critical outcomes, decisions, and next steps. Focus on what matters to leadership — skip the details.

            ### Key Decisions
            List any decisions that were made, with brief context.

            ### Next Steps
            Numbered list of the most important follow-up items with owners if identifiable.

            Be extremely concise. No more than 200 words total. Use direct, professional language.
            """,
            isBuiltIn: true
        ),
        SummaryTemplate(
            name: "Action-Focused",
            icon: "checklist",
            systemPrompt: """
            You are a meeting note assistant. Given a meeting transcript, extract ONLY the action items and tasks. Include:

            ## Action Items
            A checklist of every task, follow-up, or commitment mentioned or implied during the meeting. Format each as:
            - [ ] **Owner:** Task description (deadline if mentioned)

            ### Decisions Requiring Action
            Any decisions that need someone to act on them.

            ### Open Questions
            Items that were raised but not resolved and need follow-up.

            Focus entirely on actionable output. Do not include general discussion summaries.
            """,
            isBuiltIn: true
        )
    ]

    /// Load custom templates from UserDefaults
    static func loadCustom() -> [SummaryTemplate] {
        guard let data = UserDefaults.standard.data(forKey: "customSummaryTemplates"),
              let templates = try? JSONDecoder().decode([SummaryTemplate].self, from: data) else {
            return []
        }
        return templates
    }

    /// Save custom templates to UserDefaults
    static func saveCustom(_ templates: [SummaryTemplate]) {
        if let data = try? JSONEncoder().encode(templates) {
            UserDefaults.standard.set(data, forKey: "customSummaryTemplates")
        }
    }

    /// All available templates (built-in + custom)
    static var all: [SummaryTemplate] {
        builtIn + loadCustom()
    }
}
