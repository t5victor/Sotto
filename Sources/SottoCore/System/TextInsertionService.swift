import AppKit
import ApplicationServices
import Foundation

public struct InsertionTargetInfo: Equatable, Sendable {
    public let processIdentifier: pid_t
    public let applicationName: String?
    public let bundleIdentifier: String?

    public init(
        processIdentifier: pid_t,
        applicationName: String?,
        bundleIdentifier: String?
    ) {
        self.processIdentifier = processIdentifier
        self.applicationName = applicationName
        self.bundleIdentifier = bundleIdentifier
    }
}

