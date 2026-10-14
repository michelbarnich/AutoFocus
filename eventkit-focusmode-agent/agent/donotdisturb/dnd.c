//
//  dnd.c
//  eventkit-focusmode-agent
//

#include "dnd.h"

#include <dispatch/dispatch.h>
#include <dlfcn.h>
#include <mach/mach_time.h>
#include <objc/message.h>
#include <objc/runtime.h>
#include <stdint.h>
#include <stdio.h>

static SEL selector(const char *name)
{
    return sel_registerName(name);
}

static id send0(id object, const char *name)
{
    return ((id (*)(id, SEL))objc_msgSend)(object, selector(name));
}

static void setObject(id object, const char *name, id value)
{
    ((void (*)(id, SEL, id))objc_msgSend)(
        object,
        selector(name),
        value
    );
}

static void setUInt64(id object, const char *name, uint64_t value)
{
    ((void (*)(id, SEL, uint64_t))objc_msgSend)(
        object,
        selector(name),
        value
    );
}

static id stringFromUTF8(const char *string)
{
    Class stringClass = objc_getClass("NSString");

    if (!stringClass) {
        fprintf(stderr, "Missing NSString\n");
        return NULL;
    }

    return ((id (*)(id, SEL, const char *))objc_msgSend)(
        (id)stringClass,
        selector("stringWithUTF8String:"),
        string
    );
}

static id allocateAndInitialize(const char *className)
{
    Class class = objc_getClass(className);

    if (!class) {
        fprintf(stderr, "Missing class: %s\n", className);
        return NULL;
    }

    return send0(send0((id)class, "alloc"), "init");
}

static uint64_t monotonicMicroseconds(void)
{
    static mach_timebase_info_data_t timebase = {0};

    if (timebase.denom == 0) {
        mach_timebase_info(&timebase);
    }

    uint64_t ticks = mach_continuous_time();
    __uint128_t nanoseconds =
        (__uint128_t)ticks * timebase.numer / timebase.denom;

    return (uint64_t)(nanoseconds / 1000);
}

static id dateWithTimeIntervalSinceNow(double seconds)
{
    Class dateClass = objc_getClass("NSDate");

    if (!dateClass) {
        fprintf(stderr, "Missing NSDate\n");
        return NULL;
    }

    return ((id (*)(id, SEL, double))objc_msgSend)(
        (id)dateClass,
        selector("dateWithTimeIntervalSinceNow:"),
        seconds
    );
}

static id buildLifetime(id startDate, id endDate)
{
    Class intervalClass = objc_getClass("NSDateInterval");
    Class lifetimeClass = objc_getClass(
        "DNDModeAssertionDateIntervalLifetime"
    );

    if (!intervalClass || !lifetimeClass) {
        fprintf(
            stderr,
            "Missing NSDateInterval or DNDModeAssertionDateIntervalLifetime\n"
        );
        return NULL;
    }

    id interval = ((id (*)(id, SEL, id, id))objc_msgSend)(
        send0((id)intervalClass, "alloc"),
        selector("initWithStartDate:endDate:"),
        startDate,
        endDate
    );

    if (!interval) {
        return NULL;
    }

    return ((id (*)(id, SEL, id))objc_msgSend)(
        send0((id)lifetimeClass, "alloc"),
        selector("initWithDateInterval:"),
        interval
    );
}

static id buildAssertionDetails(
    uint64_t durationSeconds,
    const char *selectedModeIdentifier
)
{
    id details = allocateAndInitialize("DNDMutableModeAssertionDetails");

    if (!details) {
        return NULL;
    }

    id identifier = stringFromUTF8("com.apple.focus.activity-manager");
    id modeIdentifier = stringFromUTF8(selectedModeIdentifier);
    id startDate = dateWithTimeIntervalSinceNow(0);
    id endDate = dateWithTimeIntervalSinceNow((double)durationSeconds);
    id lifetime = buildLifetime(startDate, endDate);

    if (!identifier || !modeIdentifier || !lifetime || !endDate) {
        return NULL;
    }

    setObject(details, "setIdentifier:", identifier);
    setObject(details, "setModeIdentifier:", modeIdentifier);
    setObject(details, "setModeConfigurationModifiedDate:", NULL);
    setObject(details, "setLifetime:", lifetime);
    setUInt64(details, "setReason:", 1ULL);
    setObject(details, "setUserVisibleEndDate:", endDate);

    return details;
}

