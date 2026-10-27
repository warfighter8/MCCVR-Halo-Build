#pragma once

namespace mccvr {

// A visible Steam process remains the native Windows signal. Under Wine/Proton,
// accept Proton's inherited Steam-helper markers when the helper itself is not
// visible in the launcher's process snapshot. These markers are context only;
// they are not proof of account ownership or authorization.
constexpr bool SteamLaunchAllowed(bool storeEdition, bool steamProcessVisible,
                                  bool underWine, bool steamPathPresent,
                                  bool valvePlatformMutexPresent) noexcept
{
    return storeEdition || steamProcessVisible ||
        (underWine && steamPathPresent && valvePlatformMutexPresent);
}

} // namespace mccvr
