#include <CoreFoundation/CoreFoundation.h>
#include <CFNetwork/CFHTTPCookieStorage.h>

CFHTTPCookieStorageRef CFHTTPCookieStorageCreateFromFile(CFAllocatorRef allocator,
														 CFURLRef fileURL,
														 CFHTTPCookieStorageRef storage)
{
	(void)allocator;
	(void)fileURL;
	if (storage) return (CFHTTPCookieStorageRef)CFRetain(storage);
	return (CFHTTPCookieStorageRef)CFRetain(CFHTTPCookieStorageGetDefault());
}
