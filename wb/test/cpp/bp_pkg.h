#pragma once

#include <cstdint>

struct BP_pkg {
    // header is actually larger than 64 bits, but the
    // upper bits are not used by the adapter anyway
    uint8_t size;
    uint64_t addr;
    uint8_t msg_type;
    uint64_t data;

    BP_pkg(uint8_t size, uint64_t addr, uint8_t msg_type, uint64_t data);
    BP_pkg(uint64_t header, uint64_t data);

    bool operator==(const BP_pkg other);

    uint64_t build_header();
};
