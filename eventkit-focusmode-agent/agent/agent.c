//
//  agent.c
//  eventkit-focusmode-agent
//
//  Created by Michel Barnich on 29.09.2026.
//

#include "agent.h"
#include "./donotdisturb/dnd.h"
#include "./eventkit/eventkit.h"
#include "./schedule_policy.h"
#include "../setup/setup.h"

#include <dispatch/dispatch.h>
#include <math.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

typedef struct ScheduledEvent {
    char *identifier;
    char *title;
    double startTime;
    double endTime;
    uint64_t lastSeenGeneration;
    dispatch_source_t startTimer;
    struct ScheduledEvent *next;
} ScheduledEvent;

static ScheduledEvent *scheduledEvents = NULL;
static dispatch_queue_t schedulerQueue;
static uint64_t pollGeneration = 0;
static bool dndManagedActive = false;
static double managedDNDEndTime = 0;
static char *selectedFocusModeIdentifier = NULL;

static ScheduledEvent *findEvent(const char *identifier)
{
    for (ScheduledEvent *item = scheduledEvents; item != NULL; item = item->next) {
        if (strcmp(item->identifier, identifier) == 0) {
            return item;
        }
    }

    return NULL;
}

static void refreshDNDState(void)
{
    double now = (double)time(NULL);
    size_t count = 0;

    for (ScheduledEvent *item = scheduledEvents; item != NULL; item = item->next) {
        count++;
    }

    ScheduleEventSnapshot *snapshots =
        calloc(count, sizeof(ScheduleEventSnapshot));
    if (count > 0 && snapshots == NULL) {
        fprintf(stderr, "Unable to evaluate scheduled events\n");
        return;
    }

    size_t index = 0;
    for (ScheduledEvent *item = scheduledEvents; item != NULL; item = item->next) {
        snapshots[index++] = (ScheduleEventSnapshot) {
            .identifier = item->identifier,
            .start_time = item->startTime,
            .end_time = item->endTime
        };
    }

    double desiredEndTime = schedule_desired_dnd_end(snapshots, count, now);
    free(snapshots);

    if (desiredEndTime > now) {
        if (!dndManagedActive || fabs(desiredEndTime - managedDNDEndTime) >= 1) {
            uint64_t durationSeconds =
                (uint64_t)ceil(desiredEndTime - now);
            if (selectedFocusModeIdentifier == NULL) {
                fprintf(stderr, "No Focus mode is selected\n");
                return;
            }

            int result = dnd_activate_for_duration(
                durationSeconds,
                selectedFocusModeIdentifier
            );

            if (result == 0) {
                dndManagedActive = true;
                managedDNDEndTime = desiredEndTime;
            } else {
                fprintf(stderr, "DND activation returned %d\n", result);
            }
        }
    } else if (dndManagedActive) {
        int result = dnd_deactivate(selectedFocusModeIdentifier);

        if (result == 0) {
            dndManagedActive = false;
            managedDNDEndTime = 0;
        } else {
            fprintf(stderr, "DND deactivation returned %d\n", result);
        }
    }
}

static void cancelStartTimer(ScheduledEvent *event)
{
    if (event->startTimer != NULL) {
        dispatch_source_cancel(event->startTimer);
        event->startTimer = NULL;
    }
}

static void scheduleStartTimer(ScheduledEvent *event)
{
    cancelStartTimer(event);

    double now = (double)time(NULL);
    if (event->startTime <= now || event->endTime <= now) {
        return;
    }

    struct timespec deadline = {
        .tv_sec = (time_t)event->startTime,
        .tv_nsec =
            (long)((event->startTime - floor(event->startTime)) * NSEC_PER_SEC)
    };
    dispatch_source_t timer = dispatch_source_create(
        DISPATCH_SOURCE_TYPE_TIMER,
        0,
        0,
        schedulerQueue
    );

    if (timer == NULL) {
        fprintf(stderr, "Unable to create timer for '%s'\n", event->title);
        return;
    }

    event->startTimer = timer;
    dispatch_source_set_timer(
        timer,
        dispatch_walltime(&deadline, 0),
        DISPATCH_TIME_FOREVER,
        0
    );
    dispatch_source_set_event_handler(timer, ^{
        refreshDNDState();
    });
    dispatch_resume(timer);

    fprintf(
        stdout,
        "Scheduled DND for '%s' from %.0f to %.0f\n",
        event->title,
        event->startTime,
        event->endTime
    );
}

