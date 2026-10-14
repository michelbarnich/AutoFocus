//
//  setup.c
//  eventkit-focusmode-agent
//
//  Created by Michel Barnich on 29.09.2026.
//

#include "../setup/setup.h"
#include "../agent/agent.h"
#include "../agent/eventkit/eventkit.h"

#include <stdlib.h>
#include <stdio.h>
#include <stdbool.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>

#define DEFAULT_POLL_INTERVAL 60 // the default poll interval is 60 seconds
#define MIN_INTERVAL 1
#define MAX_INTERVAL 3600

bool DEBUG_MODE;
int PARENT_PID;
int POLL_INTERVAL = DEFAULT_POLL_INTERVAL; // seconds between each EventKit poll

int get_parent_pid(void) {
    const int ppid = (int) getppid();
    return ppid;
}

int get_poll_interval(void) {
    const char *_poll_interval_env = getenv("POLL_INTERVAL");
    char *endptr;
    
    if (_poll_interval_env == NULL) {
        return DEFAULT_POLL_INTERVAL; //
    }
    
    errno = 0;
    long _poll_interval = strtol(_poll_interval_env,& endptr, 10);
    
    if (
        *endptr != '\0' ||
        _poll_interval < MIN_INTERVAL ||
        _poll_interval > MAX_INTERVAL ||
        errno == ERANGE
    ) {
        return -1;
    }
    
    return (int)_poll_interval;
}

int setup(void) {
    const char *_debug_env = getenv("DEBUG_MODE");
    DEBUG_MODE = (_debug_env != NULL && strcmp(_debug_env, "true") == 0);
    PARENT_PID = get_parent_pid();
    POLL_INTERVAL = get_poll_interval();
    
    if (PARENT_PID != 1 && !DEBUG_MODE) {
        printf("Agent process was not started by launchd, if this is intentional, set DEBUG_MODE=\"true\"");
        return 1;
    }
    
    if (POLL_INTERVAL == -1) {
        printf("Invalid POLL_INTERVAL. Use numeric values between %d and %d only!", MIN_INTERVAL, MAX_INTERVAL);
        return 2;
    }
    
    printf("Setting up agent...\n");
    
    if (eventkit_init() != 0) {
        printf("Failed to initialize EventKit\n");
        return 1;
    }

    if (!eventkit_request_access()) {
        printf("Calendar permission was not granted\n");
        return 1;
    }
    return 0;
}
