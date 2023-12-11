//
//  SBClientController.swift
//  Submariner
//
//  Created by Calvin Buckley on 2023-06-13.
//  Copyright © 2023 Submariner Developers. All rights reserved.
//

import Cocoa
import os

fileprivate let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "SBClientController")

class SBSubsonicRequestOperation: SBOperation {
    typealias ParsingCustomization = ((SBSubsonicParsingOperation) -> Void)
    
    var server: SBServer // like parsing we need to do the same throwing away again
    
    let parameters: [String: String]
    let request: SBSubsonicRequestType
    var url: URL? // XXX: Make into let
    var customization: ParsingCustomization? = nil
    
    init(server: SBServer, request: SBSubsonicRequestType) {
        self.server = server
        parameters = server.getBaseParameters()
        self.request = request
        
        // name is temporary
        let baseName = "Requesting from \(self.server.resourceName ?? "server")"
        super.init(managedObjectContext: server.managedObjectContext!, name: baseName)
        self.server = threadedContext.object(with: server.objectID) as! SBServer
        
        DispatchQueue.main.async {
            if let url = self.url {
                self.name = "Requesting from \(self.server.resourceName ?? "server"): \(url)"
            }
        }
        
        buildUrl()
    }
    
    // #MARK: - HTTP Requests
    
    private func request(url: URL, type: SBSubsonicRequestType, customization: ParsingCustomization? = nil) {
        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config)
        let request = URLRequest(url: url)
        // No auth header needed since we just pass them over query string
        
