import Testing
@testable import Logging

@Suite struct LoggingTests {
    
    @Test func testCollectingLogger() async throws {
        
        enum IndifferentLoggingMode {
            case indifferent
        }
        
        let logger = CollectingLogger<String, IndifferentLoggingMode>()
        
        logger.log("hello", withMode: .indifferent)
        logger.log("error!")
        
        #expect(logger.getMessages() == ["hello", "error!"])
    }
    
}
