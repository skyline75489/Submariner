//
//  SBSubsonicDownloadOperation.swift
//  Submariner
//
//  Created by Calvin Buckley on 2023-04-18.
//  Copyright © 2023 Submariner Developers. All rights reserved.
//

import Cocoa
import UniformTypeIdentifiers

@objc class SBSubsonicDownloadOperation: SBOperation, URLSessionDelegate, URLSessionTaskDelegate, URLSessionDownloadDelegate {
    static let DownloadStartedNotification = NSNotification.Name("SBSubsonicDownloadStarted")
    static let DownloadFinishedNotification = NSNotification.Name("SBSubsonicDownloadFinished")
    
    private let libraryID: SBLibraryID
    private let track: SBTrack
    
    let activity: SBOperationActivity
    
    @objc init!(managedObjectContext mainContext: NSManagedObjectContext!, trackID: SBTrackID) {
        // Reconstitute the track because Core Data objects can't cross thread boundaries.
        track = mainContext.object(with: trackID) as! SBTrack
        
        let activityName = String.init(format: "Downloading %@%@%@",
                                       Locale.current.quotationBeginDelimiter ?? "\"",
                                       track.itemName,
                                       Locale.current.quotationEndDelimiter ?? "\"")
        activity = SBOperationActivity(name: activityName)
        activity.operationInfo = "Pending Request..."
        activity.progress = .none
        // get the handle to the library ID
        let libraryRequest = NSFetchRequest<SBLibrary>(entityName: "Library")
        let library = try! mainContext.fetch(libraryRequest).first
        libraryID = library!.objectID()
        
        super.init(managedObjectContext: mainContext)
        
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: SBSubsonicDownloadOperation.DownloadStartedNotification, object: self.activity)
        }
    }
    
    override func main() {
        autoreleasepool {
            // We don't need to do any transformation here,
            // as downloadURL will get the auth params from SBServer.
            let url = track.downloadURL()!
            let request = URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 30)
            let configuration = URLSessionConfiguration.default
            let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
            let task = session.downloadTask(with: request)
            task.resume()
        }
    }
    
    override func finish() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: SBSubsonicDownloadOperation.DownloadFinishedNotification, object: self.activity)
        }
        super.finish()
    }
    
    // #MARK: -
    // #MARK: NSURLSession Delegate (Auth)
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if (challenge.previousFailureCount == 0) {
            let credential = URLCredential(user: track.server.username,
                                           password: track.server.password,
                                           persistence: .none)
            
            completionHandler(.useCredential, credential)
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
    
    // #MARK: -
    // #MARK: NSURLSession Delegate (State)
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            DispatchQueue.main.async {
                NSApp.presentError(error)
            }
            self.finish()
            session.invalidateAndCancel()
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // Success
        DispatchQueue.main.async {
            self.activity.operationInfo = "Importing track..."
        }
        
        // SBImportOperation needs an audio file extension. Rename the file.
        let fileType = UTType(mimeType: downloadTask.response?.mimeType ?? "audio/mp3") ?? UTType.mp3
        let temporaryFile = NSURL.temporaryFile().appendingPathExtension(for: fileType)
        try! FileManager.default.moveItem(at: location, to: temporaryFile)
        let temporaryFilePath = temporaryFile.path
        
        // Now import.
        if let importOperation = SBImportOperation(managedObjectContext: mainContext) {
            importOperation.filePaths = [temporaryFilePath]
            importOperation.copyFile = true
            importOperation.remove = true
            importOperation.libraryID = libraryID
            importOperation.remoteTrackID = track.objectID()
            OperationQueue.sharedDownloadQueue.addOperation(importOperation)
        }
        
        self.finish()
        session.invalidateAndCancel()
    }
    
    // #MARK: -
    // #MARK: NSURLSession Delegate (Progress)
    
    private let byteCountFormatter = MeasurementFormatter()
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let totalWritten = Measurement<UnitInformationStorage>(value: Double(totalBytesWritten), unit: .bytes).converted(to: .megabytes)
        
        if totalBytesExpectedToWrite != NSURLSessionTransferSizeUnknown {
            let totalToWrite = Measurement<UnitInformationStorage>(value: Double(totalBytesExpectedToWrite), unit: .bytes)
                .converted(to: .megabytes)
            DispatchQueue.main.async {
                self.activity.progress = .determinate(n: Float(totalBytesWritten), outOf: Float(totalBytesExpectedToWrite))
                self.activity.operationInfo = String.init(format: "Downloaded %@/%@",
                                                          self.byteCountFormatter.string(from: totalWritten),
                                                          self.byteCountFormatter.string(from: totalToWrite))
            }
        } else {
            DispatchQueue.main.async {
                self.activity.progress = .indeterminate(n: Float(totalBytesWritten))
                self.activity.operationInfo = String.init(format: "Downloaded %@",
                                                          self.byteCountFormatter.string(from: totalWritten))
            }
        }
    }
}
