#include "verilated.h"

struct BP_cmd {
    VL_SIGW(header, 66, 0, 3);
    VL_SIG64(data, 63, 0);

    BP_cmd(
        VL_SIGW(header, 66, 0, 3),
        VL_SIG64(data, 63, 0)
    ) : header{header}, data{data} {};

    BP_cmd(
        VL_SIG8(size, 2, 0),
        VL_SIG64(addr, 39, 0),
        VL_SIG8(msg_type, 3, 0),
        VL_SIG64(data, 63, 0)
    );

    bool operator==(const BP_cmd other);
};

struct BP_resp {
    VL_SIGW(header, 66, 0, 3);
    VL_SIG64(data, 63, 0);

    BP_resp(
        VL_SIGW(header, 66, 0, 3),
        VL_SIG64(data, 63, 0)
    ) : header{header}, data{data} {};

    BP_resp(
        const BP_cmd& cmd,
        VL_SIG64(data, 63, 0)
    ) : header{cmd.header}, data{data} {};

    bool operator==(const BP_resp other);
};
