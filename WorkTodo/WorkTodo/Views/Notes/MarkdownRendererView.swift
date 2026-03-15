import SwiftUI

struct MarkdownRendererView: View {
    let content: String

    var body: some View {
        let elements = parseLines()
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(elements.indices, id: \.self) { index in
                    renderElement(elements[index])
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
        }
    }

    // MARK: - Parsing

    private enum MarkdownElement {
        case heading(level: Int, text: String)
        case bulletItem(text: String)
        case numberedItem(number: String, text: String)
        case codeBlock(lines: [String])
        case blockquote(text: String)
        case horizontalRule
        case paragraph(text: String)
    }

    private func parseLines() -> [MarkdownElement] {
        let lines = content.components(separatedBy: "\n")
        var elements: [MarkdownElement] = []
        var codeBlockLines: [String]?
        var paragraphBuffer = ""

        func flushParagraph() {
            let trimmed = paragraphBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                elements.append(.paragraph(text: trimmed))
            }
            paragraphBuffer = ""
        }

        for line in lines {
            // Code block toggle
            if line.hasPrefix("```") {
                if let current = codeBlockLines {
                    elements.append(.codeBlock(lines: current))
                    codeBlockLines = nil
                } else {
                    flushParagraph()
                    codeBlockLines = []
                }
                continue
            }

            // Inside code block
            if codeBlockLines != nil {
                codeBlockLines?.append(line)
                continue
            }

            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Empty line
            if trimmed.isEmpty {
                flushParagraph()
                continue
            }

            // Horizontal rule
            if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                flushParagraph()
                elements.append(.horizontalRule)
                continue
            }

            // Headings
            if let heading = parseHeading(trimmed) {
                flushParagraph()
                elements.append(heading)
                continue
            }

