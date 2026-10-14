//
//  schedule_policy.h
//  eventkit-focusmode-agent
//

#ifndef SCHEDULE_POLICY_H
#define SCHEDULE_POLICY_H

#include <math.h>
#include <stddef.h>
#include <string.h>

typedef enum {
    ScheduleEventUnchanged = 0,
    ScheduleEventAdded,
    ScheduleEventRemoved,
    ScheduleEventRescheduled
} ScheduleEventChange;

typedef struct {
    const char *identifier;
    double start_time;
    double end_time;
} ScheduleEventSnapshot;

static inline ScheduleEventChange schedule_event_change(
    const ScheduleEventSnapshot *previous,
    const ScheduleEventSnapshot *current
) {
    if (previous == NULL) {
        return current == NULL ? ScheduleEventUnchanged : ScheduleEventAdded;
    }

    if (current == NULL) {
        return ScheduleEventRemoved;
    }

    if (strcmp(previous->identifier, current->identifier) != 0 ||
        previous->start_time != current->start_time ||
        previous->end_time != current->end_time) {
        return ScheduleEventRescheduled;
    }

    return ScheduleEventUnchanged;
}

static inline double schedule_desired_dnd_end(
    const ScheduleEventSnapshot *events,
    size_t count,
    double now
) {
    double desired_end = 0;

    for (size_t index = 0; index < count; index++) {
        if (events[index].start_time <= now &&
            events[index].end_time > now &&
            events[index].end_time > desired_end) {
            desired_end = events[index].end_time;
        }
    }

    return desired_end;
}

#endif
