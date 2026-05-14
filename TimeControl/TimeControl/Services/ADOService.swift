//
//  ADOService.swift
//  TimeControl
//

import Foundation

struct ADOUserProfile {
    let displayName: String
    let id: String
}

struct ADOWorkItem {
    let id: Int
    let title: String
    let description: String
    let state: String

    init(id: Int, title: String, description: String, state: String = "") {
        self.id = id
        self.title = title
        self.description = description
        self.state = state
    }
}

final class ADOService {

    enum ADOError: Error, Equatable {
        case unauthorized
        case notFound
        case networkUnavailable
        case tlsError
        case serverError(Int)
        case invalidResponse
        case urlError(Int)
    }

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchWorkItem(org: String, project: String, id: Int, pat: String) async throws -> ADOWorkItem {
        let urlString = "https://dev.azure.com/\(org)/\(project)/_apis/wit/workitems/\(id)?fields=System.Title,System.Description&api-version=7.1"
        guard let url = URL(string: urlString) else { throw ADOError.invalidResponse }

        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        let credentials = Data(":\(pat)".utf8).base64EncodedString()
        request.setValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let urlError as URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .cannotFindHost,
                 .cannotConnectToHost, .timedOut, .dnsLookupFailed:
                throw ADOError.urlError(urlError.errorCode)
            case .serverCertificateUntrusted, .serverCertificateHasBadDate,
                 .serverCertificateNotYetValid, .serverCertificateHasUnknownRoot,
                 .clientCertificateRequired, .secureConnectionFailed:
                throw ADOError.tlsError
            default:
                throw ADOError.urlError(urlError.errorCode)
            }
        }

        guard let http = response as? HTTPURLResponse else { throw ADOError.invalidResponse }

        switch http.statusCode {
        case 200:
            break
        case 401:
            throw ADOError.unauthorized
        case 404:
            throw ADOError.notFound
        default:
            throw ADOError.serverError(http.statusCode)
        }

        struct ResponseBody: Decodable {
            struct Fields: Decodable {
                let title: String
                let description: String
                enum CodingKeys: String, CodingKey {
                    case title = "System.Title"
                    case description = "System.Description"
                }
            }
            let id: Int
            let fields: Fields
        }

        guard let body = try? JSONDecoder().decode(ResponseBody.self, from: data) else {
            throw ADOError.invalidResponse
        }
        return ADOWorkItem(id: body.id, title: body.fields.title, description: body.fields.description)
    }

    func fetchComments(org: String, project: String, id: Int, pat: String) async throws -> [ADOComment] {
        let urlString = "https://dev.azure.com/\(org)/\(project)/_apis/wit/workitems/\(id)/comments?api-version=7.1-preview.3"
        guard let url = URL(string: urlString) else { throw ADOError.invalidResponse }

        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        let credentials = Data(":\(pat)".utf8).base64EncodedString()
        request.setValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let urlError as URLError {
            switch urlError.code {
            case .serverCertificateUntrusted, .serverCertificateHasBadDate,
                 .serverCertificateNotYetValid, .serverCertificateHasUnknownRoot,
                 .clientCertificateRequired, .secureConnectionFailed:
                throw ADOError.tlsError
            default:
                throw ADOError.urlError(urlError.errorCode)
            }
        }

        guard let http = response as? HTTPURLResponse else { throw ADOError.invalidResponse }

        switch http.statusCode {
        case 200: break
        case 401: throw ADOError.unauthorized
        case 404: throw ADOError.notFound
        default: throw ADOError.serverError(http.statusCode)
        }

        struct ResponseBody: Decodable {
            struct Comment: Decodable {
                struct CreatedBy: Decodable { let displayName: String }
                let id: Int
                let text: String
                let createdBy: CreatedBy
                let createdDate: Date
            }
            let comments: [Comment]
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let body = try? decoder.decode(ResponseBody.self, from: data) else {
            throw ADOError.invalidResponse
        }

        return body.comments
            .map { ADOComment(id: $0.id, text: $0.text, authorDisplayName: $0.createdBy.displayName, createdDate: $0.createdDate) }
            .sorted { $0.createdDate > $1.createdDate }
    }

    func searchUsers(org: String, query: String, pat: String) async throws -> [ADOUser] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        guard let url = URL(string: "https://vssps.dev.azure.com/\(org)/_apis/graph/subjectquery?api-version=7.1-preview.1") else {
            throw ADOError.invalidResponse
        }

        struct SubjectQuery: Encodable {
            let query: String
            let subjectKind: [String]
        }
        let requestBody = SubjectQuery(query: trimmed, subjectKind: ["User"])
        let encodedBody = try? JSONEncoder().encode(requestBody)
        print("[searchUsers] POST \(url) body: \(String(data: encodedBody ?? Data(), encoding: .utf8) ?? "<encode failed>")")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue(authHeader(pat: pat), forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = encodedBody

        let (data, response) = try await performRequest(request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
        let rawBody = String(data: data, encoding: .utf8) ?? "<unreadable>"
        print("[searchUsers] status: \(statusCode), response: \(rawBody)")

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            print("[searchUsers] non-200, returning empty")
            return []
        }

        struct GraphSubject: Decodable {
            let descriptor: String
            let displayName: String
            let mailAddress: String?
            let principalName: String?
        }
        struct GraphSubjectResponse: Decodable {
            let value: [GraphSubject]
        }

        guard let response = try? JSONDecoder().decode(GraphSubjectResponse.self, from: data) else {
            print("[searchUsers] decode failed, raw: \(rawBody)")
            return []
        }
        let subjects = response.value

        let users = subjects.compactMap { subject -> ADOUser? in
            let mail = subject.mailAddress ?? subject.principalName ?? ""
            return ADOUser(id: subject.descriptor, displayName: subject.displayName, mailAddress: mail)
        }
        print("[searchUsers] query '\(trimmed)' → \(users.count) users: \(users.map(\.displayName))")
        return users
    }

    func fetchStorageKey(org: String, descriptor: String, pat: String) async throws -> String {
        guard let url = URL(string: "https://vssps.dev.azure.com/\(org)/_apis/graph/storagekeys/\(descriptor)?api-version=7.1-preview.1") else {
            throw ADOError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        let credentials = Data(":\(pat)".utf8).base64EncodedString()
        request.setValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let urlError as URLError {
            throw ADOError.urlError(urlError.errorCode)
        }

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw ADOError.invalidResponse
        }

        struct StorageKeyResponse: Decodable { let value: String }
        guard let body = try? JSONDecoder().decode(StorageKeyResponse.self, from: data) else {
            throw ADOError.invalidResponse
        }
        return body.value
    }

    // MARK: - Bulk fetch

    func fetchAssignedWorkItems(org: String, project: String, pat: String) async throws -> [ADOWorkItem] {
        let query = "SELECT [System.Id] FROM WorkItems WHERE [System.AssignedTo] = @Me AND [System.State] <> 'Closed' ORDER BY [System.ChangedDate] DESC"
        return try await fetchWorkItems(org: org, project: project, pat: pat, wiqlQuery: query)
    }

    func fetchMentionedWorkItems(org: String, project: String, pat: String) async throws -> [ADOWorkItem] {
        let profile = try await fetchCurrentUserProfile(org: org, pat: pat)
        let ids = try await searchCommentMentions(org: org, project: project, pat: pat, displayName: profile.displayName)
        guard !ids.isEmpty else { return [] }
        return try await fetchWorkItemsBatch(org: org, project: project, pat: pat, ids: ids)
    }

    private func fetchWorkItems(org: String, project: String, pat: String, wiqlQuery: String) async throws -> [ADOWorkItem] {
        // Step 1: WIQL query to get IDs
        let wiqlURL = "https://dev.azure.com/\(org)/\(project)/_apis/wit/wiql?api-version=7.1"
        guard let url = URL(string: wiqlURL) else { throw ADOError.invalidResponse }

        var wiqlRequest = URLRequest(url: url)
        wiqlRequest.httpMethod = "POST"
        wiqlRequest.timeoutInterval = 30
        wiqlRequest.setValue(authHeader(pat: pat), forHTTPHeaderField: "Authorization")
        wiqlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        wiqlRequest.httpBody = try JSONEncoder().encode(["query": wiqlQuery])

        let (wiqlData, wiqlResponse) = try await performRequest(wiqlRequest)

        guard let wiqlHttp = wiqlResponse as? HTTPURLResponse else { throw ADOError.invalidResponse }
        switch wiqlHttp.statusCode {
        case 200: break
        case 401: throw ADOError.unauthorized
        default: throw ADOError.serverError(wiqlHttp.statusCode)
        }

        struct WIQLResponse: Decodable {
            struct WorkItemRef: Decodable { let id: Int }
            let workItems: [WorkItemRef]
        }

        guard let wiqlBody = try? JSONDecoder().decode(WIQLResponse.self, from: wiqlData) else {
            throw ADOError.invalidResponse
        }

        let ids = wiqlBody.workItems.map(\.id)
        guard !ids.isEmpty else { return [] }
        return try await fetchWorkItemsBatch(org: org, project: project, pat: pat, ids: ids)
    }

    private func fetchWorkItemsBatch(org: String, project: String, pat: String, ids: [Int]) async throws -> [ADOWorkItem] {
        let batchURL = "https://dev.azure.com/\(org)/\(project)/_apis/wit/workitemsbatch?api-version=7.1"
        guard let batchUrl = URL(string: batchURL) else { throw ADOError.invalidResponse }

        struct BatchRequest: Encodable {
            let ids: [Int]
            let fields: [String]
        }

        struct BatchResponse: Decodable {
            struct Item: Decodable {
                struct Fields: Decodable {
                    let title: String
                    let state: String
                    let description: String?
                    enum CodingKeys: String, CodingKey {
                        case title = "System.Title"
                        case state = "System.State"
                        case description = "System.Description"
                    }
                }
                let id: Int
                let fields: Fields
            }
            let value: [Item]
        }

        let chunks = stride(from: 0, to: ids.count, by: 200).map {
            Array(ids[$0..<min($0 + 200, ids.count)])
        }

        var all: [ADOWorkItem] = []
        for chunk in chunks {
            var batchRequest = URLRequest(url: batchUrl)
            batchRequest.httpMethod = "POST"
            batchRequest.timeoutInterval = 30
            batchRequest.setValue(authHeader(pat: pat), forHTTPHeaderField: "Authorization")
            batchRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            batchRequest.httpBody = try JSONEncoder().encode(BatchRequest(ids: chunk, fields: ["System.Title", "System.State", "System.Description"]))

            let (batchData, batchResponse) = try await performRequest(batchRequest)

            guard let batchHttp = batchResponse as? HTTPURLResponse else { throw ADOError.invalidResponse }
            switch batchHttp.statusCode {
            case 200: break
            case 401: throw ADOError.unauthorized
            default: throw ADOError.serverError(batchHttp.statusCode)
            }

            guard let body = try? JSONDecoder().decode(BatchResponse.self, from: batchData) else {
                throw ADOError.invalidResponse
            }
            all.append(contentsOf: body.value.map {
                ADOWorkItem(id: $0.id, title: $0.fields.title, description: $0.fields.description ?? "", state: $0.fields.state)
            })
        }
        return all
    }

    // MARK: - Private helpers

    func fetchCurrentUserProfile(org: String, pat: String) async throws -> ADOUserProfile {
        guard let url = URL(string: "https://dev.azure.com/\(org)/_apis/connectiondata") else {
            throw ADOError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue(authHeader(pat: pat), forHTTPHeaderField: "Authorization")

        let (data, response) = try await performRequest(request)

        guard let http = response as? HTTPURLResponse else { throw ADOError.invalidResponse }
        switch http.statusCode {
        case 200: break
        case 401: throw ADOError.unauthorized
        default: throw ADOError.serverError(http.statusCode)
        }

        struct ConnectionDataResponse: Decodable {
            struct AuthenticatedUser: Decodable {
                let providerDisplayName: String
                let id: String
            }
            let authenticatedUser: AuthenticatedUser
        }
        guard let body = try? JSONDecoder().decode(ConnectionDataResponse.self, from: data) else {
            throw ADOError.invalidResponse
        }
        return ADOUserProfile(displayName: body.authenticatedUser.providerDisplayName, id: body.authenticatedUser.id)
    }

    func searchCommentMentions(org: String, project: String, pat: String, displayName: String) async throws -> [Int] {
        let urlString = "https://almsearch.dev.azure.com/\(org)/\(project)/_apis/search/workitemsearchresults?api-version=7.1"
        guard let url = URL(string: urlString) else { throw ADOError.invalidResponse }

        struct SearchRequest: Encodable {
            let searchText: String
            let skip: Int
            let top: Int
            let filters: [String: [String]]
            let orderBy: [[String: String]]
            let includeFacets: Bool
            enum CodingKeys: String, CodingKey {
                case searchText
                case skip = "$skip"
                case top = "$top"
                case filters
                case orderBy = "$orderBy"
                case includeFacets
            }
        }
        let body = SearchRequest(
            searchText: "comment:\"@\(displayName)\"",
            skip: 0,
            top: 200,
            filters: ["System.TeamProject": [project]],
            orderBy: [["field": "system.changeddate", "sortOrder": "DESC"]],
            includeFacets: false
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue(authHeader(pat: pat), forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await performRequest(request)

        guard let http = response as? HTTPURLResponse else { throw ADOError.invalidResponse }
        switch http.statusCode {
        case 200: break
        case 401: throw ADOError.unauthorized
        default: throw ADOError.serverError(http.statusCode)
        }

        struct SearchResponse: Decodable {
            struct Result: Decodable {
                struct Fields: Decodable {
                    let id: String
                    enum CodingKeys: String, CodingKey { case id = "system.id" }
                }
                let fields: Fields
            }
            let results: [Result]
        }
        guard let responseBody = try? JSONDecoder().decode(SearchResponse.self, from: data) else {
            throw ADOError.invalidResponse
        }
        return responseBody.results.compactMap { Int($0.fields.id) }
    }

    private func authHeader(pat: String) -> String {
        "Basic " + Data(":\(pat)".utf8).base64EncodedString()
    }

    private func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch let urlError as URLError {
            switch urlError.code {
            case .serverCertificateUntrusted, .serverCertificateHasBadDate,
                 .serverCertificateNotYetValid, .serverCertificateHasUnknownRoot,
                 .clientCertificateRequired, .secureConnectionFailed:
                throw ADOError.tlsError
            default:
                throw ADOError.urlError(urlError.errorCode)
            }
        }
    }


    func uploadAttachment(org: String, project: String, filename: String, data: Data, pat: String) async throws -> URL {
        let encodedName = filename.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? filename
        let urlString = "https://dev.azure.com/\(org)/\(project)/_apis/wit/attachments?fileName=\(encodedName)&api-version=7.1"
        guard let url = URL(string: urlString) else { throw ADOError.invalidResponse }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        let credentials = Data(":\(pat)".utf8).base64EncodedString()
        request.setValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.httpBody = data

        let responseData: Data
        let response: URLResponse
        do {
            (responseData, response) = try await session.data(for: request)
        } catch let urlError as URLError {
            throw ADOError.urlError(urlError.errorCode)
        }

        guard let http = response as? HTTPURLResponse else { throw ADOError.invalidResponse }
        switch http.statusCode {
        case 200, 201:
            break
        case 401:
            throw ADOError.unauthorized
        default:
            throw ADOError.serverError(http.statusCode)
        }

        struct AttachmentResponse: Decodable { let url: String }
        guard let body = try? JSONDecoder().decode(AttachmentResponse.self, from: responseData),
              let resultURL = URL(string: body.url) else {
            throw ADOError.invalidResponse
        }
        return resultURL
    }

    func postComment(org: String, project: String, id: Int, comment: String, pat: String) async throws {
        let urlString = "https://dev.azure.com/\(org)/\(project)/_apis/wit/workitems/\(id)/comments?api-version=7.1-preview.3"
        guard let url = URL(string: urlString) else { throw ADOError.invalidResponse }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        let credentials = Data(":\(pat)".utf8).base64EncodedString()
        request.setValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(["text": comment])

        let response: URLResponse
        do {
            (_, response) = try await session.data(for: request)
        } catch let urlError as URLError {
            switch urlError.code {
            case .serverCertificateUntrusted, .serverCertificateHasBadDate,
                 .serverCertificateNotYetValid, .serverCertificateHasUnknownRoot,
                 .clientCertificateRequired, .secureConnectionFailed:
                throw ADOError.tlsError
            default:
                throw ADOError.urlError(urlError.errorCode)
            }
        }

        guard let http = response as? HTTPURLResponse else { throw ADOError.invalidResponse }
        switch http.statusCode {
        case 200, 201:
            return
        case 401:
            throw ADOError.unauthorized
        default:
            throw ADOError.serverError(http.statusCode)
        }
    }
}