            // Bullet list
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                flushParagraph()
                let text = String(trimmed.dropFirst(2))
                elements.append(.bulletItem(text: text))
                continue
            }

            // Numbered list
            if let match = trimmed.range(of: #"^\d+\.\s"#, options: .regularExpression) {
                flushParagraph()
                let numPart = String(trimmed[trimmed.startIndex..<trimmed.index(before: match.upperBound)])
                let text = String(trimmed[match.upperBound...])
                elements.append(.numberedItem(number: numPart, text: text))
                continue
            }

            // Blockquote
            if trimmed.hasPrefix("> ") {
                flushParagraph()
                let text = String(trimmed.dropFirst(2))
                elements.append(.blockquote(text: text))
                continue
            }

            // Regular paragraph text (accumulate)
            if !paragraphBuffer.isEmpty {
                paragraphBuffer += " "
            }
            paragraphBuffer += trimmed
        }

        // Flush remaining
        if let remaining = codeBlockLines, !remaining.isEmpty {
            elements.append(.codeBlock(lines: remaining))
        }
        flushParagraph()

        return elements
    }

    private func parseHeading(_ line: String) -> MarkdownElement? {
        if line.hasPrefix("### ") {
            return .heading(level: 3, text: String(line.dropFirst(4)))
        } else if line.hasPrefix("## ") {
            return .heading(level: 2, text: String(line.dropFirst(3)))
        } else if line.hasPrefix("# ") {
            return .heading(level: 1, text: String(line.dropFirst(2)))
        }
        return nil
    }

    // MARK: - Rendering

    @ViewBuilder
    private func renderElement(_ element: MarkdownElement) -> some View {
        switch element {
        case .heading(let level, let text):
            renderInlineText(text)
                .font(headingFont(level))
                .fontWeight(.bold)
                .padding(.top, level == 1 ? 8 : 4)

        case .bulletItem(let text):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\u{2022}")
                    .foregroundStyle(.secondary)
                renderInlineText(text)
            }
            .padding(.leading, 8)

        case .numberedItem(let number, let text):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(number)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                renderInlineText(text)
            }
            .padding(.leading, 8)

        case .codeBlock(let lines):
            Text(lines.joined(separator: "\n"))
                .font(.system(.callout, design: .monospaced))
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSM))

        case .blockquote(let text):
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Theme.amber)
                    .frame(width: 3)

                renderInlineText(text)
                    .italic()
                    .foregroundStyle(.secondary)
                    .padding(.leading, 10)
            }
            .padding(.vertical, 2)

        case .horizontalRule:
            Divider()
                .padding(.vertical, 4)

        case .paragraph(let text):
            renderInlineText(text)
        }
    }

    private func headingFont(_ level: Int) -> Font {
        switch level {
        case 1: return .title2
        case 2: return .title3
        default: return .headline
        }
    }

    /// Renders inline markdown: **bold**, *italic*, `code`, ~~strikethrough~~
    private func renderInlineText(_ text: String) -> Text {
        var result = Text("")
        var remaining = text[text.startIndex...]

        while !remaining.isEmpty {
            // Bold: **text**
            if remaining.hasPrefix("**") {
                let afterOpen = remaining.index(remaining.startIndex, offsetBy: 2)
                if afterOpen < remaining.endIndex,
                   let end = remaining[afterOpen...].range(of: "**") {
                    let inner = remaining[afterOpen..<end.lowerBound]
                    if !inner.isEmpty {
                        result = result + Text(inner).bold()
                        remaining = remaining[end.upperBound...]
                        continue
                    }
                }
                // No valid closing: treat as literal text
                result = result + Text("*")
                remaining = remaining[remaining.index(after: remaining.startIndex)...]
                continue
            }

            // Strikethrough: ~~text~~
            if remaining.hasPrefix("~~") {
                let afterOpen = remaining.index(remaining.startIndex, offsetBy: 2)
                if afterOpen < remaining.endIndex,
                   let end = remaining[afterOpen...].range(of: "~~") {
                    let inner = remaining[afterOpen..<end.lowerBound]
                    if !inner.isEmpty {
                        result = result + Text(inner).strikethrough()
                        remaining = remaining[end.upperBound...]
                        continue
                    }
                }
                // No valid closing: treat as literal
                result = result + Text("~")
                remaining = remaining[remaining.index(after: remaining.startIndex)...]
                continue
            }

            // Italic: *text* (must not start with **)
            if remaining.hasPrefix("*"),
               !remaining.hasPrefix("**") {
                let afterOpen = remaining.index(after: remaining.startIndex)
                if afterOpen < remaining.endIndex,
                   let end = remaining[afterOpen...].range(of: "*") {
                    let inner = remaining[afterOpen..<end.lowerBound]
                    if !inner.isEmpty {
                        result = result + Text(inner).italic()
                        remaining = remaining[end.upperBound...]
                        continue
                    }
                }
                // No valid closing: treat as literal
                result = result + Text("*")
                remaining = remaining[remaining.index(after: remaining.startIndex)...]
                continue
            }

            // Inline code: `text`
            if remaining.hasPrefix("`") {
                let afterOpen = remaining.index(after: remaining.startIndex)
                if afterOpen < remaining.endIndex,
                   let end = remaining[afterOpen...].range(of: "`") {
                    let inner = remaining[afterOpen..<end.lowerBound]
                    if !inner.isEmpty {
                        result = result + Text(inner)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(Theme.mauve)
                        remaining = remaining[end.upperBound...]
                        continue
                    }
                }
                // No valid closing: treat as literal
                result = result + Text("`")
                remaining = remaining[remaining.index(after: remaining.startIndex)...]
                continue
            }

            // Accumulate plain text run until the next markdown marker
            var plainEnd = remaining.index(after: remaining.startIndex)
            while plainEnd < remaining.endIndex {
                let ch = remaining[plainEnd]
                if ch == "*" || ch == "~" || ch == "`" { break }
                plainEnd = remaining.index(after: plainEnd)
            }
            result = result + Text(remaining[remaining.startIndex..<plainEnd])
            remaining = remaining[plainEnd...]
        }

        return result
    }
}