static id buildRequestDetails(void)
{
    Class requestClass = objc_getClass("DNDRequestDetails");
    Class uuidClass = objc_getClass("NSUUID");

    if (!requestClass || !uuidClass) {
        fprintf(stderr, "Missing DNDRequestDetails or NSUUID\n");
        return NULL;
    }

    id object = send0((id)requestClass, "alloc");
    id uuid = send0((id)uuidClass, "UUID");
    id clientIdentifier = stringFromUTF8("com.apple.focus.activity-manager");

    if (!object || !uuid || !clientIdentifier) {
        return NULL;
    }

    return ((id (*)(id, SEL, id, id, uint64_t))objc_msgSend)(
        object,
        selector("initWithClientIdentifier:auditUUID:timestamp:"),
        clientIdentifier,
        uuid,
        monotonicMicroseconds()
    );
}

static id remoteConnection(void)
{
    Class class = objc_getClass("DNDRemoteServiceConnection");

    if (!class) {
        fprintf(stderr, "Missing DNDRemoteServiceConnection\n");
        return NULL;
    }

    return send0((id)class, "sharedInstance");
}

static int sendActivation(id connection, id assertion, id request)
{
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    __block int completionResult = 0;

    void (^completion)(id, id) = ^(id result, id error) {
        (void)result;

        if (error) {
            id description = send0(error, "description");
            const char *text = description
                ? ((const char *(*)(id, SEL))objc_msgSend)(
                    description,
                    selector("UTF8String")
                )
                : NULL;

            fprintf(
                stderr,
                "DND activation failed: %s\n",
                text ? text : "(unknown error)"
            );
            completionResult = 1;
        }

        dispatch_semaphore_signal(semaphore);
    };

    ((void (*)(id, SEL, id, id, id))objc_msgSend)(
        connection,
        selector(
            "activateModeWithDetails:"
            "withRequestDetails:"
            "completionHandler:"
        ),
        assertion,
        request,
        (id)completion
    );

    dispatch_time_t timeout = dispatch_time(
        DISPATCH_TIME_NOW,
        5LL * NSEC_PER_SEC
    );

    if (dispatch_semaphore_wait(semaphore, timeout) != 0) {
        fprintf(stderr, "DND activation timed out\n");
        return 1;
    }

    return completionResult;
}

int dnd_activate_for_duration(
    uint64_t durationSeconds,
    const char *modeIdentifier
)
{
    if (!modeIdentifier || modeIdentifier[0] == '\0') {
        fprintf(stderr, "A Focus mode identifier is required\n");
        return 1;
    }

    void *handle = dlopen(
        "/System/Library/PrivateFrameworks/"
        "DoNotDisturb.framework/Versions/A/DoNotDisturb",
        RTLD_NOW | RTLD_LOCAL
    );

    if (!handle) {
        fprintf(stderr, "Unable to load DoNotDisturb.framework: %s\n", dlerror());
        return 1;
    }

    id assertion = buildAssertionDetails(durationSeconds, modeIdentifier);
    id request = buildRequestDetails();
    id connection = remoteConnection();
    int result = 1;

    if (!assertion || !request || !connection) {
        fprintf(stderr, "Unable to construct DND activation request\n");
    } else {
        result = sendActivation(connection, assertion, request);

        if (result == 0) {
            fprintf(
                stdout,
                "DND enabled for %llu seconds\n",
                (unsigned long long)durationSeconds
            );
        }
    }

    dlclose(handle);
    return result;
}

int dnd_deactivate(const char *modeIdentifier)
{
    /*
     * DNDRemoteServiceConnection has no public deactivation selector on the
     * target system. Replace our assertion (which has a stable identifier)
     * with a one-second date-interval lifetime instead. donotdisturbd then
     * expires the assertion without relying on a client-side timer.
     */
    return dnd_activate_for_duration(1, modeIdentifier);
}
