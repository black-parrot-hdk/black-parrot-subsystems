# README

BlackParrot Subsystems contains various subsystems intended to connect BlackParrot to traditonal SoC and FPGA environments. There is a focus on standard interfaces such as AXI/Wishbone as well as non-BlackParrot open-source integrations. One primary application is the construction of the [ZynqParrot](https://github.com/black-parrot-hdk/zynq-parrot) prototyping system.

This repository tends to lag its dependencies. Issues to point out upstream incompatibilities and PRs to fix broken builds are especially appreciated. It is the intention of this repo to rely on high-quality open-source libraries. Hard dependencies on vendor IP should typically be avoided; however, some physical subsystems on FPGA make them mandatory. Please reach out if you would like to help port new subsystems or rebase existing subsystems onto more mature libraries.

## Standard Communication Protocols

### [AXI4](https://developer.arm.com/documentation/ihi0022/latest/) 

Building blocks for connecting BP to an existing AXI system:
- bp_axi_top (Wrapper with 1 AXILM, 1 AXILS, 1 AXI4M)
- bp_axil_top (Wrapper with 2 AXILM)
- bsg_axil_demux (1:2 AXIL mux)
- bsg_axil_mux (2:1 AXIL mux)
- bsg_axil_fifo_client (AXILS to fifo interface)
- bsg_axil_fifo_master (Fifo interface to AXILM)
- bsg_axil_store_packer (Specialized memory ops into a non-blocking fifo)
- bp_me_axil_client (Bedrock to AXILS converter)
- bp_me_axil_master (Bedrock to AXILM converter)
- bsg_manycore_axil_bridge (AXIL to HammerBlade converter)

### [Wishbone4](https://wishbone-interconnect.readthedocs.io/en/latest/02_interface.html)

Building blocks for connecting BP to an existing Wishbone system:
- bp_me_wb_master (Bedrock to WBv4 master converter)
- bp_me_wb_client (WBv4 client to Bedrock converter)

## IP Blocks for [ZynqParrot](https://github.com/black-parrot-hdk/zynq-parrot)

Open-source FPGA blocks, with SystemVerilog description and Verilog-2005 toplevel wrappers for compatibility with Vivado IPI:

- bsg_axi_debug (AXILM/AXILS bridge to [RISC-V Debug Module](https://github.com/pulp-platform/riscv-dbg)
- bsg_axil_uart_bridge (AXILM/AXILS bridge to UART-16550(ish) controller)
- bsg_axil_watchdog (AXILM periodic heartbeat)
- bsg_axis_fifo (AXIS FIFO)

## SoC Integrations

### [HammerBlade](https://github.com/bespoke-silicon-group/bsg_manycore)

Integration of BlackParrot as a Linux-capable control processor for the HammerBlade manycore:
#### HammerBlade modules
- bsg_manycore_endpoint_to_fifos (Gearbox to convert HammerBlade Standard Endpoint to non-blocking FIFOs)
- bsg_manycore_switch_1x2 (1:2 mux used to bridge two non-interfering HammerBlade links)
#### BP Widgets
- bp_me_manycore_bridge (Memory-mapped CSRs accessible from both BlackParrot and Manycore sides of link)
- bp_me_manycore_dram (Glue module for L1 fills from the HammerBlade memory system)
- bp_me_manycore_fifo ([CUDA Lite](https://github.com/bespoke-silicon-group/bsg_replicant)-compatible FIFO interface to the manycore)
- bp_me_manycore_mmio (Low-latency direct MMIO to HammerBlade address space)
#### BP Wrappers
- bsg_manycore_tile_blackparrot (Integration of BP widgets for a canonical control tile)
- bsg_manycore_tile_blackparrot_mesh (Set of routers to align with HammerBlade mesh)

### [OpenPiton](https://github.com/PrincetonUniversity/openpiton)

Integration of BlackParrot as a Linux-capable [BYOC](https://decades.cs.princeton.edu/aspl20-balkind.pdf) for the OpenPiton manycore:
#### BP Widgets
- bp_pce (P-Mesh Cache Engine to bridge BP-Bedrock to OpenPiton L1.5 cache)
#### BP Wrappers
- bp_piton_tile (BYOC Integration Wrapper) 
