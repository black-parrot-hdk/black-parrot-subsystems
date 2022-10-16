#pragma once

#include <cstdint>

typedef unsigned __int128 uint128_t;

struct BP_cmd {
    uint128_t header;
    uint64_t data;

    BP_cmd(
        uint128_t header,
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
    uint128_t header;
    uint64_t data;

    BP_resp(
        uint128_t header,
        uint64_t data
    ) : header{header}, data{data} {};

    bool operator==(const BP_resp other);
};
