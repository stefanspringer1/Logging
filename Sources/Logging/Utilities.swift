import Foundation

public struct LoggingError: Error, CustomStringConvertible  {
    public let description: String
    
    var localizedDescription: String { description }
    
    public init(_ description: String) {
        self.description = description
    }
}

/// A file that can be opened, closed, and reopened, and text can be written to it.
class WritableFile {
    
    public let path: String
    public let blocking: Bool
    var fileHandle: FileHandle?
    
    public func open(append: Bool = false) throws {
        let fileManager = FileManager.default
        if !append && fileManager.fileExists(atPath: path) {
            try fileManager.removeItem(atPath: path)
        }
        if !fileManager.fileExists(atPath: path) {
            fileManager.createFile(atPath: path, contents: nil)
        }
        let maybeFileHandle = FileHandle(forWritingAtPath: path)
        if let theFileHandle = maybeFileHandle {
            fileHandle = theFileHandle
            if append {
                try fileHandle?.seekToEnd()
            }
        } else {
            throw LoggingError("could not open \(path) \(append ? "to append" : "to write")")
        }
    }
    
    public func close() throws {
        if #available(macOS 10.15, *) {
            try fileHandle?.close()
        }
        fileHandle = nil
    }
    
    public func reopen() throws {
        if fileHandle == nil {
            try open(append: true)
        }
    }
    
    public init(path: String, append: Bool = false, blocking: Bool = true) throws {
        //blocking==true: keeps the log file open for performance reasons.
        //blocking==false: reopens and closes file every time it writes to it.
        self.path = path
        self.blocking = blocking
        if blocking {
            try self.open(append: append)
        }
    }
    
    private let NEWLINE = "\n".data(using: .utf8)!
    
    public func write(_ message: String, newline: Bool = true) throws {
        try self.reopen()
        fileHandle?.write(message.data(using: .utf8)!)
        if newline {
            fileHandle?.write(NEWLINE)
        }
        if !self.blocking {
            try self.close()
        }
    }
    
    public func flush() throws {
        if #available(macOS 10.15, *) {
            try fileHandle?.synchronize()
        } else {
            fileHandle?.synchronizeFile()
        }
    }

}
