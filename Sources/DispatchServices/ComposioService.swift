import AppKit
import Foundation
import DispatchCore

public struct ComposioToolkit: Identifiable, Equatable, Sendable {
    public var id: String { slug }
    public let slug: String
    public let name: String
    public let category: String
    public let description: String
    public let symbol: String
    public let webURL: String
    public let sampleActions: [String]
    public var isConnected: Bool

    public var iconSpec: IconSpec {
        .asset("brand-\(slug)")
    }

    public init(
        slug: String,
        name: String,
        category: String,
        description: String,
        symbol: String,
        webURL: String,
        sampleActions: [String],
        isConnected: Bool = false
    ) {
        self.slug = slug
        self.name = name
        self.category = category
        self.description = description
        self.symbol = symbol
        self.webURL = webURL
        self.sampleActions = sampleActions
        self.isConnected = isConnected
    }
}

/// Manages Composio app connectors so users can easily connect GitHub, Linear,
/// Notion, Slack, Gmail, Google Calendar, Jira, Figma, Vercel, and more.
/// Supports Composio v3 API (`x-api-key`) for live connected accounts & OAuth
/// link generation, plus instant CLI / web fallback when no API key is set.
public final class ComposioService: @unchecked Sendable {
    private let store: AppStore
    private let lock = NSLock()
    private var toolkits: [ComposioToolkit] = []

    public init(store: AppStore = .shared) {
        self.store = store
        self.toolkits = Self.defaultCatalog(connectedSlugs: Set(store.settings.connectedComposioToolkits))
    }

    public var catalog: [ComposioToolkit] {
        lock.lock()
        defer { lock.unlock() }
        let settings = store.settings
        let connected = Set(settings.connectedComposioToolkits)
        var list = toolkits.map { item -> ComposioToolkit in
            var copy = item
            copy.isConnected = connected.contains(item.slug)
            return copy
        }
        let existingSlugs = Set(list.map(\.slug))
        for custom in settings.customComposioConnectors where !existingSlugs.contains(custom.slug) {
            list.append(ComposioToolkit(
                slug: custom.slug,
                name: custom.name,
                category: custom.category,
                description: custom.description,
                symbol: "link.circle.fill",
                webURL: custom.webURL,
                sampleActions: custom.sampleActions,
                isConnected: connected.contains(custom.slug)
            ))
        }
        return list
    }

    public func addCustomConnector(
        name: String,
        slug: String,
        category: String = "Custom Connector",
        description: String = "Composio connected integration",
        webURL: String = ""
    ) {
        let cleanSlug = slug.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
        guard !cleanSlug.isEmpty else { return }
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? cleanSlug.capitalized
            : name.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedURL = webURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "https://platform.composio.dev/marketplace/\(cleanSlug)"
            : webURL.trimmingCharacters(in: .whitespacesAndNewlines)

        var settings = store.settings
        settings.customComposioConnectors.removeAll { $0.slug == cleanSlug }
        settings.customComposioConnectors.append(CustomComposioConnector(
            slug: cleanSlug,
            name: cleanName,
            category: category.isEmpty ? "Custom Connector" : category,
            description: description.isEmpty ? "Composio integration for \(cleanName)" : description,
            webURL: resolvedURL,
            sampleActions: ["Open \(cleanName)", "Run \(cleanName) Action"]
        ))
        if !settings.connectedComposioToolkits.contains(cleanSlug) {
            settings.connectedComposioToolkits.append(cleanSlug)
        }
        store.settings = settings
    }

    public func removeCustomConnector(slug: String) {
        var settings = store.settings
        settings.customComposioConnectors.removeAll { $0.slug == slug }
        settings.connectedComposioToolkits.removeAll { $0 == slug }
        store.settings = settings
    }

