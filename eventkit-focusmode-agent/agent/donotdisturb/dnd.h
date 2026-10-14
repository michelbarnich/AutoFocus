//
//  dnd.h
//  eventkit-focusmode-agent
//

#ifndef DND_H
#define DND_H

#include <stdint.h>

int dnd_activate_for_duration(
    uint64_t durationSeconds,
    const char *modeIdentifier
);
int dnd_deactivate(const char *modeIdentifier);

#endif
