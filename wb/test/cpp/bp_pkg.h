#pragma once

#include <cstdint>
#include <vector>

// this struct only stores the header of the first package
// the address of follwoing packages must be calculated follwing the wrapping
// rules, e.g. from https://verificationguide.com/wrap-address-calculation/
struct BP_pkg {
    union {
        struct {
            uint64_t msg_type : 4;
            uint64_t subop    : 4;
            uint64_t addr     : 40;
            uint64_t size     : 3;
            uint64_t payload  : 13;
        };

        uint64_t header;
    };

    std::vector<uint64_t> data;
};
