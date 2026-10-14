#ifndef SCHEDULER_BRIDGE_H
#define SCHEDULER_BRIDGE_H

#include "../eventkit-focusmode-agent/agent/schedule_policy.h"
#include <stdbool.h>

static inline int schedule_test_change(
    bool hasPrevious,
    const char *previousIdentifier,
    double previousStart,
    double previousEnd,
    bool hasCurrent,
    const char *currentIdentifier,
    double currentStart,
    double currentEnd
) {
    ScheduleEventSnapshot previous = {
        previousIdentifier,
        previousStart,
        previousEnd
    };
    ScheduleEventSnapshot current = {
        currentIdentifier,
        currentStart,
        currentEnd
    };

    return (int)schedule_event_change(
        hasPrevious ? &previous : NULL,
        hasCurrent ? &current : NULL
    );
}

static inline double schedule_test_desired_end(
    double now,
    size_t count,
    double firstStart,
    double firstEnd,
    double secondStart,
    double secondEnd,
    double thirdStart,
    double thirdEnd
) {
    ScheduleEventSnapshot events[3] = {
        { "first", firstStart, firstEnd },
        { "second", secondStart, secondEnd },
        { "third", thirdStart, thirdEnd }
    };

    return schedule_desired_dnd_end(events, count, now);
}

#endif
