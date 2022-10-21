#pragma once

#include <cstdint>

struct BP_cmd {
    // header is actually larger than 64 bits, but the
    // upper bits are not used by the adapter anyway
    uint64_t header;
    uint64_t data;

    BP_cmd(
        uint64_t header,
        uint64_t data
    ) : header{header}, data{data} {};

    BP_cmd(
        uint8_t size,
        uint64_t addr,
        uint8_t msg_type,
        uint64_t data
    );

    bool operator==(const BP_cmd other);
};

struct BP_resp {
    // header is actually larger than 64 bits, but the
    // upper bits are not used by the adapter anyway
    uint64_t header;
    uint64_t data;

    BP_resp(
        uint64_t header,
        uint64_t data
    ) : header{header}, data{data} {};

    bool operator==(const BP_resp other);
};
