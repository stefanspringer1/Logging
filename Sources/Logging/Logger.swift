import Foundation
import LoggingInterfaces

/// This is a logger that can be used to "merge" several other loggers,
/// i.e. all messages are being distributed to all loggers.
///
/// The use is limited because all loggers have to
/// understand the same logging mode.
public final class MultiLogger<Message: Sendable & CustomStringConvertible,Mode>: Logger {

    public typealias Message = Message
    public typealias Mode = Mode
    
    private let _loggers: [any Logger<Message,Mode>]
    
    public var loggers: [any Logger<Message,Mode>] { _loggers }
    
    public init(_ loggers: [any Logger<Message,Mode>]) {
        self._loggers = loggers
    }
    
    public func log(_ message: Message, withMode mode: Mode? = nil) {
        _loggers.forEach { logger in
            logger.log(message, withMode: mode)
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
open class ConcurrentLogger<Message: Sendable & CustomStringConvertible,Mode: Sendable>: Logger, @unchecked Sendable {
    
    public typealias Message = Message
    public typealias Mode = Mode
    
    internal let group = DispatchGroup()
    internal let queue = DispatchQueue(label: "ConcurrentLogger", qos: .background)
    
    public var loggingAction: (@Sendable (Message,Mode?) -> ())? = nil
    public var closeAction: (@Sendable () -> ())? = nil
    
    public init(
        loggingAction: (@Sendable (Message,Mode?) -> ())? = nil,
        closeAction: (@Sendable () -> ())? = nil
    ) {
        self.loggingAction = loggingAction
        self.closeAction = closeAction
    }
    
    private var closed = false
    
    public func log(_ message: Message, withMode mode: Mode? = nil) {
        group.enter()
        self.queue.async {
            if !self.closed {
                self.loggingAction?(message, mode)
            }
            self.group.leave()
        }
    }
    
    public func close() throws {
        group.enter()
        self.queue.sync {
            if !self.closed {
                self.closeAction?()
                self.loggingAction = nil
                self.closeAction = nil
                self.closed = true
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
open class ConcurrentCrashLogger<Message: Sendable & CustomStringConvertible,Mode: Sendable>: Logger, @unchecked Sendable {
    
    public typealias Message = Message
    public typealias Mode = Mode
    
    private let queue = DispatchQueue(label: "AyncLogger", qos: .background)
    
    public var loggingAction: (@Sendable (Message,Mode?) -> ())? = nil
    public var closeAction: (@Sendable () -> ())? = nil
    
    public init(
        loggingAction: (@Sendable (Message,Mode?) -> ())? = nil,
        closeAction: (@Sendable () -> ())? = nil
    ) {
        self.loggingAction = loggingAction
        self.closeAction = closeAction
    }
    
    private var closed = false
    
    public func log(_ message: Message, withMode mode: Mode? = nil) {
        self.queue.sync {
            if !self.closed {
                loggingAction?(message, mode)
            }
        }
    }
    
    public func close() {
        self.queue.sync {
            if !closed {
                closeAction?()
                closeAction = nil
                loggingAction = nil
                closed = true
            }
        }
    }
    
}
