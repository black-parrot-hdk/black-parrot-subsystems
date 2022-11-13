#include "bp_pkg.h"


BP_pkg::BP_pkg(uint8_t size, uint64_t addr, uint8_t msg_type, uint64_t data)
: size{size}, addr{addr}, msg_type{msg_type}, data{data} {}

BP_pkg::BP_pkg(uint64_t header, uint64_t data) : data{data} {
    msg_type = header & 0x3;
    addr = (header >> 8) & 0xFFFFFFFFF8;
    size = (header >> 48) & 0x3;
}

bool BP_pkg::operator==(const BP_pkg other) {
    return size == other.size &&
           addr == other.addr &&
           msg_type == other.msg_type &&
           data == other.data;
}

uint64_t BP_pkg::build_header() {
    uint64_t header = msg_type;
    header |= static_cast<uint64_t>(addr) << 8;
    header |= static_cast<uint64_t>(size) << 48;
    return header;
}
