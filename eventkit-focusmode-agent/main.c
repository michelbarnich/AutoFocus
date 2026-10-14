//
//  main.c
//  eventkit-focusmode-agent
//
//  Created by Michel Barnich on 29.09.2026.
//

#include <EventKit/EventKit.h>
#include <stdlib.h>
#include <stdio.h>

#include "./setup/setup.h"
#include "./agent/agent.h"

int main(int argc, const char * argv[]) {
    if (setup()) {
        exit(EXIT_FAILURE);
    }
    
    run_loop();
    
    exit(EXIT_SUCCESS);
}
