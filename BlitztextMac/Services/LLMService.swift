import Foundation

enum LLMError: LocalizedError {
    case notConfigured
    case networkError(String)
    case apiError(String)
    case noContent

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Anthropic API Key fehlt. Bitte in den Einstellungen hinterlegen."
        case .networkError(let msg):
            return "Verbindungsproblem: \(msg)"
        case .apiError(let msg):
            return "Fehler von Anthropic: \(msg)"
        case .noContent:
            return "Keine Antwort erhalten. Bitte nochmal versuchen."
        }
    }
}

enum RewriteModel: String {
    case fastEdit = "claude-haiku-4-5-20251001"
    case rageMode = "claude-sonnet-4-6"
}

private struct AnthropicMessagesRequest: Encodable {
    struct Message: Encodable {
        let role: String
        let content: String
    }

    let model: String
    let maxTokens: Int
    let system: String
    let messages: [Message]
    let temperature: Double

    enum CodingKeys: String, CodingKey {
        case model
        case maxTokens = "max_tokens"
        case system
        case messages
        case temperature
    }
}

private struct AnthropicMessagesResponse: Decodable {
    struct ContentBlock: Decodable {
        let type: String?
        let text: String?
    }

    let content: [ContentBlock]?
}

private struct AnthropicErrorResponse: Decodable {
    struct APIError: Decodable {
        let message: String?
    }

    let error: APIError?
}

