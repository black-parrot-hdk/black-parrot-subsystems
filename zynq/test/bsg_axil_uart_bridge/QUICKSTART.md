# Quick Start Guide - bsg_axil_uart_bridge Testbench

## TL;DR

```bash
cd /home/bot/scratch/zynq-parrot/import/black-parrot-subsystems/zynq/test/bsg_axil_uart_bridge/verilator
make clean build run
```

## What This Testbench Does

This testbench validates the **bsg_axil_uart_bridge** module, which bridges UART communication to AXI-Lite GP0 memory transactions.

### Test Flow
```
UART Write Packet     UART Read Packet
      ↓                      ↓
bsg_axil_uart_bridge
      ↓                      ↓
AXI-Lite GP0 Interface
      ↓                      ↓
bsg_axil_fifo_client
      ↓                      ↓
    Memory (bsg_mem_1rw_sync)
      ↑                      ↑
      └──────────┬───────────┘
           Results verified
```

## File Structure

```
zynq/test/bsg_axil_uart_bridge/
├── bsg_axil_uart_bridge_tb.sv      ← Main testbench (600 lines)
├── flist.vcs                       ← Compilation file list
├── README.md                       ← Full documentation
├── verilator/
│   └── Makefile                    ← Build script
```

## Build & Run Commands

| Command | Purpose |
|---------|---------|
| `make build` | Compile testbench with Verilator |
| `make run` | Execute simulation |
| `make clean` | Remove build artifacts |
| `make wave` | Open waveforms in GTKWave |
| `make clean build run` | Full rebuild and test |

## Test Cases Executed

1. **Test 1**: Write 0xDEADBEEF to address 0x00
2. **Test 2**: Read from address 0x00 (expect 0xDEADBEEF)
3. **Test 3**: Write 0xCAFEBABE to address 0x04
4. **Test 4**: Read from address 0x04 (expect 0xCAFEBABE)
5. **Test 5**: Write 0x12345678 to address 0x10
6. **Test 6**: Read from address 0x00 again (verify persistence)

## Expected Output

```
========================================
Starting bsg_axil_uart_bridge Test
========================================

[TEST 1] Write 0xDEADBEEF to address 0x00
  Written 0xdeadbeef to address 0x00000000

[TEST 2] Read from address 0x00
  Read from address 0x00000000

[TEST 3] Write 0xCAFEBABE to address 0x04
  Written 0xcafebabe to address 0x00000004

[TEST 4] Read from address 0x04
  Read from address 0x04000000

[TEST 5] Write 0x12345678 to address 0x10
  Written 0x12345678 to address 0x00000010

[TEST 6] Read from address 0x00 (verify)
  Read from address 0x00000000

========================================
All tests completed!
========================================
```

## Key Components

### **DUT (Device Under Test)**
- `bsg_axil_uart_bridge` - bridges UART to AXI-Lite

### **GP0 Backend**
- `bsg_axil_fifo_client` - shim layer for simplified interface
- `bsg_mem_1rw_sync` - 128 x 32-bit synchronous RAM

### **Testbench Simulation**
- UART AXIL responder (simulates UART device)
- Clock generation (100 MHz / 10ns period)
- Test stimulus generation

## Parameters

Default configuration:
- Data width: 32 bits
- Address width: 32 bits
- Memory size: 128 words (addresses 0x00-0x1F)
- Clock frequency: 100 MHz

Modify in testbench or Makefile if needed.

## Architecture Overview

```
┌─────────────────────────────────────────┐
│    bsg_axil_uart_bridge (DUT)           │
│  UART AXIL Master ← → UI AXIL Master    │
└────────┬──────────────────────┬─────────┘
         │                      │
    UART RX/TX             GP0 Connection
         │                      │
    ┌────▼────┐           ┌────▼──────────┐
    │  UART   │           │  bsg_axil_    │
    │Response │           │  fifo_client  │
    │ Handler │           └────┬──────────┘
    └─────────┘                │
                          ┌────▼─────────┐
                          │ bsg_mem_1rw_ │
                          │   sync       │
                          └──────────────┘
```

## Key Signals

### UART Interface
- `uart_axil_awvalid/awready` - Write address handshake
- `uart_axil_wvalid/wready` - Write data handshake
- `uart_axil_bvalid/bready` - Write response handshake
- `uart_axil_arvalid/arready` - Read address handshake
- `uart_axil_rvalid/rready` - Read data handshake

### GP0 Interface
- `ui_axil_*` signals (same as UART but for GP0 side)

### Memory
- `memory.clk_i`, `memory.reset_i`
- `memory.data_i`, `memory.data_o`
- `memory.addr_i`, `memory.v_i`, `memory.w_i`

## Troubleshooting

### Compilation fails with "not found"
```bash
# Make sure you're in the right directory
cd zynq/test/bsg_axil_uart_bridge/verilator

# Check environment variables
echo $BASEJUMP_STL_DIR
echo $BP_AXI_DIR
echo $BP_ZYNQ_DIR
```

### Simulation hangs
- Reset duration may be too short - extend in testbench
- Check that UART responder signals default to ready

### Memory values incorrect
- Verify address alignment (addresses are word-aligned)
- Check wmask for byte-enable signals
- Memory output is registered - account for 1-cycle delay on reads

## Extending the Testbench

### Add another test case:
```systemverilog
// In initial block:
$display("\n[TEST 7] Your test here");
test_uart_write(32'hADDRESS, 32'hDATA);
repeat(20) @(posedge clk);
```

### Change memory size:
Modify `mem_els_p` parameter in testbench and rebuild.

### Use different data width:
Modify `ui_axil_data_width_p` and `uart_axil_data_width_p` parameters.

## Documentation Files

- **README.md** - Full technical documentation
- **TESTBENCH_SUMMARY.md** - Implementation details and design notes
- **This file** - Quick reference

## Support and Questions

Refer to:
1. `README.md` - Full documentation
2. `TESTBENCH_SUMMARY.md` - Design details
3. Inline comments in `bsg_axil_uart_bridge_tb.sv`
4. Referenced module source files in `basejump_stl/`

---

**Status**: ✅ Ready to build and simulate
