import Foundation
import LoggingInterfaces

/// A logger just collecting all logging messages.
public class CollectingLogger<Message: Sendable & CustomStringConvertible,Mode: Sendable>: ConcurrentLogger<Message,Mode>, @unchecked Sendable {
    
    public typealias Message = Message
    public typealias Mode = Mode
    
    private var messages = [Message]()
    
    public init(errorsToStandard: Bool = false) {
        super.init()
        loggingAction = { message,printMode in
            self.messages.append(message)
        }
    }
    
    /// Get all collected message events.
    public func getMessages() -> [Message] {
        var messages: [Message]? = nil
        group.enter()
        self.queue.sync {
            messages = self.messages
            self.group.leave()
        }
        return messages!
    }
}

func printToErrorOut(_ message: CustomStringConvertible) {
    FileHandle.standardError.write(Data("\(message)\n".utf8))
}

/// A logger that just prints to the standard output.
public final class PrintLogger<Message: Sendable & CustomStringConvertible,Mode>: ConcurrentLogger<Message,PrintMode>, @unchecked Sendable {
    
    public typealias Message = Message
    public typealias Mode = PrintMode
    
    let errorsToStandard: Bool
    
    public init(errorsToStandard: Bool = false) {
        self.errorsToStandard = errorsToStandard
        super.init()
        loggingAction = { message,printMode in
            if errorsToStandard {
                print(message.description)
            } else {
                switch printMode {
                case .standard, nil:
                    print(message.description)
                case .error:
                    printToErrorOut(message.description)
                }
            }
        }
    }
    
}

/// A logger writing into a file.
public final class FileLogger<Message: Sendable & CustomStringConvertible,Mode: Sendable>: ConcurrentLogger<Message,Mode>, @unchecked Sendable {
    
    public typealias Message = Message
    public typealias Mode = Mode
    
    public let path: String
    var writableFile: WritableFile
    
    public init(
        usingFile path: String,
        append: Bool = false,
        blocking: Bool = true
    ) throws {
        self.path = path
        self.writableFile = try WritableFile(path: path, append: append, blocking: blocking)
        super.init()
        self.loggingAction = { message,mode in
            do {
                try self.writableFile.reopen()
                try self.writableFile.write(message.description)
                if !self.writableFile.blocking {
                    try self.writableFile.close()
                }
            }
            catch {
                printToErrorOut("could not log to \(path)")
            }
        }
        self.closeAction = {
            do {
                try self.writableFile.close()
            }
            catch {
                printToErrorOut("could not log to \(path)")
            }
        }
    }
    
}

/// A logger writing immediately into a file.
public final class FileCrashLogger<Message: Sendable & CustomStringConvertible,Mode>: ConcurrentCrashLogger<Message,IndifferentLoggingMode>, @unchecked Sendable {
    
    public typealias Message = Message
    public typealias Mode = Mode
    
    public let path: String
    var writableFile: WritableFile
    
    public init(
        usingFile path: String,
        append: Bool = false,
        blocking: Bool = true
    ) throws {
        self.path = path
        writableFile = try WritableFile(path: path, append: append, blocking: blocking)
        super.init()
        self.loggingAction = { message,mode in
            do {
                try self.writableFile.reopen()
                try self.writableFile.write(message.description)
                if !self.writableFile.blocking {
                    try self.writableFile.close()
                }
            }
            catch {
                printToErrorOut("could not log to \(path)")
            }
        }
        self.closeAction = {
            do {
                try self.writableFile.close()
            }
            catch {
                printToErrorOut("could not log to \(path)")
            }
        }
    }
    
}
