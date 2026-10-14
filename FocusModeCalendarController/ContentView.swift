import AppKit
import EventKit
import SwiftUI

struct ContentView: View {
    @State private var model = AppModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            Divider()
            focusSection
            Divider()
            calendarSection
            Divider()
            footer
        }
        .padding()
        .frame(width: 340)
        .task {
            await model.refresh()
        }
    }

    private var header: some View {
        HStack {
            Label("Calendar Focus", systemImage: "moon.stars.fill")
                .font(.headline)
            Spacer()
            Button {
                Task {
                    await model.refresh()
                }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("Refresh Focus modes and calendars")
        }
    }

    private var focusSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Focus mode")
                .font(.subheadline.weight(.semibold))

            if let error = model.focusLoadError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                    ForEach(model.focusModes) { mode in
                            focusModeButton(mode)
                        }
                    }
                }
                .frame(height: focusModeListHeight)
            }
        }
    }

    private func focusModeButton(_ mode: FocusMode) -> some View {
        let isSelected = model.selectedFocusModeIdentifier == mode.id
        let tint = focusColor(named: mode.tintColorName)

        return Button {
            model.selectFocusMode(mode.id)
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(tint)
                    Image(systemName: focusSymbolName(for: mode))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 28, height: 28)

                Text(mode.name)
                    .foregroundStyle(.primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .fontWeight(.semibold)
                        .foregroundStyle(tint)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? tint.opacity(0.16) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    private var focusModeListHeight: CGFloat {
        min(max(CGFloat(model.focusModes.count) * 48, 48), 190)
    }

    private func focusSymbolName(for mode: FocusMode) -> String {
        if NSImage(systemSymbolName: mode.symbolImageName, accessibilityDescription: nil) != nil {
            return mode.symbolImageName
        }

        switch mode.id {
        case "com.apple.focus.work":
            return "briefcase.fill"
        case "com.apple.focus.personal":
            return "person.fill"
        case "com.apple.sleep.sleep-mode":
            return "bed.double.fill"
        case "com.apple.donotdisturb.mode.driving":
            return "car.fill"
        default:
            return "moon.fill"
        }
    }

    private func focusColor(named name: String) -> Color {
        switch name {
        case "systemRedColor": return .red
        case "systemOrangeColor": return .orange
        case "systemYellowColor": return .yellow
        case "systemGreenColor": return .green
        case "systemMintColor": return .mint
        case "systemTealColor": return .teal
        case "systemCyanColor": return .cyan
        case "systemBlueColor": return .blue
        case "systemPurpleColor": return .purple
        case "systemPinkColor": return .pink
        case "systemBrownColor": return .brown
        case "systemGrayColor": return .gray
        default: return .indigo
        }
    }

    private var calendarSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Calendars")
                .font(.subheadline.weight(.semibold))

            if let error = model.calendarLoadError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if model.calendars.isEmpty {
                Text("No calendars available.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(model.calendarGroups) { group in
                            Text(group.name)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.top, 4)

                            ForEach(
                                group.calendars,
                                id: \.calendarIdentifier
                            ) { calendar in
                                Toggle(
                                    isOn: Binding(
                                        get: {
                                            model.selectedCalendarIdentifiers.contains(
                                                calendar.calendarIdentifier
                                            )
                                        },
                                        set: { isSelected in
                                            model.setCalendar(
                                                calendar.calendarIdentifier,
                                                isSelected: isSelected
                                            )
                                        }
                                    )
                                ) {
                                    HStack(spacing: 7) {
                                        Circle()
                                            .fill(calendarColor(calendar))
                                            .frame(width: 10, height: 10)
                                        Text(calendar.title)
                                    }
                                }
                                .padding(.leading, 8)
                            }
                        }
                    }
                }
                .frame(height: calendarListHeight)
            }
        }
    }

    private var calendarListHeight: CGFloat {
        let calendarHeight = CGFloat(model.calendars.count) * 28
        let groupHeight = CGFloat(model.calendarGroups.count) * 24
        return min(max(calendarHeight + groupHeight, 28), 260)
    }

    private func calendarColor(_ calendar: EKCalendar) -> Color {
        guard let color = calendar.cgColor else {
            return .secondary
        }

        return Color(cgColor: color)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Changes apply on the agent’s next poll.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Install Components") {
                    model.installComponents()
                }
                .disabled(model.isInstalling)
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }

            if let status = model.installationStatus {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
