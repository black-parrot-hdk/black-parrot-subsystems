#include "bp_packages.h"

BP_cmd::BP_cmd(
    VL_SIG8(size, 2, 0),
    VL_SIG64(addr, 39, 0),
    VL_SIG8(msg_type, 3, 0),
    VL_SIG64(data, 63, 0)
) : data{data} {
    header[0] = 0;
    header[0] += (msg_type & 0x0F);
    header[0] += (addr & 0x0000000000FFFFFF) << 8;

    header[1] = 0;
    header[1] += (addr & 0x000000FFFF000000) >> 24;
    header[1] += (size & 0x07) << 16;

    header[2] = 0;
}

bool BP_cmd::operator==(const BP_cmd other) {
    return header[0] == other.header[0] &&
           header[1] == other.header[1] &&
           header[2] == other.header[2] &&
           data == other.data;
}

bool BP_resp::operator==(const BP_resp other) {
    return header[0] == other.header[0] &&
           header[1] == other.header[1] &&
           header[2] == other.header[2] &&
           data == other.data;
}
