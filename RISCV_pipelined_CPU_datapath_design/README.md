# Implementing RISC-V Multi-Cycle Pipelined CPU in SystemVerilog

An iterative project simulating (and programming onto Altera DE2 FPGA) a RISC-V multi-cycle CPU with 26 instructions. It started with a simple 13 instruction single-cycle CPU designed by Sarah Harris and David Harris, evolved to a multi-cycle pipeline with the same simple instruction set. Finally, we doubled the instruction count to 26, adding important instructions like conditional branches and jump-and-link.

Check out [the report](https://github.com/CollateralJ/embedded-projects/blob/main/RISCV_pipelined_CPU_datapath_design/report.pdf) for a detailed breakdown of the modified datapath, control unit, and more.