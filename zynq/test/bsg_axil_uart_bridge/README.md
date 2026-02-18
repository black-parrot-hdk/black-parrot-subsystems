# BSG AXIL UART Bridge Testbench

## Overview

This testbench validates the `bsg_axil_uart_bridge` module by performing read and write operations through UART transactions. The testbench architecture consists of:

### Architecture

```
┌─────────────────────────────────────────────────────────┐
│                  bsg_axil_uart_bridge                   │
│  (Converts UART packets to AXI-Lite GP0 transactions)   │
├─────────────────────────────────────────────────────────┤
│                                                         │
│   UART AXIL Interface (master)                         │
│   ├── Write Address Channel                             │
│   ├── Write Data Channel                                │
│   ├── Write Response Channel                            │
│   ├── Read Address Channel                              │
│   └── Read Data Channel                                 │
│                                                         │
│   UI AXIL Interface (master)                           │
│   └── Connected to GP0 Backend                          │
└─────────────────────────────────────────────────────────┘
                         │
        ┌────────────────┴────────────────┐
        │                                 │
        ▼                                 ▼
┌───────────────────┐         ┌──────────────────┐
│ bsg_axil_fifo_    │         │ UART AXIL        │
│ client (GP0)      │         │ Responder        │
│                   │         │ (Simulated)      │
└───────────────────┘         └──────────────────┘
        │
        ▼
   ┌─────────────┐
   │ bsg_mem_1rw │
   │   (Memory   │
   │  Backend)   │
   └─────────────┘
```

### Components

1. **DUT: `bsg_axil_uart_bridge`**
   - Bridges UART communication to AXI-Lite interface
   - Converts UART byte packets into AXI-Lite read/write transactions on the UI (GP0) side

2. **UART Packet Format**
   ```
   Bits [63:32] : Data (read address for reads, data for writes)
   Bits [31:2]  : Address (30 bits)
   Bit  [1]     : Write not Read (1=write, 0=read)
   Bit  [0]     : Port select (0=GP0)
   ```

3. **GP0 Backend**
   - **bsg_axil_fifo_client**: Shim layer that converts AXI-Lite transactions to simplified ready/valid interface
   - **bsg_mem_1rw_sync**: Single-port synchronous RAM (128 words x 32 bits default)

4. **UART AXIL Responder (Testbench)**
   - Simulates UART peripheral with status registers (RX, TX, STAT, CTRL)
   - Responds to AXI-Lite read/write requests from the bridge

## Test Cases

The testbench executes the following test sequence:

### Test 1: Write 0xDEADBEEF to address 0x00
- Sends UART packet with write command
- Verifies data appears in memory through GP0 interface

### Test 2: Read from address 0x00
- Sends UART packet with read command
- Verifies correct data (0xDEADBEEF) is returned

### Test 3: Write 0xCAFEBABE to address 0x04
- Independent write to a different address
- Verifies no interference with previous data

### Test 4: Read from address 0x04
- Verifies data written in Test 3

### Test 5: Write 0x12345678 to address 0x10
- Third independent write

### Test 6: Read from address 0x00 (verify)
- Confirms data persistence
- Verifies previous writes didn't affect other memory locations

## Building and Running

### Prerequisites

- Verilator (for simulation)
- SystemVerilog-capable compiler/simulator
- GNU Make

### Build

From the test directory:

```bash
cd zynq/test/bsg_axil_uart_bridge/verilator
make build
```

### Run Simulation

```bash
make run
```

This will:
1. Compile the testbench and all dependencies
2. Execute the simulation
3. Display test results and waveform dumps

### View Waveforms

```bash
make wave
```

Opens the generated FST waveform file in GTKWave (if installed).

### Clean

```bash
make clean
```

Removes build artifacts and generated files.

## Interface Details

### UART AXIL Master
The DUT acts as an AXI-Lite master on the UART side, communicating with a simulated UART device:

- **Clock**: `clk_i`
- **Reset**: `reset_i` (active high)
- **Write Address Channel**: `uart_axil_awaddr_o`, `uart_axil_awvalid_o`, `uart_axil_awready_i`
- **Write Data Channel**: `uart_axil_wdata_o`, `uart_axil_wvalid_o`, `uart_axil_wready_i`
- **Write Response Channel**: `uart_axil_bvalid_i`, `uart_axil_bready_o`
- **Read Address Channel**: `uart_axil_araddr_o`, `uart_axil_arvalid_o`, `uart_axil_arready_i`
- **Read Data Channel**: `uart_axil_rdata_i`, `uart_axil_rvalid_i`, `uart_axil_rready_o`

### UI AXIL Master
The DUT acts as an AXI-Lite master on the UI (GP0) side, interfacing with the memory backend:

- Same structure as UART AXIL, but with `ui_axil_*` signals
- Connects to `bsg_axil_fifo_client` which provides the simplified interface to memory

## Key Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `uart_axil_data_width_p` | 32 | UART interface data width (bits) |
| `uart_axil_addr_width_p` | 32 | UART interface address width (bits) |
| `ui_axil_data_width_p` | 32 | GP0 interface data width (bits) |
| `ui_axil_addr_width_p` | 32 | GP0 interface address width (bits) |
| `mem_els_p` | 128 | Number of memory elements |

## Signals and Timing

- **Clock Period**: 10 ns (100 MHz)
- **Cycles per Test**: ~50-100 cycles
- **Total Simulation Time**: ~600 cycles

## Design Notes

1. **Memory Organization**
   - Each address stores 32 bits of data
   - Addressable locations: 0x00 - 0x1F (128 words)
   - Byte-enable (wmask) supports selective byte writes

2. **Read/Write Ordering**
   - The `bsg_axil_fifo_client` prioritizes reads over writes
   - Write transactions complete via the write response channel
   - Read transactions complete via the read data channel

3. **AXI-Lite Compliance**
   - All transactions comply with AXI-Lite specification
   - Single outstanding transaction at a time
   - No bursting (single-beat transactions)
   - Response codes: OKAY or SLVERR

## Extending the Testbench

### To add more test cases:

1. Add a new test procedure call in the `initial` block:
   ```systemverilog
   test_uart_write(32'hADDRESS, 32'hDATA);
   repeat(20) @(posedge clk);
   ```

2. The helper tasks will automatically:
   - Send UART packets
   - Wait for completion
   - Display results

### To modify the memory size:

Change the `mem_els_p` parameter in the testbench instantiation or in the Makefile:

```makefile
verilator ... -Gmem_els_p=256 ...
```

### To trace different signals:

Use the `--trace-fst` option (already enabled) and filter signals in GTKWave.

## Troubleshooting

### Compilation Errors

- Ensure all environment variables are set properly: `$TOP`, `$BASEJUMP_STL_DIR`, etc.
- Check that file paths in `flist.vcs` are correct relative to environment directories

### Simulation Hangs

- Check that `uart_axil_awready` and `uart_axil_wready` default to 1 in the responder
- Verify the testbench properly initializes all input signals in reset

### Incorrect Memory Values

- Verify address alignment (lower bits may be masked)
- Check byte-enable (wmask) signals
- Confirm memory read data path has proper pipeline

## References

- AXI Specification (AXI4-Lite)
- BaseJump STL Documentation: FIFO, Memory, and Dataflow modules
- SystemVerilog LRM for testbench syntax
