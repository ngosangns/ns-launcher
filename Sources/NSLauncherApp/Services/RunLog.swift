// RunLog.swift
//
// The two pieces of run-log handling that are decisions rather than plumbing: what gets kept, and
// how much of it is retained.
//
// Both used to live in `LauncherViewModel`, where they could not be tested — the filter is a state
// machine spread across three stored properties, and the retention rule only ran as a side effect
// of publishing to SwiftUI. Scheduling the flush stays in the view model, because deciding *when*
// to touch `@Published` state is genuinely its job; deciding *what* the log contains is not.

import Foundation

/// Drops the capability dumps that bury the one line explaining why a launch failed.
///
/// Stateful on purpose. MoltenVK announces itself and then prints a few hundred lines of Vulkan
/// extensions, which cannot be recognised line by line — only as "everything until the dump ends".
struct WineLogFilter {
    private var isSkippingMoltenVKExtensionDump = false
    private var didSummarizeMoltenVKDump = false

    /// Filters one streamed process chunk into the text to append, or nil when nothing survives.
    mutating func filtered(_ chunk: ProcessOutputChunk) -> String? {
        let prefix = chunk.stream == .stderr ? "[stderr] " : "[stdout] "
        let lines = chunk.text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .compactMap { filtered(String($0), prefix: prefix) }
        guard !lines.isEmpty else { return nil }
        let joined = lines.joined(separator: "\n")
        return joined.hasSuffix("\n") ? joined : joined + "\n"
    }

    /// Filters one line: nil drops it, an empty string keeps the blank line.
    mutating func filtered(_ line: String, prefix: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        if trimmed.contains("[mvk-info] MoltenVK version") {
            isSkippingMoltenVKExtensionDump = true
            // Only the first dump is worth announcing; later ones are the same wall of text.
            if didSummarizeMoltenVKDump {
                return nil
            }
            didSummarizeMoltenVKDump = true
            return "\(prefix)[mvk-info] MoltenVK initialized; verbose Vulkan capability dump hidden"
        }

        if isSkippingMoltenVKExtensionDump {
            if trimmed.hasPrefix("The following") || trimmed.hasPrefix("VK_") || trimmed.hasPrefix("[mvk-info] GPU device:") {
                return nil
            }
            isSkippingMoltenVKExtensionDump = false
        }

        return Self.isLowSignal(trimmed) ? nil : prefix + line
    }

    /// Resets the dump state so a new launch does not inherit the previous run's suppression.
    mutating func reset() {
        isSkippingMoltenVKExtensionDump = false
        didSummarizeMoltenVKDump = false
    }

    /// Identifies repetitive graphics capability lines that hide the useful launch failure.
    static func isLowSignal(_ trimmedLine: String) -> Bool {
        trimmedLine.hasPrefix("GPU Family ")
            || trimmedLine.hasPrefix("model:")
            || trimmedLine.hasPrefix("type:")
            || trimmedLine.hasPrefix("VK_")
            || trimmedLine.hasPrefix("[mvk-info] GPU device:")
            || trimmedLine.hasPrefix("[mvk-info] Created VkInstance")
            || trimmedLine.hasPrefix("Read-Write Texture Tier")
            || trimmedLine.hasPrefix("supports the following GPU Features")
            || trimmedLine.hasPrefix("Metal Shading Language")
            || trimmedLine.hasPrefix("pipelineCacheUUID:")
            || trimmedLine.hasPrefix("GPU memory available:")
            || trimmedLine.hasPrefix("GPU memory used:")
            || trimmedLine.hasPrefix("vendorID:")
            || trimmedLine.hasPrefix("deviceID:")
            || trimmedLine.contains("handle_DeviceMatchingCallback Ignoring HID device")
            || trimmedLine.contains("kerberos_LsaApInitializePackage no Kerberos support")
            || trimmedLine.contains("ntlm_check_version ntlm_auth was not found")
            || trimmedLine.contains("ntlm_LsaApInitializePackage no NTLM support")
            || trimmedLine.contains("wineserver: using server-side synchronization")
    }
}

/// Accumulates log text between flushes and keeps the retained log bounded.
///
/// A running game emits Wine diagnostics continuously, and every published change re-lays out the
/// whole log on the main thread the game is competing with. Text lands in `pending` as it arrives
/// and only crosses into `contents` when the owner flushes.
struct RunLogBuffer {
    /// Size past which the log is trimmed, and the size it is trimmed back to.
    ///
    /// Trimming to `retainedCharacters` only once past `trimThreshold` amortizes the O(n) copy over
    /// many appends instead of paying it on every one.
    static let trimThreshold = 120_000
    static let retainedCharacters = 80_000

    /// Text that has been flushed and is safe to publish.
    private(set) var contents = ""
    private var pending = ""

    var hasPendingText: Bool { !pending.isEmpty }

    mutating func append(_ text: String) {
        pending += text
    }

    /// Moves buffered text into `contents`, trimming it back under the cap.
    /// - Returns: whether anything moved, so the owner can skip a needless publish.
    @discardableResult
    mutating func flush() -> Bool {
        guard !pending.isEmpty else { return false }
        contents = Self.trimmed(contents + pending)
        pending = ""
        return true
    }

    /// Drops buffered text so a new run never inherits the previous tail.
    mutating func discardPending() {
        pending = ""
    }

    /// Clears everything, flushed text included.
    mutating func reset() {
        contents = ""
        pending = ""
    }

    static func trimmed(_ log: String) -> String {
        guard log.count > trimThreshold else { return log }
        return String(log.suffix(retainedCharacters))
    }
}