enum LLMService {
    private static let messagesURL = URL(string: "https://api.anthropic.com/v1/messages")!
    private static let anthropicVersion = "2023-06-01"
    private static let maxTokens = 4096

    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.waitsForConnectivity = false
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 45
        configuration.timeoutIntervalForResource = 45
        return URLSession(configuration: configuration)
    }()

    static func improve(
        text: String,
        settings: TextImprovementSettings,
        model: RewriteModel = .fastEdit
    ) async throws -> String {
        try await complete(
            text: text,
            systemPrompt: buildSystemPrompt(settings: settings),
            model: model,
            temperature: 0.3
        )
    }

    static func dampfAblassen(
        text: String,
        systemPrompt: String,
        model: RewriteModel = .rageMode
    ) async throws -> String {
        try await complete(
            text: text,
            systemPrompt: systemPrompt,
            model: model,
            temperature: 0.4
        )
    }

    static func generateConcept(
        text: String,
        settings: ConceptSettings,
        model: RewriteModel = .rageMode
    ) async throws -> String {
        try await complete(
            text: text,
            systemPrompt: buildConceptSystemPrompt(context: settings.context),
            model: model,
            temperature: 0.3
        )
    }

    static func translate(
        text: String,
        settings: TranslateSettings,
        model: RewriteModel = .rageMode
    ) async throws -> String {
        try await complete(
            text: text,
            systemPrompt: buildTranslateSystemPrompt(target: settings.targetLanguage),
            model: model,
            temperature: 0.3,
            spellingOverride: settings.targetLanguage.germanSpelling
        )
    }

    static func addEmojis(
        text: String,
        settings: EmojiTextSettings,
        model: RewriteModel = .fastEdit
    ) async throws -> String {
        try await complete(
            text: text,
            systemPrompt: buildEmojiSystemPrompt(density: settings.emojiDensity),
            model: model,
            temperature: 0.3
        )
    }

    private static func complete(
        text: String,
        systemPrompt: String,
        model: RewriteModel,
        temperature: Double,
        spellingOverride: GermanSpelling? = nil
    ) async throws -> String {
        guard let apiKey = KeychainService.load(key: .anthropicAPIKey) else {
            throw LLMError.notConfigured
        }

        let spelling = spellingOverride ?? GermanSpelling.current

        let payload = AnthropicMessagesRequest(
            model: model.rawValue,
            maxTokens: maxTokens,
            system: systemPrompt + spelling.promptInstruction,
            messages: [
                .init(role: "user", content: text),
            ],
            temperature: temperature
        )

        var request = URLRequest(url: messagesURL)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(anthropicVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 45
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.networkError("Keine gültige Antwort")
        }

        guard httpResponse.statusCode == 200 else {
            throw LLMError.apiError(anthropicErrorMessage(from: data) ?? "Status \(httpResponse.statusCode)")
        }

        let result = try JSONDecoder().decode(AnthropicMessagesResponse.self, from: data)
        let content = result.content?
            .compactMap { $0.type == "text" ? $0.text : nil }
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !content.isEmpty else {
            throw LLMError.noContent
        }

        return spelling.normalized(content)
    }

    private static func anthropicErrorMessage(from data: Data) -> String? {
        (try? JSONDecoder().decode(AnthropicErrorResponse.self, from: data))?.error?.message
    }

    private static func buildConceptSystemPrompt(context: String) -> String {
        var prompt = """
        Du erhältst ein frei gesprochenes, oft sprunghaftes Transkript. Mache daraus ein klar strukturiertes Konzept als reinen Text.

        Regeln:
        - Bleibe nah am Gesprochenen: ordnen, gruppieren, Wiederholungen und Füllwörter entfernen, Grammatik und Satzbau glätten. Füge KEINE neuen Inhalte, Fakten oder Punkte hinzu, die nicht gesagt wurden.
        - Erkenne die Themen-/Aufgabenbereiche im Gesprochenen und gliedere danach.
        - Format (einfacher Klartext, KEIN Markdown):
          - Beginne mit einer kurzen Überschrift/Titelzeile.
          - Danach ein zusammenhängender Textblock zu diesem Thema.
          - Dann eine Leerzeile, danach bei Bedarf die nächste Überschrift und ihr Textblock, usw.
          - Aufzählungen beginnen mit "– " (Gedankenstrich und Leerzeichen), jede auf einer eigenen Zeile.
        - Keine Sonderzeichen zur Auszeichnung (kein #, *, **, keine Nummerierung, ausser sie wurde so gesprochen).
        - Schreibe in der Sprache des Transkripts.
        - Gib NUR das fertige Konzept aus, keine Einleitung, keine Erklärungen, keine Meta-Kommentare.
        """

        let trimmedContext = context.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedContext.isEmpty {
            prompt += "\n\nKontext zum Inhalt (nur zur Orientierung, nicht ausgeben): \(trimmedContext)"
        }

        return prompt
    }

    private static func buildTranslateSystemPrompt(target: TranslationLanguage) -> String {
        """
        Du erhältst ein frei gesprochenes Transkript. Übersetze es nach \(target.promptName).

        Regeln:
        - Gib die Übersetzung in natürlicher, idiomatischer Sprache aus – so, wie ein Mensch es geschrieben hätte, nicht wörtlich Wort für Wort.
        - Korrigiere Grammatik, entferne Füllwörter, Versprecher und Wiederholungen, und strukturiere den Text sauber (sinnvolle Sätze und Absätze).
        - Bewahre Bedeutung, Tonfall und Absicht des Originals.
        - Erfinde keine Inhalte dazu.
        - Gib NUR die fertige Übersetzung aus, keine Einleitung, keine Erklärungen, keine Anmerkungen.
        """
    }

    private static func buildEmojiSystemPrompt(density: EmojiTextSettings.EmojiDensity) -> String {
        let densityInstruction: String
        switch density {
        case .wenig:
            densityInstruction = "Setze nur vereinzelt Emojis ein, maximal 1-2 pro Absatz."
        case .mittel:
            densityInstruction = "Setze regelmaessig passende Emojis ein, etwa alle 1-2 Saetze."
        case .viel:
            densityInstruction = "Setze grosszuegig Emojis ein, gerne mehrere pro Satz."
        }

        return "Du erhaeltst ein gesprochenes Transkript. Gib den Text moeglichst originalgetreu zurueck, aber fuege passende Emojis ein. \(densityInstruction) Korrigiere offensichtliche Sprach- und Grammatikfehler. Behalte den Stil und die Bedeutung bei. Gib NUR den Text mit Emojis zurueck, keine Erklaerungen."
    }

    private static func buildSystemPrompt(settings: TextImprovementSettings) -> String {
        if !settings.systemPrompt.isEmpty {
            var prompt = settings.systemPrompt
            if !settings.customTerms.isEmpty {
                prompt += "\n\nWichtig: Diese Eigennamen und Fachbegriffe muessen exakt so geschrieben werden: \(settings.customTerms.joined(separator: ", "))"
            }
            return prompt
        }

        var prompt = """
        Du bist ein Lektor und Schreibassistent. Verbessere den folgenden Text:
        - Korrigiere Rechtschreibung und Grammatik
        - Verbessere die Formulierung und den Lesefluss
        - Behalte die urspruengliche Bedeutung bei
        - Gib NUR den verbesserten Text zurueck, keine Erklaerungen
        """

        switch settings.tone {
        case .formal:
            prompt += "\n- Verwende einen formellen, professionellen Ton"
        case .neutral:
            prompt += "\n- Verwende einen neutralen, klaren Ton"
        case .casual:
            prompt += "\n- Verwende einen lockeren, natuerlichen Ton"
        }

        if !settings.customTerms.isEmpty {
            prompt += "\n\nWichtig: Diese Eigennamen und Fachbegriffe muessen exakt so geschrieben werden: \(settings.customTerms.joined(separator: ", "))"
        }

        if !settings.context.isEmpty {
            prompt += "\n\nKontext: \(settings.context)"
        }

        return prompt
    }
}
