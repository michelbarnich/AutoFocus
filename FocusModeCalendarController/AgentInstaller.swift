import Darwin
import Foundation

@MainActor
enum AgentInstaller {
    static let launchAgentIdentifier = "com.michelbarnich.eventkit-focusmode-agent"
    static let squidManifestIdentifier =
        "com.michelbarnich.eventkit-focusmode-agent.dnd-patch"
    static let defaultTargetBundleIdentifier = "com.apple.donotdisturbd"

    static func install() throws -> String {
        let fileManager = FileManager.default
        let supportDirectory = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support")
            .appendingPathComponent("EventKitFocusModeAgent")
        let binaryDirectory = supportDirectory.appendingPathComponent("bin")
        let launchAgentsDirectory = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents")
        let squidDirectory = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".squid")

        guard
            let agentURL = Bundle.main.url(
                forResource: "eventkit-focusmode-agent",
                withExtension: nil
            ),
            let tweakURL = Bundle.main.url(
                forResource: "libdonotdisturbd-patch",
                withExtension: "dylib"
            )
        else {
            throw InstallerError.missingEmbeddedComponents
        }

        try fileManager.createDirectory(
            at: binaryDirectory,
            withIntermediateDirectories: true
        )
        try fileManager.createDirectory(
            at: launchAgentsDirectory,
            withIntermediateDirectories: true
        )
        try fileManager.createDirectory(
            at: squidDirectory,
            withIntermediateDirectories: true
        )

        let installedAgentURL = binaryDirectory
            .appendingPathComponent("eventkit-focusmode-agent")
        let installedTweakURL = binaryDirectory
            .appendingPathComponent("libdonotdisturbd-patch.dylib")
        try replaceItem(at: installedAgentURL, with: agentURL)
        try replaceItem(at: installedTweakURL, with: tweakURL)
        try fileManager.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: installedAgentURL.path
        )

        let launchAgentURL = launchAgentsDirectory
            .appendingPathComponent("\(launchAgentIdentifier).plist")
        let manifestURL = squidDirectory
            .appendingPathComponent("\(launchAgentIdentifier).plist")

        try Data(launchAgentPlist(agentPath: installedAgentURL.path).utf8)
            .write(to: launchAgentURL, options: .atomic)
        try Data(
            squidManifest(libraryPath: installedTweakURL.path).utf8
        ).write(to: manifestURL, options: .atomic)

        _ = runLaunchctl(
            arguments: [
                "bootout",
                "gui/\(getuid())",
                launchAgentURL.path
            ]
        )
        let bootstrapResult = runLaunchctl(
            arguments: [
                "bootstrap",
                "gui/\(getuid())",
                launchAgentURL.path
            ]
        )

        guard bootstrapResult == 0 else {
            throw InstallerError.launchAgentBootstrapFailed
        }

        return "Installed agent, Squid tweak, and LaunchAgent."
    }

    private static func replaceItem(
        at destinationURL: URL,
        with sourceURL: URL
    ) throws {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.copyItem(at: sourceURL, to: destinationURL)
    }

    private static func runLaunchctl(arguments: [String]) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus
        } catch {
            return -1
        }
    }

    private static func launchAgentPlist(agentPath: String) -> String {
        let supportDirectory = URL(fileURLWithPath: agentPath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .path

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(launchAgentIdentifier)</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(agentPath)</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
            <key>KeepAlive</key>
            <true/>
            <key>StandardOutPath</key>
            <string>\(supportDirectory)/agent.stdout.log</string>
            <key>StandardErrorPath</key>
            <string>\(supportDirectory)/agent.stderr.log</string>
        </dict>
        </plist>
        """
    }

    private static func squidManifest(libraryPath: String) -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Identifier</key>
            <string>\(squidManifestIdentifier)</string>

            <key>TargetBundleID</key>
            <string>\(defaultTargetBundleIdentifier)</string>

            <key>LibraryPath</key>
            <string>\(libraryPath)</string>

            <key>OSVersion</key>
            <string>*</string>

            <key>Enabled</key>
            <true/>
        </dict>
        </plist>
        """
    }
}

enum InstallerError: LocalizedError {
    case missingEmbeddedComponents
    case launchAgentBootstrapFailed

    var errorDescription: String? {
        switch self {
        case .missingEmbeddedComponents:
            return "The app bundle does not contain the agent and Squid tweak."
        case .launchAgentBootstrapFailed:
            return "The agent files were installed, but launchd could not bootstrap the LaunchAgent."
        }
    }
}
