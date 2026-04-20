// RambleService.swift
// FlowDay
//
// "Ramble" — speak a stream of tasks and FlowDay parses each one into a
// fully-formed task with project, dates, priority, labels, duration.
// Beats Todoist's Pro-only Ramble by parsing duration AND making it free.
//
// Splitting strategy: prefer strong sentence boundaries (period / question
// mark), then explicit conjunctions ("then", "after that", "also", "and"),
// then sentence-initial imperatives. Each chunk goes through
// NaturalLanguageParser, so dates / projects / priorities work the same way
// they do in Quick Add.

import Foundation

enum RambleService {

    /// Take a long transcribed string, split it into one-task chunks, and
    /// run each chunk through the natural-language parser.
    static func parse(_ transcript: String) -> [ParsedTask] {
        let cleaned = transcript
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

        guard !cleaned.isEmpty else { return [] }

        let chunks = split(cleaned)
        let parser = NaturalLanguageParser()

        return chunks
            .map { chunk in chunk.trimmingCharacters(in: CharacterSet(charactersIn: " ,.;").union(.whitespaces)) }
            .filter { !$0.isEmpty }
            .map { parser.parse($0) }
            .filter { !$0.title.isEmpty }
    }

    // MARK: - Splitter

    /// Sentence + conjunction splitter tuned for spoken task lists.
    private static func split(_ text: String) -> [String] {
        // Step 1 — split on strong terminators (. ! ?)
        let sentenceParts = text.split(whereSeparator: { ".!?".contains($0) }).map(String.init)

        var chunks: [String] = []
        for sentence in sentenceParts {
            let s = sentence.trimmingCharacters(in: .whitespaces)
            if s.isEmpty { continue }

            // Step 2 — within each sentence, split on transitional phrases.
            chunks.append(contentsOf: splitOnTransitions(s))
        }

        // Step 3 — remove leading filler words ("then", "and", "also", "next",
        // "after that", "I need to", "remind me to") from each chunk.
        return chunks.map(stripLeadFillers)
    }

    private static func splitOnTransitions(_ text: String) -> [String] {
        // Word-bounded transitions that almost always start a new task in
        // spoken language. Order matters — multi-word phrases first so they
        // match before their single-word prefixes.
        let transitions = [
            "after that",
            "and then",
            "then",
            "next",
            "also",
            "and also",
            "plus"
        ]

        // Build a regex that splits on " transition " (with surrounding spaces)
        // anywhere in the string.
        let pattern = "\\s+(?:" + transitions.map { NSRegularExpression.escapedPattern(for: $0) }.joined(separator: "|") + ")\\s+"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return [text]
        }

        let nsText = text as NSString
        var lastEnd = 0
        var parts: [String] = []
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))

        for match in matches {
            let range = match.range
            if range.location > lastEnd {
                parts.append(nsText.substring(with: NSRange(location: lastEnd, length: range.location - lastEnd)))
            }
            lastEnd = range.location + range.length
        }
        if lastEnd < nsText.length {
            parts.append(nsText.substring(with: NSRange(location: lastEnd, length: nsText.length - lastEnd)))
        }

        return parts.isEmpty ? [text] : parts
    }

    /// Drop common spoken sentence starters that aren't part of the actual
    /// task title. "I need to buy milk" → "buy milk".
    private static func stripLeadFillers(_ text: String) -> String {
        let lead = text.trimmingCharacters(in: .whitespaces)
        let fillers = [
            "i need to",
            "i have to",
            "i should",
            "i want to",
            "remind me to",
            "remember to",
            "make sure to",
            "don't forget to",
            "please",
            "and",
            "then",
            "also",
            "next"
        ]

        let lower = lead.lowercased()
        for filler in fillers {
            if lower.hasPrefix(filler + " ") {
                let dropped = lead.dropFirst(filler.count + 1)
                return String(dropped).trimmingCharacters(in: .whitespaces)
            }
            if lower == filler {
                return ""
            }
        }
        return lead
    }
}
