#include "bp_packages.h"

BP_cmd::BP_cmd(
    uint8_t size,
    uint64_t addr,
    uint8_t msg_type,
    uint64_t data
) : data{data} {
    header = 0;
    header |= msg_type & 0x3;
    header |= (addr & 0xFFFFFFFFF8) << 8;
    header |= (static_cast<uint64_t>(size) & 0x3) << 48;
}

bool BP_cmd::operator==(const BP_cmd other) {
    return header == other.header &&
           data == other.data;
}

bool BP_resp::operator==(const BP_resp other) {
    return header == other.header &&
           data == other.data;
}
