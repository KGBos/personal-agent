import Foundation

/// Tool for fetching and reading web content
struct WebBrowsingTool: AgentTool {
    let name = "web_browse"
    let description = "Fetch and read content from a URL. Returns the main text content of the webpage."
    let requiresConfirmation = false // Read-only operation

    let parameterSchema = ToolParameterSchema(
        type: "object",
        description: nil,
        properties: [
            "url": .init(
                type: "string",
                description: "The URL to fetch (must be a valid http or https URL)",
                enumValues: nil,
                items: nil
            ),
            "max_length": .init(
                type: "number",
                description: "Maximum characters to return (default: 10000)",
                enumValues: nil,
                items: nil
            )
        ],
        required: ["url"]
    )

    func execute(arguments: [String: Any]) async throws -> String {
        guard let urlString = arguments["url"] as? String else {
            throw ToolError.invalidArguments("Missing required 'url' parameter")
        }

        guard let url = URL(string: urlString),
              let scheme = url.scheme,
              ["http", "https"].contains(scheme.lowercased()) else {
            throw ToolError.invalidArguments("Invalid URL. Must be a valid http or https URL")
        }

        let maxLength = arguments["max_length"] as? Int ?? 10000

        // Fetch the URL
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ToolError.executionFailed("Invalid response from server")
        }

        guard httpResponse.statusCode == 200 else {
            throw ToolError.executionFailed("HTTP error: \(httpResponse.statusCode)")
        }

        guard let htmlString = String(data: data, encoding: .utf8) else {
            throw ToolError.executionFailed("Could not decode response as text")
        }

        // Extract text content from HTML
        let textContent = extractTextFromHTML(htmlString)

        // Truncate if needed
        if textContent.count > maxLength {
            let truncated = String(textContent.prefix(maxLength))
            return "\(truncated)\n\n[Content truncated at \(maxLength) characters]"
        }

        return textContent
    }

    // MARK: - HTML Parsing

    private func extractTextFromHTML(_ html: String) -> String {
        var text = html

        // Remove script and style tags with their content
        text = removeTagWithContent(text, tag: "script")
        text = removeTagWithContent(text, tag: "style")
        text = removeTagWithContent(text, tag: "noscript")
        text = removeTagWithContent(text, tag: "nav")
        text = removeTagWithContent(text, tag: "footer")
        text = removeTagWithContent(text, tag: "header")

        // Remove HTML comments
        text = text.replacingOccurrences(of: "<!--[\\s\\S]*?-->", with: "", options: .regularExpression)

        // Replace common block elements with newlines
        let blockTags = ["</p>", "</div>", "</h1>", "</h2>", "</h3>", "</h4>", "</h5>", "</h6>",
                         "</li>", "</tr>", "<br>", "<br/>", "<br />"]
        for tag in blockTags {
            text = text.replacingOccurrences(of: tag, with: "\n", options: .caseInsensitive)
        }

        // Remove all remaining HTML tags
        text = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)

        // Decode HTML entities
        text = decodeHTMLEntities(text)

        // Clean up whitespace
        text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        text = text.replacingOccurrences(of: "\n\\s+", with: "\n", options: .regularExpression)
        text = text.replacingOccurrences(of: "\\s+\n", with: "\n", options: .regularExpression)
        text = text.replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func removeTagWithContent(_ html: String, tag: String) -> String {
        let pattern = "<\(tag)[^>]*>[\\s\\S]*?</\(tag)>"
        return html.replacingOccurrences(of: pattern, with: "", options: [.regularExpression, .caseInsensitive])
    }

    private func decodeHTMLEntities(_ text: String) -> String {
        var result = text

        let entities: [String: String] = [
            "&nbsp;": " ",
            "&amp;": "&",
            "&lt;": "<",
            "&gt;": ">",
            "&quot;": "\"",
            "&apos;": "'",
            "&#39;": "'",
            "&mdash;": "—",
            "&ndash;": "–",
            "&hellip;": "...",
            "&copy;": "©",
            "&reg;": "®",
            "&trade;": "™",
            "&bull;": "•",
            "&ldquo;": "\u{201C}",
            "&rdquo;": "\u{201D}",
            "&lsquo;": "\u{2018}",
            "&rsquo;": "\u{2019}"
        ]

        for (entity, replacement) in entities {
            result = result.replacingOccurrences(of: entity, with: replacement, options: .caseInsensitive)
        }

        // Handle numeric entities
        let numericPattern = "&#(\\d+);"
        if let regex = try? NSRegularExpression(pattern: numericPattern) {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "") { match, result in
                guard let match = match,
                      let range = Range(match.range(at: 1), in: result),
                      let codePoint = Int(result[range]),
                      let scalar = Unicode.Scalar(codePoint) else {
                    return nil
                }
                return String(Character(scalar))
            }
        }

        return result
    }
}

// MARK: - NSRegularExpression Extension

private extension NSRegularExpression {
    func stringByReplacingMatches(
        in string: String,
        range: NSRange,
        withTemplate template: String,
        using block: (NSTextCheckingResult?, String) -> String?
    ) -> String {
        var result = string
        let matches = self.matches(in: string, range: range).reversed()

        for match in matches {
            if let matchRange = Range(match.range, in: result),
               let replacement = block(match, result) {
                result.replaceSubrange(matchRange, with: replacement)
            }
        }

        return result
    }
}
