import Foundation
import LoggingInterfaces

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
    internal let queue: DispatchQueue
    
    public var loggingAction: (@Sendable (Message,Mode?) -> ())? = nil
    public var closeAction: (@Sendable () -> ())? = nil
    
    public init(
        loggingAction: (@Sendable (Message,Mode?) -> ())? = nil,
        closeAction: (@Sendable () -> ())? = nil,
        qualityOfService: DispatchQoS = .userInitiated
    ) {
        self.loggingAction = loggingAction
        self.closeAction = closeAction
        queue = DispatchQueue(label: "ConcurrentLogger", qos: qualityOfService)
    }
    
    private var closed = false
    
    open func log(_ message: Message, withMode mode: Mode? = nil) {
        group.enter()
        self.queue.async {
            if !self.closed {
                self.loggingAction?(message, mode)
            }
            self.group.leave()
        }
    }
    
    open func close() throws {
        group.wait()
        group.enter()
        self.queue.async {
            if !self.closed {
                self.closeAction?()
                self.loggingAction = nil
                self.closeAction = nil
                self.closed = true
            }
            self.group.leave()
        }
        group.wait()
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
    
    private let queue: DispatchQueue
    
    public var loggingAction: (@Sendable (Message,Mode?) -> ())? = nil
    public var closeAction: (@Sendable () -> ())? = nil
    
    public init(
        loggingAction: (@Sendable (Message,Mode?) -> ())? = nil,
        closeAction: (@Sendable () -> ())? = nil,
        qualityOfService: DispatchQoS = .userInitiated
    ) {
        self.loggingAction = loggingAction
        self.closeAction = closeAction
        queue = DispatchQueue(label: "AyncLogger", qos: qualityOfService)
    }
    
    private var closed = false
    
    open func log(_ message: Message, withMode mode: Mode? = nil) {
        self.queue.sync {
            if !self.closed {
                loggingAction?(message, mode)
            }
        }
    }
    
    open func close() {
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
