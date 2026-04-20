// TemplatesView+AI.swift
// FlowDay
//
// AI-generated templates: prompt → Claude → parsed JSON → FDProject + tasks.
// Kept separate from the main view so the render path stays small.

import SwiftUI
import SwiftData

extension TemplatesView {

    struct AITemplateResponse: Decodable {
        let name: String
        let description: String
        let icon: String
        let colorHex: String
        let tasks: [AITemplateTask]
    }

    struct AITemplateTask: Decodable {
        let title: String
        let priority: Int
        let estimatedMinutes: Int
        let notes: String?
    }

    @MainActor
    func generateAITemplate() async {
        let prompt = aiPrompt.trimmingCharacters(in: .whitespaces)
        guard !prompt.isEmpty else { return }

        isGeneratingTemplate = true
        generationError = nil

        defer { isGeneratingTemplate = false }

        let userMessage = """
        Create a task template for this project:
        "\(prompt)"

        Return ONLY a JSON object — no markdown, no prose.
        """

        do {
            let raw = try await ClaudeClient.shared.chat(
                feature: .templateGenerator,
                messages: [LLMMessage(role: .user, content: userMessage)],
                temperature: 0.8,
                maxTokens: 2048
            )

            let cleaned = extractJSON(from: raw)

            guard let data = cleaned.data(using: .utf8),
                  let aiTemplate = try? JSONDecoder().decode(AITemplateResponse.self, from: data) else {
                generationError = "Couldn't parse the AI response. Try again."
                return
            }

            let project = FDProject(
                name: aiTemplate.name,
                colorHex: aiTemplate.colorHex,
                iconName: aiTemplate.icon
            )
            modelContext.insert(project)

            for (index, aiTask) in aiTemplate.tasks.enumerated() {
                let priority: TaskPriority
                switch aiTask.priority {
                case 1: priority = .urgent
                case 2: priority = .high
                case 3: priority = .medium
                default: priority = .none
                }

                let task = FDTask(
                    title: aiTask.title,
                    notes: aiTask.notes ?? "",
                    estimatedMinutes: aiTask.estimatedMinutes,
                    priority: priority,
                    project: project
                )
                task.sortOrder = index
                modelContext.insert(task)

                Task { await SupabaseService.shared.syncTask(task) }
            }

            try? modelContext.save()

            let tasksForSupabase = aiTemplate.tasks.map { t -> [String: Any] in
                ["title": t.title, "priority": t.priority, "estimatedMinutes": t.estimatedMinutes]
            }
            Task {
                await SupabaseService.shared.saveTemplate(
                    name: aiTemplate.name,
                    description: aiTemplate.description,
                    icon: aiTemplate.icon,
                    colorHex: aiTemplate.colorHex,
                    prompt: prompt,
                    tasks: tasksForSupabase
                )
                await SupabaseService.shared.syncProject(project)
            }

            Haptics.success()
            appliedTemplateName = aiTemplate.name
            showTemplateApplied = true
            aiPrompt = ""

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                dismiss()
            }

        } catch let err as ClaudeClientError {
            Haptics.error()
            generationError = err.localizedDescription
        } catch {
            Haptics.error()
            generationError = "AI generation failed. Check your connection and try again."
        }
    }

    /// Extract the JSON object from a string that may contain markdown code fences.
    func extractJSON(from text: String) -> String {
        var s = text
        if let start = s.range(of: "```json") {
            s.removeSubrange(...start.lowerBound)
            if let end = s.range(of: "```") { s.removeSubrange(end.lowerBound...) }
        } else if let start = s.range(of: "```") {
            s.removeSubrange(...start.lowerBound)
            if let end = s.range(of: "```") { s.removeSubrange(end.lowerBound...) }
        }
        guard let jsonStart = s.firstIndex(of: "{"),
              let jsonEnd = s.lastIndex(of: "}") else { return s }
        return String(s[jsonStart...jsonEnd])
    }
}
