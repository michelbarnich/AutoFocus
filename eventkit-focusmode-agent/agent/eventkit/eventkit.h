//
//  eventkit.h
//  eventkit-focusmode-agent
//
//  Created by Michel Barnich on 29.09.2026.
//

#ifndef EVENTKIT_H
#define EVENTKIT_H

#include <stdbool.h>
#include <stddef.h>

typedef struct {
    char *title;
    char *identifier;
} EventKitCalendar;

typedef struct {
    EventKitCalendar *items;
    size_t count;
} EventKitCalendarList;

typedef struct {
    char *title;
    char *identifier;
    double start_time;
    double end_time;
    bool is_all_day;
} EventKitEvent;

typedef struct {
    EventKitEvent *items;
    size_t count;
} EventKitEventList;

typedef struct {
    char *focus_mode_identifier;
    char **calendar_identifiers;
    size_t calendar_count;
} EventKitAgentConfiguration;

int eventkit_init(void);
bool eventkit_request_access(void);
EventKitCalendarList eventkit_get_calendars(void);
void eventkit_free_calendars(EventKitCalendarList *list);
EventKitEventList eventkit_get_upcoming_events(const char *calendar_identifier);
void eventkit_free_events(EventKitEventList *list);
EventKitAgentConfiguration eventkit_load_agent_configuration(void);
void eventkit_free_agent_configuration(
    EventKitAgentConfiguration *configuration
);

#endif
