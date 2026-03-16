import Foundation

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

enum PasteboardClient {
    static func copy(_ string: String) {
        #if canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
        #elseif canImport(UIKit)
        UIPasteboard.general.string = string
        #endif
    }

    static func clearIfUnchanged(_ string: String) {
        #if canImport(AppKit)
        if NSPasteboard.general.string(forType: .string) == string {
            NSPasteboard.general.clearContents()
        }
        #elseif canImport(UIKit)
        if UIPasteboard.general.string == string {
            UIPasteboard.general.string = nil
        }
        #endif
    }
}
