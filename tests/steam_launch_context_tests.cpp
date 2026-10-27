#include "../src/common/steam_launch_context.h"

#include <cstdio>
#include <cstdlib>

namespace {
unsigned checks = 0;
unsigned failures = 0;

void Check(bool condition, const char* message)
{
    ++checks;
    if (!condition)
    {
        ++failures;
        std::fprintf(stderr, "FAIL: %s\n", message);
    }
}
}

int main()
{
    using mccvr::SteamLaunchAllowed;

    // Native Windows remains governed by the visible Steam process.
    Check(SteamLaunchAllowed(false, true, false, false, false),
          "native Windows with visible Steam is accepted");
    Check(!SteamLaunchAllowed(false, false, false, true, true),
          "native Windows without visible Steam is rejected even with Proton markers");

    // Wine alone or either marker alone is insufficient.
    Check(!SteamLaunchAllowed(false, false, true, false, false),
          "Wine without Proton markers is rejected");
    Check(!SteamLaunchAllowed(false, false, true, true, false),
          "SteamPath alone is insufficient");
    Check(!SteamLaunchAllowed(false, false, true, false, true),
          "ValvePlatformMutex alone is insufficient");
    Check(SteamLaunchAllowed(false, false, true, true, true),
          "Wine with both Proton markers and no visible Steam is accepted");

    // Store edition does not require Steam at all.
    Check(SteamLaunchAllowed(true, false, false, false, false),
          "Store edition remains exempt from Steam gate");

    std::printf("Steam launch context: %u checks, %u failures\n", checks, failures);
    return failures ? EXIT_FAILURE : EXIT_SUCCESS;
}
