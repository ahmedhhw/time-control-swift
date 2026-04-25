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
        case serverError(Int)
        case invalidResponse
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
            if urlError.code == .notConnectedToInternet ||
               urlError.code == .networkConnectionLost ||
               urlError.code == .cannotFindHost ||
               urlError.code == .cannotConnectToHost ||
               urlError.code == .timedOut {
                throw ADOError.networkUnavailable
            }
            throw ADOError.networkUnavailable
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
}
