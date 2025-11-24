import Foundation

/// A logger, logging instances of `String`.
public protocol Logger: Sendable {
    func log(_ message: String)
    func close() throws
}

/// This is a logger that can be used to "merge" several other loggers,
/// i.e. all logging events are being distributed to all loggers.
public final class MultiLogger: Logger {
    
    private let _loggers: [Logger]
    
    public var loggers: [Logger] { _loggers }
    
    public init(_ loggers: Logger?...) {
        self._loggers = loggers.compactMap{$0}
    }
    
    public func log(_ message: String) {
        _loggers.forEach { logger in
            logger.log(message)
        }
    }
    
    public func close() throws {
        try _loggers.forEach { logger in
            try logger.close()
        }
    }
}

/// A concurrent wraper around some logging action.
/// The logging is done asynchronously, so the close() method
/// is to be called at the end of a process in order to be sure
/// that all logging is done.
///
/// In the case of a crash some logging might get lost, so the
/// use of an additional `ConcurrentCrashLogger` is sensible.
open class ConcurrentLogger: Logger, @unchecked Sendable {

    internal let group = DispatchGroup()
    internal let queue = DispatchQueue(label: "AyncLogger", qos: .background)
    
    public var loggingAction: ((String) -> ())? = nil
    public var closeAction: (() -> ())? = nil
    
    public init() {}
    
    private var closed = false
    
    public func log(_ message: String) {
        group.enter()
        self.queue.async {
            if !self.closed {
                self.loggingAction?(message)
            }
            self.group.leave()
        }
    }
    
    public func close() throws {
        group.enter()
        self.queue.sync {
            if !self.closed {
                self.closeAction?()
                self.closed = true
                self.closeAction = nil
                self.group.leave()
            }
        }
    }
    
}

/// This concurrent logger waits until the logging of the message is done.
/// This is convenient for save-logging of sparse events on so
/// is good for an additional "crash logger" which logs the executed steps
/// savely so in case of a crash one can know where the crashing takes place.
/// The repective log can be removed when all work is done.
open class ConcurrentCrashLogger: Logger, @unchecked Sendable {
    
    private let queue = DispatchQueue(label: "AyncLogger", qos: .background)
    
    public var loggingAction: ((String) -> ())? = nil
    public var closeAction: (() -> ())? = nil
    
    public init() {}
    
    private var closed = false
    
    public func log(_ message: String) {
        self.queue.sync {
            self.loggingAction?(message)
        }
    }
    
    public func close() {
        self.queue.sync {
            if !closed {
                closeAction?()
                closed = true
                closeAction = nil
            }
        }
    }
    
}
