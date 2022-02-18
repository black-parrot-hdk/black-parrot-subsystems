
#include <ctime>
#include <mutex>
#include <queue>
#include <cassert>
#include <cstdio>

#include "svdpi.h"

extern "C" int get_time()
{
    return time(NULL);
}
