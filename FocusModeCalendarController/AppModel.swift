import EventKit
import Foundation
import Observation

struct FocusMode: Identifiable, Hashable {
    let id: String
    let name: String
    let symbolImageName: String
    let tintColorName: String
}

struct CalendarGroup: Identifiable {
    let id: String
    let name: String
    let calendars: [EKCalendar]
}

struct AgentConfiguration: Codable {
    var focusModeIdentifier: String?
    var calendarIdentifiers: [String]
}

@MainActor
@Observable
final class AppModel {
    private let eventStore = EKEventStore()
    private let fileManager = FileManager.default

    var focusModes: [FocusMode] = []
    var calendars: [EKCalendar] = []
    var calendarGroups: [CalendarGroup] = []
    var selectedFocusModeIdentifier: String?
    var selectedCalendarIdentifiers: Set<String> = []
    var focusLoadError: String?
    var calendarLoadError: String?
    var installationStatus: String?
    var isInstalling = false

    init() {
        loadConfiguration()
    }

    func refresh() async {
        loadFocusModes()
        await loadCalendars()
    }

    func selectFocusMode(_ identifier: String) {
        selectedFocusModeIdentifier = identifier
        saveConfiguration()
    }

    func setCalendar(_ identifier: String, isSelected: Bool) {
        if isSelected {
            selectedCalendarIdentifiers.insert(identifier)
        } else {
            selectedCalendarIdentifiers.remove(identifier)
        }
        saveConfiguration()
    }

    func installComponents() {
        guard !isInstalling else {
            return
        }

        isInstalling = true
        installationStatus = nil

        do {
            installationStatus = try AgentInstaller.install()
        } catch {
            installationStatus = "Installation failed: \(error.localizedDescription)"
        }

        isInstalling = false
    }

    private var configurationURL: URL {
        fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support")
            .appendingPathComponent("EventKitFocusModeAgent")
            .appendingPathComponent("config.json")
    }

    private var modeConfigurationsURL: URL {
        fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/DoNotDisturb/DB")
            .appendingPathComponent("ModeConfigurations.json")
    }

    private func loadConfiguration() {
        guard
            let data = try? Data(contentsOf: configurationURL),
            let configuration = try? JSONDecoder().decode(
                AgentConfiguration.self,
                from: data
            )
        else {
            return
        }

        selectedFocusModeIdentifier = configuration.focusModeIdentifier
        selectedCalendarIdentifiers = Set(configuration.calendarIdentifiers)
    }

    private func saveConfiguration() {
        let configuration = AgentConfiguration(
            focusModeIdentifier: selectedFocusModeIdentifier,
            calendarIdentifiers: selectedCalendarIdentifiers.sorted()
        )

        do {
            let directory = configurationURL.deletingLastPathComponent()
            try fileManager.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(configuration)
            try data.write(to: configurationURL, options: .atomic)
        } catch {
            focusLoadError = "Couldn’t save agent configuration: \(error.localizedDescription)"
        }
    }

    private func loadFocusModes() {
        do {
            let data = try Data(contentsOf: modeConfigurationsURL)
            let object = try JSONSerialization.jsonObject(with: data)
            var modesByIdentifier: [String: FocusMode] = [:]
            collectFocusModes(from: object, into: &modesByIdentifier)
            focusModes = modesByIdentifier.values.sorted {
                $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
            focusLoadError = focusModes.isEmpty
                ? "No Focus modes were found in ModeConfigurations.json."
                : nil
        } catch {
            focusModes = []
            focusLoadError = """
            Focus modes couldn’t be read. Grant Full Disk Access to             FocusModeCalendarController in System Settings, then refresh.
            """
        }
    }

    private func collectFocusModes(
        from value: Any,
        into modes: inout [String: FocusMode]
    ) {
        if let dictionary = value as? [String: Any] {
            if
                let identifier = dictionary["modeIdentifier"] as? String,
                let name = dictionary["name"] as? String
            {
                modes[identifier] = FocusMode(
                    id: identifier,
                    name: name,
                    symbolImageName:
                        dictionary["symbolImageName"] as? String
                        ?? "moon.fill",
                    tintColorName:
                        dictionary["tintColorName"] as? String
                        ?? "systemIndigoColor"
                )
            }

            for child in dictionary.values {
                collectFocusModes(from: child, into: &modes)
            }
        } else if let array = value as? [Any] {
            for child in array {
                collectFocusModes(from: child, into: &modes)
            }
        }
    }

    private func loadCalendars() async {
        do {
            let granted = try await eventStore.requestFullAccessToEvents()
            guard granted else {
                calendars = []
                calendarGroups = []
                calendarLoadError = "Calendar access wasn’t granted."
                return
            }

            calendars = eventStore
                .calendars(for: .event)
                .sorted {
                    $0.title.localizedStandardCompare($1.title) == .orderedAscending
                }
            calendarGroups = Dictionary(
                grouping: calendars,
                by: { $0.source.sourceIdentifier }
            )
            .compactMap { sourceIdentifier, calendars in
                guard let source = calendars.first?.source else {
                    return nil
                }

                return CalendarGroup(
                    id: sourceIdentifier,
                    name: source.title.isEmpty ? "Other" : source.title,
                    calendars: calendars
                )
            }
            .sorted {
                $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
            calendarLoadError = nil
        } catch {
            calendars = []
            calendarGroups = []
            calendarLoadError = "Couldn’t load calendars: \(error.localizedDescription)"
        }
    }
}
