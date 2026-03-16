import Foundation

struct CSVPasswordImportService {
    func parse(data: Data) throws -> [ImportedPasswordRecord] {
        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .utf16) else {
            throw CSVPasswordImportError.unreadableFile
        }

        let rows = parseRows(from: text)
        guard let headerRow = rows.first, !headerRow.isEmpty else {
            throw CSVPasswordImportError.missingHeader
        }

        let headerMap = Dictionary(uniqueKeysWithValues: headerRow.enumerated().map {
            (normalizeHeader($0.element), $0.offset)
        })

        let records = rows.dropFirst().compactMap { row -> ImportedPasswordRecord? in
            let password = value(in: row, headerMap: headerMap, keys: ["password", "passcode", "secret"])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !password.isEmpty else { return nil }

            let title = value(in: row, headerMap: headerMap, keys: ["name", "title", "service"])
            let website = value(in: row, headerMap: headerMap, keys: ["website", "url", "origin", "loginurl"])
            let username = value(in: row, headerMap: headerMap, keys: ["username", "login", "email", "account"])
            let notes = value(in: row, headerMap: headerMap, keys: ["notes", "note", "comment", "comments"])

            let service = preferredServiceName(title: title, website: website)
            guard !service.isEmpty else { return nil }

            return ImportedPasswordRecord(
                service: service,
                username: username,
                password: password,
                notes: notes,
                tags: []
            )
        }

        return records
    }

    private func parseRows(from text: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var isInsideQuotes = false

        for character in text {
            switch character {
            case "\"":
                isInsideQuotes.toggle()
            case "," where !isInsideQuotes:
                row.append(field)
                field = ""
            case "\n" where !isInsideQuotes:
                row.append(field)
                if !row.allSatisfy({ $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                    rows.append(row.map(cleanField))
                }
                row = []
                field = ""
            case "\r":
                continue
            default:
                field.append(character)
            }
        }

        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            if !row.allSatisfy({ $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                rows.append(row.map(cleanField))
            }
        }

        return rows
    }

    private func value(in row: [String], headerMap: [String: Int], keys: [String]) -> String {
        for key in keys {
            if let index = headerMap[key], row.indices.contains(index) {
                return row[index].trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return ""
    }

    private func normalizeHeader(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
    }

    private func cleanField(_ value: String) -> String {
        var cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("\""), cleaned.hasSuffix("\""), cleaned.count >= 2 {
            cleaned.removeFirst()
            cleaned.removeLast()
        }
        return cleaned.replacingOccurrences(of: "\"\"", with: "\"")
    }

    private func preferredServiceName(title: String, website: String) -> String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTitle.isEmpty {
            return trimmedTitle
        }

        guard let url = URL(string: website), let host = url.host else {
            return website.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return host.replacingOccurrences(of: "www.", with: "")
    }
}

struct ImportedPasswordRecord {
    let service: String
    let username: String
    let password: String
    let notes: String
    let tags: [String]
}

enum CSVPasswordImportError: LocalizedError {
    case unreadableFile
    case missingHeader

    var errorDescription: String? {
        switch self {
        case .unreadableFile:
            "The selected CSV could not be read."
        case .missingHeader:
            "The CSV file is missing a valid header row."
        }
    }
}
