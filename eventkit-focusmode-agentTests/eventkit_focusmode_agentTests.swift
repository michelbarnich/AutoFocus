import Testing

private enum EventChange: Int32 {
    case unchanged = 0
    case added = 1
    case removed = 2
    case rescheduled = 3
}

private func change(
    previous: (String, Double, Double)?,
    current: (String, Double, Double)?
) -> EventChange {
    let previousValue = previous ?? ("", 0, 0)
    let currentValue = current ?? ("", 0, 0)

    return previousValue.0.withCString { previousIdentifier in
        currentValue.0.withCString { currentIdentifier in
            EventChange(
                rawValue: schedule_test_change(
                    previous != nil,
                    previousIdentifier,
                    previousValue.1,
                    previousValue.2,
                    current != nil,
                    currentIdentifier,
                    currentValue.1,
                    currentValue.2
                )
            )!
        }
    }
}

private func desiredEnd(
    now: Double,
    _ events: [(Double, Double)]
) -> Double {
    let padded = events + Array(
        repeating: (0.0, 0.0),
        count: 3 - events.count
    )

    return schedule_test_desired_end(
        now,
        events.count,
        padded[0].0,
        padded[0].1,
        padded[1].0,
        padded[1].1,
        padded[2].0,
        padded[2].1
    )
}

struct CalendarSchedulePolicyTests {
    @Test
    func existingActiveEventUsesItsEndTime() {
        #expect(desiredEnd(now: 100, [(90, 160)]) == 160)
    }

    @Test
    func overlappingEventsUseTheLatestEndTime() {
        #expect(
            desiredEnd(
                now: 100,
                [(80, 130), (90, 180), (110, 220)]
            ) == 180
        )
    }

    @Test
    func removingAnEventWhileRunningIsDetectedAndShortensDND() {
        let event = ("event-a", 80.0, 180.0)

        #expect(change(previous: event, current: nil) == .removed)
        #expect(desiredEnd(now: 100, [(80, 180), (90, 140)]) == 180)
        #expect(desiredEnd(now: 100, [(90, 140)]) == 140)
    }

    @Test
    func addingAnEventWhileRunningIsDetectedAndExtendsDND() {
        let event = ("event-b", 90.0, 200.0)

        #expect(change(previous: nil, current: event) == .added)
        #expect(desiredEnd(now: 100, [(80, 140)]) == 140)
        #expect(desiredEnd(now: 100, [(80, 140), (90, 200)]) == 200)
    }

    @Test
    func prolongingAnActiveEventUpdatesTheDeadline() {
        let previous = ("event-a", 80.0, 140.0)
        let prolonged = ("event-a", 80.0, 220.0)

        #expect(
            change(previous: previous, current: prolonged) == .rescheduled
        )
        #expect(desiredEnd(now: 100, [(80, 220)]) == 220)
    }

    @Test
    func shorteningAnActiveEventUpdatesTheDeadline() {
        let previous = ("event-a", 80.0, 220.0)
        let shortened = ("event-a", 80.0, 125.0)

        #expect(
            change(previous: previous, current: shortened) == .rescheduled
        )
        #expect(desiredEnd(now: 100, [(80, 125)]) == 125)
    }
}