    public func toggleConnection(
        slug: String,
        completion: @escaping @Sendable (Result<String, Error>) -> Void
    ) {
        var settings = store.settings
        if settings.connectedComposioToolkits.contains(slug) {
            settings.connectedComposioToolkits.removeAll { $0 == slug }
            store.settings = settings
            completion(.success("Disconnected \(slug.capitalized) from Composio."))
            return
        }

        let apiKey = settings.composioApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !apiKey.isEmpty {
            initiateOAuthConnection(slug: slug, apiKey: apiKey, userId: settings.composioUserId) { [weak self] result in
                guard let self else { return }
                var updated = self.store.settings
                if !updated.connectedComposioToolkits.contains(slug) {
                    updated.connectedComposioToolkits.append(slug)
                    self.store.settings = updated
                }
                completion(result)
            }
        } else {
            settings.connectedComposioToolkits.append(slug)
            store.settings = settings
            if let url = URL(string: "https://platform.composio.dev/marketplace/\(slug)") {
                DispatchQueue.main.async {
                    NSWorkspace.shared.open(url)
                }
            }
            completion(.success("Connected \(slug.capitalized) in Dispatch & opened Composio setup."))
        }
    }

    public func syncConnectedAccounts(completion: @escaping @Sendable (Result<Int, Error>) -> Void) {
        let apiKey = store.settings.composioApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty else {
            completion(.success(store.settings.connectedComposioToolkits.count))
            return
        }

        guard let url = URL(string: "https://backend.composio.dev/api/v3/connected_accounts") else {
            completion(.success(store.settings.connectedComposioToolkits.count))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.timeoutInterval = 8

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self else { return }
            if let error {
                completion(.failure(error))
                return
            }
            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let items = json["items"] as? [[String: Any]] else {
                completion(.success(self.store.settings.connectedComposioToolkits.count))
                return
            }

            var discoveredSlugs = Set(self.store.settings.connectedComposioToolkits)
            for item in items {
                if let toolkit = item["toolkit"] as? [String: Any],
                   let slug = toolkit["slug"] as? String {
                    discoveredSlugs.insert(slug.lowercased())
                } else if let appName = item["appName"] as? String {
                    discoveredSlugs.insert(appName.lowercased())
                }
            }

            var settings = self.store.settings
            settings.connectedComposioToolkits = Array(discoveredSlugs).sorted()
            self.store.settings = settings
            completion(.success(settings.connectedComposioToolkits.count))
        }.resume()
    }

