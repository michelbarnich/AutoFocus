//
//  dnd_patch.m
//  eventkit-focusmode-agent
//
//  Runtime hooks for Do Not Disturb entitlement checks.
//

#include "/Users/michelbarnich/Desktop/Projects/Squid/libsquid/squid.h"

#include <dispatch/dispatch.h>
#include <objc/runtime.h>
#include <stdlib.h>
#include <stdarg.h>
#include <stdio.h>
#include <string.h>
#include <syslog.h>
#include <unistd.h>

typedef BOOL (*DNDModeAssertionEntitlementIMP)(id, SEL, id);
typedef BOOL (*DNDAnyValidEntitlementIMP)(id, SEL);

static DNDModeAssertionEntitlementIMP originalModeAssertionEntitlement;
static DNDAnyValidEntitlementIMP originalAnyValidEntitlement;
static bool hooksInstalled;
static bool hookInstallationStarted;
static unsigned int hookInstallationAttempt;

__attribute__((visibility("default")))
volatile unsigned long long dnd_patch_init_status;

static const unsigned int maximumHookInstallationAttempts = 40;
static const uint64_t hookInstallationRetryNanoseconds = 250000000ULL;

static void writeRuntimeDiagnostic(const char *format, ...)
{
    FILE *file = fopen("/private/tmp/dnd-patch-runtime.log", "a");
    if (file == NULL) {
        return;
    }

    va_list arguments;
    va_start(arguments, format);
    vfprintf(file, format, arguments);
    va_end(arguments);
    fputc('\n', file);
    fclose(file);
}

static void logEntitlementMethods(Class serviceConnectionClass)
{
    for (Class currentClass = serviceConnectionClass;
         currentClass != Nil;
         currentClass = class_getSuperclass(currentClass)) {
        unsigned int methodCount = 0;
        Method *methods = class_copyMethodList(currentClass, &methodCount);
        const char *className = class_getName(currentClass);

        for (unsigned int index = 0; index < methodCount; index++) {
            const char *selectorName = sel_getName(method_getName(methods[index]));
            if (strstr(selectorName, "dnd") != NULL ||
                strstr(selectorName, "Entitlement") != NULL ||
                strstr(selectorName, "entitlement") != NULL) {
                syslog(LOG_NOTICE,
                       "[dnd-patch] runtime method class=%s selector=%s",
                       className,
                       selectorName);
                writeRuntimeDiagnostic(
                    "runtime method class=%s selector=%s",
                    className,
                    selectorName
                );
            }
        }

        free(methods);
    }
}

static BOOL hookedModeAssertionEntitlement(
    id self,
    SEL selector,
    id clientIdentifier
)
{
    (void)self;
    (void)selector;
    (void)clientIdentifier;

    return YES;
}

static BOOL hookedAnyValidEntitlement(id self, SEL selector)
{
    (void)self;
    (void)selector;

    return YES;
}

static void installHooks(void)
{
    if (hooksInstalled) {
        return;
    }

    hookInstallationAttempt++;

    Class serviceConnectionClass = objc_getClass("BSServiceConnection");
    SEL modeAssertionSelector = sel_registerName(
        "dnds_hasModeAssertionEntitlementForClientIdentifier:"
    );
    SEL anyValidSelector = sel_registerName("dnds_hasAnyValidEntitlement");

    if (serviceConnectionClass != Nil && hookInstallationAttempt == 1) {
        logEntitlementMethods(serviceConnectionClass);
    }

    bool modeAssertionHooked = false;
    bool anyValidEntitlementHooked = false;

    if (serviceConnectionClass != Nil) {
        modeAssertionHooked = squid_hook_instance_method(
            serviceConnectionClass,
            modeAssertionSelector,
            (IMP)hookedModeAssertionEntitlement,
            (IMP *)&originalModeAssertionEntitlement
        );
        anyValidEntitlementHooked = squid_hook_instance_method(
            serviceConnectionClass,
            anyValidSelector,
            (IMP)hookedAnyValidEntitlement,
            (IMP *)&originalAnyValidEntitlement
        );
    }

    Method modeMethod = serviceConnectionClass == Nil
        ? NULL
        : class_getInstanceMethod(serviceConnectionClass, modeAssertionSelector);
    Method anyMethod = serviceConnectionClass == Nil
        ? NULL
        : class_getInstanceMethod(serviceConnectionClass, anyValidSelector);

    syslog(LOG_NOTICE,
           "[dnd-patch] hook attempt=%u class=%p modeMethod=%p anyMethod=%p mode=%d any=%d",
           hookInstallationAttempt,
           serviceConnectionClass,
           modeMethod,
           anyMethod,
           modeAssertionHooked,
           anyValidEntitlementHooked);
    writeRuntimeDiagnostic(
        "attempt=%u class=%p modeMethod=%p anyMethod=%p mode=%d any=%d",
        hookInstallationAttempt,
        serviceConnectionClass,
        modeMethod,
        anyMethod,
        modeAssertionHooked,
        anyValidEntitlementHooked
    );

    hooksInstalled = modeAssertionHooked && anyValidEntitlementHooked;

    if (!hooksInstalled && hookInstallationAttempt < maximumHookInstallationAttempts) {
        dispatch_after(
            dispatch_time(DISPATCH_TIME_NOW, (int64_t)hookInstallationRetryNanoseconds),
            dispatch_get_main_queue(),
            ^{
                installHooks();
            }
        );
    } else if (!hooksInstalled) {
        syslog(LOG_ERR,
               "[dnd-patch] failed to install hooks after %u attempts",
               hookInstallationAttempt);
    } else {
        syslog(LOG_NOTICE, "[dnd-patch] both hooks installed");
    }
}

__attribute__((visibility("default"), noinline))
void squid_tweak_init(void)
{
    dnd_patch_init_status = 1;

    if (hookInstallationStarted) {
        return;
    }

    hookInstallationStarted = true;
    syslog(LOG_NOTICE, "[dnd-patch] squid_tweak_init executed");
    writeRuntimeDiagnostic("squid_tweak_init executed");
    installHooks();
    dnd_patch_init_status = hooksInstalled ? 3 : 2;
}

__attribute__((constructor))
static void dndPatchInitialize(void)
{
    squid_tweak_init();
}
