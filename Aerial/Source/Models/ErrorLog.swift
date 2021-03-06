//
//  ErrorLog.swift
//  Aerial
//
//  Created by Guillaume Louel on 17/10/2018.
//  Copyright © 2018 John Coates. All rights reserved.
//

import Cocoa
import os.log

enum ErrorLevel: Int {
    case info, debug, warning, error
}

final class LogMessage {
    let date: Date
    let level: ErrorLevel
    let message: String
    var actionName: String?
    var actionBlock: BlockOperation?

    init(level: ErrorLevel, message: String) {
        self.level = level
        self.message = message
        self.date = Date()
    }
}

typealias LoggerCallback = (ErrorLevel) -> Void

final class Logger {
    static let sharedInstance = Logger()

    var callbacks = [LoggerCallback]()

    func addCallback(_ callback:@escaping LoggerCallback) {
        callbacks.append(callback)
    }

    func callBack(level: ErrorLevel) {
        DispatchQueue.main.async {
            for callback in self.callbacks {
                callback(level)
            }
        }
    }
}
var errorMessages = [LogMessage]()

// swiftlint:disable:next identifier_name
func Log(level: ErrorLevel, message: String) {
    errorMessages.append(LogMessage(level: level, message: message))
    if level == .error {
        if #available(OSX 10.12, *) {
            // This is faster when available
            let log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "Screensaver")
            os_log("AerialError: %@", log: log, type: .error, message)
        } else {
            NSLog("AerialError: \(message)")
        }
    }

    let preferences = Preferences.sharedInstance
    if level == .warning || level == .error || (level == .debug && preferences.debugMode) {
        Logger.sharedInstance.callBack(level: level)
    }

    if preferences.logToDisk {
        DispatchQueue.main.async {
            let dateFormatter = DateFormatter()
            if preferences.logMilliseconds {
                dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
            } else {
                dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            }
            let string = dateFormatter.string(from: Date()) + " : " + message + "\n"

            if let cacheDirectory = VideoCache.appSupportDirectory {
                var cacheFileUrl = URL(fileURLWithPath: cacheDirectory as String)
                cacheFileUrl.appendPathComponent("AerialLog.txt")
                let data = string.data(using: String.Encoding.utf8, allowLossyConversion: false)!
                if FileManager.default.fileExists(atPath: cacheFileUrl.path) {
                    do {
                        let fileHandle = try FileHandle(forWritingTo: cacheFileUrl)
                        fileHandle.seekToEndOfFile()
                        fileHandle.write(data)
                        fileHandle.closeFile()
                    } catch {
                        NSLog("AerialError: Can't open handle for AerialLog.txt")
                    }
                } else {
                    do {
                        try data.write(to: cacheFileUrl, options: .atomic)  // Create the file
                    } catch {
                        NSLog("AerialError: Can't write to file AerialLog.txt")
                    }
                }
            }
        }
    }
}

func debugLog(_ message: String) {
    #if DEBUG
    print("\(message)\n")
    #endif

    // Comment the condition to always log debug mode
    let preferences = Preferences.sharedInstance
    if preferences.debugMode {
        Log(level: .debug, message: message)
    }
}

func infoLog(_ message: String) {
    Log(level: .info, message: message)
}

func warnLog(_ message: String) {
    Log(level: .warning, message: message)
}

func errorLog(_ message: String) {
    Log(level: .error, message: message)
}

func dataLog(_ data: Data) {
    let cacheDirectory = VideoCache.appSupportDirectory!
    var cacheFileUrl = URL(fileURLWithPath: cacheDirectory as String)
    cacheFileUrl.appendPathComponent("AerialData.txt")

    if FileManager.default.fileExists(atPath: cacheFileUrl.path) {
        do {
            let fileHandle = try FileHandle(forWritingTo: cacheFileUrl)
            fileHandle.seekToEndOfFile()
            fileHandle.write(data)
            fileHandle.closeFile()
        } catch {
            print("Can't open handle")
        }
    } else {
        do {
            try data.write(to: cacheFileUrl, options: .atomic)
        } catch {
            print("Can't write to file")
        }
    }

}
