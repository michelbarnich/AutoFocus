//
//  setup.h
//  eventkit-focusmode-agent
//
//  Created by Michel Barnich on 29.09.2026.
//

#ifndef SETUP_H
#define SETUP_H

#include <stdbool.h>

extern bool DEBUG_MODE;
extern int PARENT_PID;
extern int POLL_INTERVAL;

int setup(void);
int get_parent_pid(void);
int get_poll_interval(void);

#endif