        let task = session.dataTask(with: request) { data, response, error in
            // sensitive because &p= contains user password
            logger.info("Handling URL \(url, privacy: .sensitive)")
            logger.info("\tAPI endpoint \(url.path, privacy: .public)")
            
            defer { self.finish() }
            
            if let error = error {
                DispatchQueue.main.async {
                    NSApp.presentError(error)
                }
                return
            } else if let response = response as? HTTPURLResponse {
                logger.info("\tStatus code is \(response.statusCode)")
                // Note that Subsonic and Navidrome return app-level error bodies in HTTP 200
                // HTTP 404s are used for unsupported features in Subsonic and Navidrome,
                // but OC Music uses code 70 Subsonic responses
                if response.statusCode == 404 {
                    self.server.markNotSupported(feature: type)
                    return
                } else if response.statusCode == 429 {
                    // Newer versions of Navidrome back getCoverArt w/ third-party APIs.
                    // As such, it rate limits API requests that can invoke them.
                    // Instead of bothering the user, retry the request later.

                    // Retry-After is seconds or a specific date
                    let retryAfter = response.value(forHTTPHeaderField: "Retry-After")
                    logger.info("Retrying w/ Retry-After value \(retryAfter ?? "<nil>")")

                    if let retryAfter = retryAfter,
                       let specificDate = retryAfter.dateTimeFromHTTP() {
                        _ = Timer(fire: specificDate, interval: 0, repeats: false) { timer in
                            self.request(url: url, type: type, customization: customization)
                            timer.invalidate()
                        }
                    } else {
                        // handle if Retry-After is valid, invalid, or missing
                        let seconds = TimeInterval(retryAfter ?? "5") ?? 5
                        _ = Timer(timeInterval: seconds, repeats: false) { timer in
                            self.request(url: url, type: type, customization: customization)
                            timer.invalidate()
                        }
                    }
                    return
                } else if response.statusCode != 200 {
                    let message = "HTTP \(response.statusCode) for \(url.path)"
                    let userInfo = [NSLocalizedDescriptionKey: message]
                    // XXX: Right domain?
                    let error = NSError(domain: NSURLErrorDomain, code: response.statusCode, userInfo: userInfo)
                    DispatchQueue.main.async {
                        NSApp.presentError(error)
                    }
                    return
                }
                
                if let operation = SBSubsonicParsingOperation(managedObjectContext: self.threadedContext,
                                                              requestType: type,
                                                              server: self.server.objectID,
                                                              xml: data,
                                                              mimeType: response.mimeType) {
                    if let customization = customization {
                        customization(operation)
                    }
                    OperationQueue.sharedServerQueue.addOperation(operation)
                }
            }
        }
        task.resume()
    }
    
    override func main() {
        if let url = self.url {
            request(url: url, type: self.request, customization: self.customization)
        } else {
            logger.error("URL was nil for request \(String(describing: self.request)), the server URL likely needs to be reset")
            self.finish()
        }
    }
    
    private func buildUrl() {
        switch request {
        case .ping:
            url = URL.URLWith(string: server.url, command: "rest/ping.view", parameters: parameters)
        case .getLicense:
            url = URL.URLWith(string: server.url, command: "rest/getLicense.view", parameters: parameters)
        case .getCoverArt(id: let id, forAlbumId: let albumId):
            var params = parameters
            params["id"] = id
            url = URL.URLWith(string: server.url, command: "rest/getCoverArt.view", parameters: params)
            customization = { operation in
                operation.currentCoverID = id
                operation.currentAlbumID = albumId
            }
        case .getPlaylists:
            url = URL.URLWith(string: server.url, command: "rest/getPlaylists.view", parameters: parameters)
        case .getAlbumList(type: let type):
            var params = parameters
            switch type {
            case .random:
                params["type"] = "random"
            case .newest:
                params["type"] = "newest"
            case .frequent:
                params["type"] = "frequent"
            case .highest:
                params["type"] = "highest"
            case .recent:
                params["type"] = "recent"
            default:
                logger.error("getAlbumList type: unrecognized")
                abort()
            }
            
            url = URL.URLWith(string: server.url, command: "rest/getAlbumList2.view", parameters: params)
        case .getPlaylist(id: let id):
            var params = parameters
            params["id"] = id
            url = URL.URLWith(string: server.url, command: "rest/getPlaylist.view", parameters: params)
            customization = { operation in
                operation.currentPlaylistID = id
            }
        case .deletePlaylist(id: let id):
            var params = parameters
            params["id"] = id
            url = URL.URLWith(string: server.url, command: "rest/deletePlaylist.view", parameters: params)
            customization = { operation in
                operation.currentPlaylistID = id
            }
        case .createPlaylist(name: let name, tracks: let tracks):
            var params = parameters
            params["name"] = name
            
            // XXX: DRY this with update
            let allParams = params.map { (k, v) in  URLQueryItem(name: k, value: v) } +
                tracks.map { track in URLQueryItem(name: "songId", value: track.itemId) }
            
            url = URL.URLWith(string: server.url, command: "rest/createPlaylist.view", queryItems: allParams)
        case .getNowPlaying:
            url = URL.URLWith(string: server.url, command: "rest/getNowPlaying.view", parameters: parameters)
        case .search(query: let query):
            var params = parameters
            params["query"] = query
            params["songCount"] = "100" // XXX: Configurable? Pagination?
            url = URL.URLWith(string: server.url, command: "rest/search3.view", parameters: params)
            customization = { operation in
                operation.currentSearch = SBSearchResult(query: query)
            }
        case .setRating(id: let id, rating: let rating):
            var params = parameters
            params["rating"] = String(rating)
            params["id"] = id
            url = URL.URLWith(string: server.url, command: "rest/setRating.view", parameters: params)
        case .getPodcasts:
            url = URL.URLWith(string: server.url, command: "rest/getPodcasts.view", parameters: parameters)
        case .scrobble(id: let id):
            var params = parameters
            params["id"] = id
            let currentTimeMS = Int64(Date().timeIntervalSince1970 * 1000)
            params["time"] = String(currentTimeMS)
            url = URL.URLWith(string: server.url, command: "rest/scrobble.view", parameters: params)
        case .scanLibrary:
            url = URL.URLWith(string: server.url, command: "rest/startScan.view", parameters: parameters)
        case .getScanStatus:
            url = URL.URLWith(string: server.url, command: "rest/getScanStatus.view", parameters: parameters)
        case .replacePlaylist(id: let id, tracks: let tracks):
            var params = parameters
            params["playlistId"] = id
            
            let allParams = params.map { (k, v) in  URLQueryItem(name: k, value: v) } +
                tracks.map { track in URLQueryItem(name: "songId", value: track.itemId) }
            
            url = URL.URLWith(string: server.url, command: "rest/createPlaylist.view", queryItems: allParams)
            customization = { operation in
                operation.currentPlaylistID = id
            }
        case .updatePlaylist(id: let id, name: let name, comment: let comment, isPublic: let isPublic, appending: let appending, removing: let removing):
            var params = parameters
            params["playlistId"] = id
            if let name = name {
                params["name"] = name
            }
            if let comment = comment {
                params["comment"] = comment
            }
            if let isPublic = isPublic {
                params["public"] = "\(isPublic)"
            }
            
            let allParams = params.map { (k, v) in  URLQueryItem(name: k, value: v) } +
                (appending?.map { track in URLQueryItem(name: "songIdToAdd", value: track.itemId) } ?? []) +
                (removing?.map { index in URLQueryItem(name: "songIndexToRemove", value: "\(index)") } ?? [])
            
            url = URL.URLWith(string: server.url, command: "rest/updatePlaylist.view", queryItems: allParams)
            customization = { operation in
                operation.currentPlaylistID = id
            }
        case .getArtists:
            url = URL.URLWith(string: server.url, command: "rest/getArtists.view", parameters: parameters)
        case .getArtist(id: let id):
            var params = parameters
            params["id"] = id
            url = URL.URLWith(string: server.url, command: "rest/getArtist.view", parameters: params)
            customization = { operation in
                operation.currentArtistID = id
            }
        case .getAlbum(id: let id):
            var params = parameters
            params["id"] = id
            url = URL.URLWith(string: server.url, command: "rest/getAlbum.view", parameters: params)
            customization = { operation in
                operation.currentAlbumID = id
            }
        case .getTrack(id: let id):
            var params = parameters
            params["id"] = id
            
            url = URL.URLWith(string: server.url, command: "rest/getSong.view", parameters: params)
        }
    }
}