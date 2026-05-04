//
//  ADOService.swift
//  TimeControl
//

import Foundation

struct ADOWorkItem {
    let id: Int
    let title: String
    let description: String
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
