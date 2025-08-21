# BlackParrot Subsystems

This repository contains various subsystems intended to connect BlackParrot to traditonal SoC and FPGA environments.
There is a focus on standard interfaces such as AXI/Wishbone as well as non-BlackParrot open-source integrations.
One primary application is the construction of the [ZynqParrot](https://github.com/black-parrot-hdk/zynq-parrot) prototyping system.

This repository tends to lag its dependencies.
Issues to point out upstream incompatibilities and PRs to fix broken builds are especially appreciated.
It is the intention of this repo to rely on high-quality open-source libraries.
Hard dependencies on vendor IP should typically be avoided; however, some physical subsystems on FPGA make them mandatory.
Please reach out if you would like to help port new subsystems or rebase existing subsystems onto more mature libraries.

## Standard Communication Protocols

### [AXI4](https://developer.arm.com/documentation/ihi0022/latest/) 

Building blocks for connecting BP to an existing AXI system
- bsg\_axil\_demux (1:2 AXIL mux)
- bsg\_axil\_mux (2:1 AXIL mux)
- bsg\_axil\_fifo\_client (AXILS to fifo interface)
- bsg\_axil\_fifo\_master (Fifo interface to AXILM)
- bsg\_axil\_store\_packer (Specialized memory ops into a non-blocking fifo)

### [Wishbone4](https://wishbone-interconnect.readthedocs.io/en/latest/02\_interface.html)

Building blocks for connecting BP to an existing Wishbone system
- bp\_me\_wb\_master (Bedrock to WBv4 master converter)
- bp\_me\_wb\_client (WBv4 client to Bedrock converter)

## IP Blocks for [ZynqParrot](https://github.com/black-parrot-hdk/zynq-parrot)

Open-source FPGA blocks, with SystemVerilog description and Verilog-2005 toplevel wrappers for compatibility with Vivado IPI

- bsg\_irq\_to\_axil (edge-trigger to AXILM converter)
- bsg\_axil\_debug (AXILM/AXILS bridge to [RISC-V Debug Module](https://github.com/pulp-platform/riscv-dbg)
- bsg\_axil\_dma (AXILM/AXILS R/W DMA)
- bsg\_axil\_uart\_bridge (AXILM/AXILS bridge to UART-16550(ish) controller)
- bsg\_axil\_watchdog (AXILM periodic heartbeat)
- bsg\_axis\_fifo (AXIS FIFO)
- bsg\_axil\_plic (AXIL wrapper around the [OpenTitan](https://github.com/lowRISC/opentitan) PLIC)
- bsg\_axil\_ethernet (AXIL wrapper around [verilog-ethernet](https://github.com/alexforencich/verilog-ethernet)

## SoC Integrations

### [BlackParrot](https://github.com/black-parrot/black-parrot)

- bp\_axi\_top (Wrapper with 1 AXILM, 1 AXILS, 1 AXI4M)
- bp\_axil\_top (Wrapper with 2 AXILM)
- bp\_axil\_client (Bedrock to AXILS converter)
- bp\_axil\_master (Bedrock to AXILM converter)
- bp\_endpoint\_to\_fifos (Bedrock to FIFO gearbox)

### [HammerBlade](https://github.com/bespoke-silicon-group/bsg\_manycore)

Integration of BlackParrot as a Linux-capable control processor for the HammerBlade manycore

#### HammerBlade modules
- bsg\_manycore\_endpoint\_to\_fifos (Gearbox to convert HammerBlade Standard Endpoint to non-blocking FIFOs)
- bsg\_manycore\_switch\_1x2 (1:2 mux used to bridge two non-interfering HammerBlade links)
#### Manycore Widgets
- bsg\_manycore\_axil\_bridge (AXIL to HammerBlade converter)
#### BP Widgets
- bp\_me\_manycore\_bridge (Memory-mapped CSRs accessible from both BlackParrot and Manycore sides of link)
- bp\_me\_manycore\_dram (Glue module for L1 fills from the HammerBlade memory system)
- bp\_me\_manycore\_fifo ([CUDA Lite](https://github.com/bespoke-silicon-group/bsg\_replicant)-compatible FIFO interface to the manycore)
- bp\_me\_manycore\_mmio (Low-latency direct MMIO to HammerBlade address space)
#### BP Wrappers
- bsg\_manycore\_tile\_blackparrot (Integration of BP widgets for a canonical control tile)
- bsg\_manycore\_tile\_blackparrot\_mesh (Set of routers to align with HammerBlade mesh)

### [OpenPiton](https://github.com/PrincetonUniversity/openpiton)

Integration of BlackParrot as a Linux-capable [BYOC](https://decades.cs.princeton.edu/aspl20-balkind.pdf) for the OpenPiton manycore

#### BP Widgets
- bp\_pce (P-Mesh Cache Engine to bridge BP-Bedrock to OpenPiton L1.5 cache)
#### BP Wrappers
- bp\_piton\_tile (BYOC Integration Wrapper)

