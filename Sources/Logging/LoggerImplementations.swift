import Foundation

/// A logger just collecting all logging messages.
public class CollectingLogger: ConcurrentLogger, @unchecked Sendable {
    
    private var messages = [String]()
    
    public override init() {
        super.init()
        loggingAction = { message in
            self.messages.append(message)
        }
    }
    
    /// Get all collected message events.
    public func getMessages() -> [String] {
        var messages: [String]? = nil
        group.enter()
        self.queue.sync {
            messages = self.messages
            self.group.leave()
        }
        return messages!
    }
}

/// A logger that just prints to the standard output.
public final class PrintLogger: ConcurrentLogger, @unchecked Sendable {
    
    public init(errorsToStandard: Bool = false) {
        super.init()
        loggingAction = { message in
            print(message)
        }
    }
    
}

func printToErrorOut(_ text: String) {
    FileHandle.standardError.write(Data(text.utf8))
}

/// A logger that just prints to the error output.
public class ErrorPrintLogger: ConcurrentLogger, @unchecked Sendable {
    
    public init(errorsToStandard: Bool = false) {
        super.init()
        loggingAction = { message in
            printToErrorOut(message)
        }
    }
    
}

/// A logger writing into a file.
public final class FileLogger: ConcurrentLogger, @unchecked Sendable {
    
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
        loggingAction = { message in
            do {
                try self.writableFile.reopen()
                try self.writableFile.write(message)
                if !self.writableFile.blocking {
                    try self.writableFile.close()
                }
            }
            catch {
                printToErrorOut("could not log to \(path)")
            }
        }
        closeAction = {
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
public final class FileCrashLogger: ConcurrentCrashLogger, @unchecked Sendable {
    
    public let path: String
    var writableFile: WritableFile
    
    public init(
        usingFile path: String,
        append: Bool = true
    ) throws {
        self.path = path
        writableFile = try WritableFile(path: path, append: append)
        super.init()
        loggingAction = { message in
            do {
                try self.writableFile.write(message)
                try self.writableFile.flush()
            }
            catch {
                printToErrorOut("could not log to \(path)")
            }
        }
        closeAction = {
            do {
                try self.writableFile.close()
            }
            catch {
                printToErrorOut("could not log to \(path)")
            }
        }
    }
}

/// A logger that adds a prefix to all message texts
/// before forwarding it to the contained logger.
/// The referenced loggers are being closed when the
/// PrefixedLogger is being closed.
public final class PrefixedLogger: Logger {
    
    let prefix: String
    let logger: Logger
    
    public init(prefix: String, logger: Logger) {
        self.prefix = prefix
        self.logger = logger
    }
    
    public func log(_ message: String) {
        logger.log("\(prefix)\(message)")
    }
    
    public func close() throws {
        try logger.close()
    }
}