static ScheduledEvent *createScheduledEvent(const EventKitEvent *event)
{
    ScheduledEvent *item = calloc(1, sizeof(ScheduledEvent));
    if (item == NULL) {
        return NULL;
    }

    item->identifier = strdup(event->identifier);
    item->title = strdup(event->title);
    if (item->identifier == NULL || item->title == NULL) {
        free(item->identifier);
        free(item->title);
        free(item);
        return NULL;
    }

    item->startTime = event->start_time;
    item->endTime = event->end_time;
    item->lastSeenGeneration = pollGeneration;
    item->next = scheduledEvents;
    scheduledEvents = item;
    scheduleStartTimer(item);
    return item;
}

static void updateScheduledEvent(
    ScheduledEvent *item,
    const EventKitEvent *event
)
{
    ScheduleEventSnapshot previous = {
        .identifier = item->identifier,
        .start_time = item->startTime,
        .end_time = item->endTime
    };
    ScheduleEventSnapshot current = {
        .identifier = event->identifier,
        .start_time = event->start_time,
        .end_time = event->end_time
    };
    bool timingChanged =
        schedule_event_change(&previous, &current) == ScheduleEventRescheduled;

    item->lastSeenGeneration = pollGeneration;

    if (strcmp(item->title, event->title) != 0) {
        char *newTitle = strdup(event->title);
        if (newTitle != NULL) {
            free(item->title);
            item->title = newTitle;
        }
    }

    if (timingChanged) {
        item->startTime = event->start_time;
        item->endTime = event->end_time;
        scheduleStartTimer(item);
    }
}

static void removeMissingEvents(void)
{
    ScheduledEvent **link = &scheduledEvents;

    while (*link != NULL) {
        ScheduledEvent *item = *link;

        if (item->lastSeenGeneration == pollGeneration) {
            link = &item->next;
            continue;
        }

        fprintf(stdout, "Removed calendar event '%s'\n", item->title);
        cancelStartTimer(item);
        *link = item->next;
        free(item->identifier);
        free(item->title);
        free(item);
    }
}

static void reconcileEventList(EventKitEventList *events)
{
    for (size_t index = 0; index < events->count; index++) {
        EventKitEvent *event = &events->items[index];
        ScheduledEvent *scheduled = findEvent(event->identifier);

        if (scheduled == NULL) {
            createScheduledEvent(event);
        } else {
            updateScheduledEvent(scheduled, event);
        }
    }

}

static void updateSelectedFocusMode(const char *identifier)
{
    bool changed =
        (selectedFocusModeIdentifier == NULL && identifier != NULL) ||
        (selectedFocusModeIdentifier != NULL && identifier == NULL) ||
        (selectedFocusModeIdentifier != NULL && identifier != NULL &&
         strcmp(selectedFocusModeIdentifier, identifier) != 0);

    if (!changed) {
        return;
    }

    if (dndManagedActive && selectedFocusModeIdentifier != NULL) {
        dnd_deactivate(selectedFocusModeIdentifier);
        dndManagedActive = false;
        managedDNDEndTime = 0;
    }

    free(selectedFocusModeIdentifier);
    selectedFocusModeIdentifier =
        identifier == NULL ? NULL : strdup(identifier);
}

static void pollEvents(void)
{
    EventKitAgentConfiguration configuration =
        eventkit_load_agent_configuration();
    EventKitEventList *eventLists = calloc(
        configuration.calendar_count,
        sizeof(EventKitEventList)
    );

    if (configuration.calendar_count > 0 && eventLists == NULL) {
        fprintf(stderr, "Unable to allocate calendar event lists\n");
        eventkit_free_agent_configuration(&configuration);
        return;
    }

    for (
        size_t index = 0;
        index < configuration.calendar_count;
        index++
    ) {
        eventLists[index] = eventkit_get_upcoming_events(
            configuration.calendar_identifiers[index]
        );
    }

    dispatch_sync(schedulerQueue, ^{
        pollGeneration++;
        updateSelectedFocusMode(configuration.focus_mode_identifier);

        for (
            size_t index = 0;
            index < configuration.calendar_count;
            index++
        ) {
            reconcileEventList(&eventLists[index]);
        }

        removeMissingEvents();
        refreshDNDState();
    });

    if (configuration.focus_mode_identifier == NULL) {
        fprintf(
            stderr,
            "Configure a Focus mode in FocusModeCalendarController\n"
        );
    }

    for (
        size_t index = 0;
        index < configuration.calendar_count;
        index++
    ) {
        eventkit_free_events(&eventLists[index]);
    }
    free(eventLists);
    eventkit_free_agent_configuration(&configuration);
}

void run_loop(void)
{
    schedulerQueue = dispatch_queue_create(
        "com.eventkit-focusmode-agent.scheduler",
        DISPATCH_QUEUE_SERIAL
    );

    fprintf(
        stdout,
        "Polling calendars every %d seconds\n",
        POLL_INTERVAL
    );

    for (;;) {
        pollEvents();
        sleep((unsigned int)POLL_INTERVAL);
    }
}
