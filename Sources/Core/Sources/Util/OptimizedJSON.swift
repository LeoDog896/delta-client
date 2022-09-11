// Wrapper around ZippyJSON that fallbacks to JSON if not on mac.

#if os(macOS)
    import ZippyJSON
#endif

public struct OptimizedJSONDecoder {
    init() {
        #if os(macOS)
            self.decoder = ZippyJSONDecoder()
        #else
            self.decoder = JSONDecoder()
        #endif
    }
}


public struct OptimizedJSONEncoder {
    init() {
        #if os(macOS)
            self.decoder = ZippyJSONEncoder()
        #else
            self.decoder = JSONEncoder()
        #endif
    }
}