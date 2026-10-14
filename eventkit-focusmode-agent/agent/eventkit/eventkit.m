#import <EventKit/EventKit.h>
#import "eventkit.h"
#import <dispatch/dispatch.h>
#include <stdlib.h>
#include <string.h>

static EKEventStore *store = nil;

int eventkit_init(void)
{
    store = [[EKEventStore alloc] init];

    if (store == nil) {
        return -1;
    }

    EKAuthorizationStatus status =
        [EKEventStore authorizationStatusForEntityType:EKEntityTypeEvent];

    NSLog(@"Authorization status: %ld", (long)status);

    return 0;
}

bool eventkit_request_access(void)
{
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    __block bool accessGranted = false;

    [store requestFullAccessToEventsWithCompletion:
        ^(BOOL granted, NSError *error) {
            if (error != nil) {
                NSLog(@"EventKit error: %@", error);
            } else if (!granted) {
                NSLog(@"Calendar access denied");
            } else {
                NSLog(@"Calendar access granted");
                accessGranted = true;
            }

            dispatch_semaphore_signal(semaphore);
        }];

    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    return accessGranted;
}

EventKitCalendarList eventkit_get_calendars(void)
{
    EventKitCalendarList result = { .items = NULL, .count = 0 };
    NSArray<EKCalendar *> *calendars =
        [store calendarsForEntityType:EKEntityTypeEvent];

    if (calendars.count == 0) {
        return result;
    }

    result.items = calloc(calendars.count, sizeof(EventKitCalendar));
    if (result.items == NULL) {
        return result;
    }

    for (EKCalendar *calendar in calendars) {
        const char *title = calendar.title.UTF8String;
        const char *identifier = calendar.calendarIdentifier.UTF8String;
        EventKitCalendar item = {
            .title = strdup(title != NULL ? title : ""),
            .identifier = strdup(identifier != NULL ? identifier : "")
        };

        if (item.title == NULL || item.identifier == NULL) {
            free(item.title);
            free(item.identifier);
            eventkit_free_calendars(&result);
            return result;
        }

        result.items[result.count++] = item;
    }

    return result;
}

void eventkit_free_calendars(EventKitCalendarList *list)
{
    if (list == NULL) {
        return;
    }

    for (size_t index = 0; index < list->count; index++) {
        free(list->items[index].title);
        free(list->items[index].identifier);
    }

    free(list->items);
    list->items = NULL;
    list->count = 0;
}
EventKitEventList eventkit_get_upcoming_events(const char *calendar_identifier)
{
    EventKitEventList result = { .items = NULL, .count = 0 };

    if (store == nil) {
        return result;
    }

    NSArray<EKCalendar *> *requestedCalendars = nil;
    if (calendar_identifier != NULL) {
        NSString *requestedIdentifier =
            [NSString stringWithUTF8String:calendar_identifier];
        if (requestedIdentifier == nil) {
            return result;
        }

        EKCalendar *requestedCalendar = nil;
        for (EKCalendar *calendar in
             [store calendarsForEntityType:EKEntityTypeEvent]) {
            if ([calendar.calendarIdentifier isEqualToString:requestedIdentifier]) {
                requestedCalendar = calendar;
                break;
            }
        }

        if (requestedCalendar == nil) {
            return result;
        }

        requestedCalendars = @[requestedCalendar];
    }

    NSDate *startDate = [NSDate date];
    NSDate *endDate = [[NSCalendar currentCalendar]
        dateByAddingUnit:NSCalendarUnitDay
                  value:1
                 toDate:startDate
                options:0];
    NSPredicate *predicate =
        [store predicateForEventsWithStartDate:startDate
                                       endDate:endDate
                                     calendars:requestedCalendars];
    NSArray<EKEvent *> *events = [store eventsMatchingPredicate:predicate];

    if (events.count == 0) {
        return result;
    }

    result.items = calloc(events.count, sizeof(EventKitEvent));
    if (result.items == NULL) {
        return result;
    }

    for (EKEvent *event in events) {
        const char *title = event.title.UTF8String;
        const char *identifier = event.eventIdentifier.UTF8String;
        EventKitEvent item = {
            .title = strdup(title != NULL ? title : ""),
            .identifier = strdup(identifier != NULL ? identifier : ""),
            .start_time = event.startDate.timeIntervalSince1970,
            .end_time = event.endDate.timeIntervalSince1970,
            .is_all_day = event.isAllDay
        };

        if (item.title == NULL || item.identifier == NULL) {
            free(item.title);
            free(item.identifier);
            eventkit_free_events(&result);
            return result;
        }

        result.items[result.count++] = item;
    }

    return result;
}

void eventkit_free_events(EventKitEventList *list)
{
    if (list == NULL) {
        return;
    }

    for (size_t index = 0; index < list->count; index++) {
        free(list->items[index].title);
        free(list->items[index].identifier);
    }

    free(list->items);
    list->items = NULL;
    list->count = 0;
}

EventKitAgentConfiguration eventkit_load_agent_configuration(void)
{
    EventKitAgentConfiguration result = {
        .focus_mode_identifier = NULL,
        .calendar_identifiers = NULL,
        .calendar_count = 0
    };
    NSURL *applicationSupport = [[NSFileManager defaultManager]
        URLForDirectory:NSApplicationSupportDirectory
               inDomain:NSUserDomainMask
      appropriateForURL:nil
                 create:NO
                  error:nil];
    NSURL *configurationURL = [[applicationSupport
        URLByAppendingPathComponent:@"EventKitFocusModeAgent"]
        URLByAppendingPathComponent:@"config.json"];
    NSData *data = [NSData dataWithContentsOfURL:configurationURL];

    if (data == nil) {
        return result;
    }

    NSDictionary *configuration = [NSJSONSerialization
        JSONObjectWithData:data
                   options:0
                     error:nil];
    if (![configuration isKindOfClass:[NSDictionary class]]) {
        return result;
    }

    NSString *focusModeIdentifier = configuration[@"focusModeIdentifier"];
    NSArray *calendarIdentifiers = configuration[@"calendarIdentifiers"];
    if (![focusModeIdentifier isKindOfClass:[NSString class]] ||
        ![calendarIdentifiers isKindOfClass:[NSArray class]]) {
        return result;
    }

    result.focus_mode_identifier = strdup(focusModeIdentifier.UTF8String);
    result.calendar_identifiers = calloc(
        calendarIdentifiers.count,
        sizeof(char *)
    );
    if (result.focus_mode_identifier == NULL ||
        (calendarIdentifiers.count > 0 &&
         result.calendar_identifiers == NULL)) {
        eventkit_free_agent_configuration(&result);
        return result;
    }

    for (id value in calendarIdentifiers) {
        if (![value isKindOfClass:[NSString class]]) {
            continue;
        }

        char *identifier = strdup([(NSString *)value UTF8String]);
        if (identifier == NULL) {
            eventkit_free_agent_configuration(&result);
            return result;
        }

        result.calendar_identifiers[result.calendar_count++] = identifier;
    }

    return result;
}

void eventkit_free_agent_configuration(
    EventKitAgentConfiguration *configuration
)
{
    if (configuration == NULL) {
        return;
    }

    free(configuration->focus_mode_identifier);
    for (size_t index = 0; index < configuration->calendar_count; index++) {
        free(configuration->calendar_identifiers[index]);
    }
    free(configuration->calendar_identifiers);
    configuration->focus_mode_identifier = NULL;
    configuration->calendar_identifiers = NULL;
    configuration->calendar_count = 0;
}