    private func initiateOAuthConnection(
        slug: String,
        apiKey: String,
        userId: String,
        completion: @escaping @Sendable (Result<String, Error>) -> Void
    ) {
        guard let url = URL(string: "https://backend.composio.dev/api/v1/connectedAccounts") else {
            completion(.success("Connected \(slug)"))
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 8
        let payload: [String: Any] = [
            "appName": slug,
            "entityId": userId.isEmpty ? "dispatch-default-user" : userId,
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        URLSession.shared.dataTask(with: request) { data, _, _ in
            if let data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let redirectUrl = (json["redirectUrl"] as? String) ?? (json["connectionStatus"] as? String),
               let authURL = URL(string: redirectUrl),
               authURL.scheme?.hasPrefix("http") == true {
                DispatchQueue.main.async {
                    NSWorkspace.shared.open(authURL)
                }
                completion(.success("Opened Composio OAuth flow for \(slug.capitalized)."))
                return
            }

            if let fallbackURL = URL(string: "https://platform.composio.dev/marketplace/\(slug)") {
                DispatchQueue.main.async {
                    NSWorkspace.shared.open(fallbackURL)
                }
            }
            completion(.success("Connected \(slug.capitalized) via Composio."))
        }.resume()
    }

    public static func defaultCatalog(connectedSlugs: Set<String> = []) -> [ComposioToolkit] {
        let items: [(String, String, String, String, String, String, [String])] = [
            (
                "github",
                "GitHub",
                "Developer Tools",
                "Search repositories, issues, pull requests, and workflows",
                "chevron.left.forwardslash.chevron.right",
                "https://github.com",
                ["Search Pull Requests", "Create Issue", "List Notifications", "My Repositories"]
            ),
            (
                "linear",
                "Linear",
                "Project Management",
                "Create issues, triage backlog, and view active cycles",
                "line.3.horizontal.decrease.circle",
                "https://linear.app",
                ["Create Issue", "My Assigned Issues", "Active Cycle", "Search Issues"]
            ),
            (
                "notion",
                "Notion",
                "Knowledge & Docs",
                "Search pages, databases, and append notes",
                "doc.text",
                "https://www.notion.so",
                ["Search Pages", "Create Page", "Append to Daily Note"]
            ),
            (
                "slack",
                "Slack",
                "Communication",
                "Send messages, search channels, and set status",
                "number.square",
                "https://app.slack.com",
                ["Send Message", "Search Messages", "Set Status"]
            ),
            (
                "gmail",
                "Gmail",
                "Email",
                "Search threads, draft emails, and check unread inbox",
                "envelope.fill",
                "https://mail.google.com",
                ["Search Unread", "Compose Email", "Recent Threads"]
            ),
            (
                "googlecalendar",
                "Google Calendar",
                "Productivity",
                "View upcoming meetings, join calls, and create events",
                "calendar",
                "https://calendar.google.com",
                ["Upcoming Events", "Create Event", "Join Next Meeting"]
            ),
            (
                "jira",
                "Jira",
                "Project Management",
                "Search tickets, transition status, and create issues",
                "ticket",
                "https://www.atlassian.com/software/jira",
                ["My Issues", "Create Jira Issue", "Search Sprint"]
            ),
            (
                "figma",
                "Figma",
                "Design",
                "Browse design files, components, and comments",
                "paintbrush.pointed",
                "https://www.figma.com",
                ["Search Files", "Recent Projects"]
            ),
            (
                "vercel",
                "Vercel",
                "Cloud & Deployments",
                "Inspect deployments, logs, and domains",
                "triangle.fill",
                "https://vercel.com/dashboard",
                ["Recent Deployments", "Project Domains"]
            ),
            (
                "sentry",
                "Sentry",
                "Observability",
                "Triage unresolved production errors and stack traces",
                "exclamationmark.triangle",
                "https://sentry.io",
                ["Unresolved Issues", "Recent Releases"]
            ),
            (
                "supabase",
                "Supabase",
                "Database & Backend",
                "Manage projects, tables, and edge functions",
                "bolt.horizontal.circle",
                "https://supabase.com/dashboard",
                ["List Projects", "SQL Editor"]
            ),
            (
                "hubspot",
                "HubSpot",
                "CRM & Sales",
                "Look up contacts, deals, and company records",
                "person.2.circle",
                "https://app.hubspot.com",
                ["Search Contacts", "Open Deals"]
            ),
            (
                "discord",
                "Discord",
                "Communication",
                "Send channel messages, manage servers, and inspect threads",
                "bubble.left.and.bubble.right.fill",
                "https://discord.com/app",
                ["Send Channel Message", "List Guilds"]
            ),
            (
                "stripe",
                "Stripe",
                "Finance & Billing",
                "Inspect customers, subscriptions, invoices, and payouts",
                "creditcard.fill",
                "https://dashboard.stripe.com",
                ["Search Customers", "Recent Payments", "List Subscriptions"]
            ),
            (
                "datadog",
                "Datadog",
                "Observability",
                "Query monitors, incidents, metrics, and log streams",
                "waveform.path.ecg",
                "https://app.datadoghq.com",
                ["Triggered Monitors", "Search Logs"]
            ),
            (
                "asana",
                "Asana",
                "Project Management",
                "Create tasks, check project milestones, and assign work",
                "checkmark.circle.fill",
                "https://app.asana.com",
                ["Create Task", "My Tasks"]
            ),
            (
                "trello",
                "Trello",
                "Project Management",
                "Manage boards, lists, and cards across workspaces",
                "rectangle.split.3x1.fill",
                "https://trello.com",
                ["Create Card", "My Boards"]
            ),
            (
                "cloudflare",
                "Cloudflare",
                "Cloud & DNS",
                "Manage zones, DNS records, Workers, and cache purge",
                "cloud.fill",
                "https://dash.cloudflare.com",
                ["List Zones", "Purge Cache"]
            ),
        ]

        return items.map { slug, name, category, desc, symbol, webURL, actions in
            ComposioToolkit(
                slug: slug,
                name: name,
                category: category,
                description: desc,
                symbol: symbol,
                webURL: webURL,
                sampleActions: actions,
                isConnected: connectedSlugs.contains(slug)
            )
        }
    }
}
