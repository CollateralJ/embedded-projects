// riscvextended.sv

// 11/22/2025
// Comments that say "do x now" state an important difference to riscvsingle.sv by Sarah Harris and David Harris

// 32-bit registers with instruction set:
// lw, sw
// add, sub, and, or, slt
// addi, andi, ori, slti
// beq, jal

// Extended adds the following instructions:
// sll slli srl srli
// xor xori
// bne blt bge jalr
// sra srai
// lui

module top(input  logic        clk, reset,
           output logic [31:0] WriteData, DataAdr, PC, Result,
           output logic        MemWrite);
           
  logic AdrSrc;
  logic [31:0] ReadData;
  // instantiate cpu, mem unit
  riscvmulti rvmulti(clk, reset, PC, MemWrite, WriteData, ReadData, DataAdr, Result, AdrSrc);
  idmem idmem(clk, MemWrite, AdrSrc, PC, DataAdr, WriteData, ReadData);

endmodule

module riscvmulti(input  logic        clk, reset,
                  output logic [31:0] PC,
                  output logic        MemWrite,
                  output logic [31:0] WriteData,
                  input  logic [31:0] ReadData,
                  output logic [31:0] DataAdr, Result, // DataAdr = Adr
                  output logic        AdrSrc);
                  
  logic        RegWrite, Jump, Zero, lessThan, PCWrite, IRWrite;
  logic [2:0]  ImmSrc;
  logic [1:0]  ResultSrc, ALUSrcA, ALUSrcB;
  logic [3:0]  ALUControl;
  logic [31:0] Instr; // this comes from, dp now, and sends to controller
  
  controller c(clk, reset, Instr[6:0], Instr[14:12], Instr[30],
               Zero, lessThan, ImmSrc, ALUSrcA, ALUSrcB, ResultSrc,
               AdrSrc, ALUControl, IRWrite, PCWrite, RegWrite,
               MemWrite);
  datapath dp(clk, reset, ResultSrc, AdrSrc, ALUSrcA,
              ALUSrcB, RegWrite, ImmSrc, ALUControl, Zero, lessThan,
              PC, Instr, WriteData, ReadData, PCWrite, 
              DataAdr, Result, IRWrite);

endmodule

module datapath(input  logic        clk, reset,
                input  logic [1:0]  ResultSrc,
                input  logic        AdrSrc,
                input  logic [1:0]  ALUSrcA, ALUSrcB,
                input  logic        RegWrite,
                input  logic [2:0]  ImmSrc,
                input  logic [3:0]  ALUControl,
                output logic        Zero, lessThan,
                output logic [31:0] PC,
                output logic [31:0] Instr, // datapath outputs instr, very diff to single cycle
                output logic [31:0] WriteData,
                input  logic [31:0] ReadData,
                input  logic        PCWrite,
                output logic [31:0] DataAdr, Result, // DataAdr = Adr, Result = PCNext
                input  logic        IRWrite);

  logic [31:0] OldPC, Data, ImmExt, rdA, rdB;
  logic [31:0] A, SrcA, SrcB, ALUResult, ALUOut;

  /* Instr/Data Memory Logic */

  eflopr #(32)  pcreg(clk, reset, PCWrite, Result, PC); // pcnext -> pc reg
  mux2   #(32)  pcmux(PC, Result, AdrSrc, DataAdr); // Adr mux
  flopr  #(32)  datareg(clk, reset, ReadData, Data); // readdata -> data reg
  eflopr #(32)  oldpcreg(clk, reset, IRWrite, PC, OldPC); // pc -> oldpc reg
  eflopr #(32)  instrreg(clk, reset, IRWrite, ReadData, Instr); // readdata -> instr reg

  /* Register File Logic */

  flopr  #(32)  areg(clk, reset, rdA, A); // rdA -> A reg
  flopr  #(32)  breg(clk, reset, rdB, WriteData);// rdB -> Writedata reg
  extend        ext(Instr[31:7], ImmSrc, ImmExt);
  regfile       rf(clk, RegWrite, Instr[19:15], Instr[24:20], Instr[11:7], Result, rdA, rdB);

  /* ALU Logic */

  alu           alu(SrcA, SrcB, ALUControl, ALUResult, Zero, lessThan);
  mux3   #(32)  srcamux(PC, OldPC, A, ALUSrcA, SrcA);// SrcA mux
  mux3   #(32)  srcbmux(WriteData, ImmExt, 32'd4, ALUSrcB, SrcB);// SrcB mux
  flopr  #(32)  aluoutreg(clk, reset, ALUResult, ALUOut);// ALUResult -> ALUOut reg
  mux3   #(32)  resultmux(ALUOut, Data, ALUResult, ResultSrc, Result); // Result mux
    
endmodule


/* Controller Module Definitions */


module controller(input logic clk, input logic reset,
                input logic [6:0] op,
                input logic [2:0] funct3,
                input logic funct7b5,
                input logic zero, lessThan,
                output logic [2:0] immsrc,
                output logic [1:0] ALUSrcA, ALUSrcB,
                output logic [1:0] ResultSrc,
                output logic AdrSrc,
                output logic [3:0] alucontrol,
                output logic IRWrite, PCWrite,
                output logic RegWrite, MemWrite);
    
    logic PCUpdate;
    logic [3:0] Branch;
    logic [1:0] ALUOp;
    typedef enum bit[3:0] {S0,S1,S2,S3,S4,S5,S6,S7,S8,S9,S10,S11,S12} State;
    State state;
    State nextState;
    
    aludec alu(op[5], funct3, funct7b5, ALUOp, alucontrol);
    instrdec instr(op, immsrc);
    
    always_ff @(posedge clk, posedge reset) 
        if (reset) state = S0;
        else state = nextState;
    
    always_comb
        case(state)
            S0:    begin
                    AdrSrc = 0;
                    IRWrite = 1;
                    ALUSrcA = 2'b00;
                    ALUSrcB = 2'b10;
                    ALUOp = 2'b00;
                    ResultSrc = 2'b10;
                    PCUpdate = 1;
                    RegWrite = 0;
                    MemWrite = 0;
                    Branch = 4'b0000;
                    nextState = S1;
                end
            S1:    begin
                    ALUSrcA = 2'b01;
                    ALUSrcB = 2'b01;
                    ALUOp = 2'b00;
                    AdrSrc = 0;
                    IRWrite = 0;
                    ResultSrc = 0;
                    PCUpdate = 0;
                    RegWrite = 0;
                    MemWrite = 0;
                    Branch = 4'b0000;
                    case(op)
                        7'b000_0011: nextState = S2; //I-Type
                        7'b010_0011: nextState = S2; //S-Type
                        7'b011_0011: nextState = S6; //R-Type
                        7'b001_0011: nextState = S8; //I-Type
                        7'b110_1111: nextState = S9; //jal
                        7'b110_0111: nextState = S12; //jalr
                        7'b110_0011: nextState = S10;//B-Type
                        7'b011_0111: nextState = S11;//U-Type
                        default: nextState = S0;
                    endcase
                end
            S2:    begin
                    ALUSrcA = 2'b10;
                    ALUSrcB = 2'b01;
                    ALUOp = 2'b00;
                    AdrSrc = 0;
                    IRWrite = 0;
                    ResultSrc = 2'b00;
                    PCUpdate = 0;
                    RegWrite = 0;
                    MemWrite = 0;
                    Branch = 4'b0000;
                    nextState = (op[5])? S5 : S3;
                end
            S3:    begin
                    ResultSrc = 2'b00;
                    AdrSrc = 1;
                    ALUSrcA = 2'b00;
                    ALUSrcB = 2'b00;
                    ALUOp = 2'b00;
                    IRWrite = 0;
                    PCUpdate = 0;
                    RegWrite = 0;
                    MemWrite = 0;
                    Branch = 4'b0000;
                    nextState = S4;
                end
            S4:    begin
                    ResultSrc = 2'b01;
                    RegWrite = 1;
                    AdrSrc = 0;
                    ALUSrcA = 2'b00;
                    ALUSrcB = 2'b00;
                    ALUOp = 2'b0;
                    IRWrite = 0;
                    PCUpdate = 0;
                    MemWrite = 0;
                    Branch = 4'b0000;
                    nextState = S0;
                end
            S5:    begin
                    ResultSrc = 2'b00;
                    AdrSrc = 1;
                    MemWrite = 1;
                    ALUSrcA = 2'b00;
                    ALUSrcB = 2'b00;
                    ALUOp = 2'b00;
                    IRWrite = 0;
                    PCUpdate = 0;
                    RegWrite = 0;
                    Branch = 4'b0000;
                    nextState = S0;
                end
            S6:    begin
                    ALUSrcA = 2'b10;
                    ALUSrcB = 2'b00;
                    ALUOp = 2'b10;
                    AdrSrc = 0;
                    IRWrite = 0;
                    ResultSrc = 0;
                    PCUpdate = 0;
                    RegWrite = 0;
                    MemWrite = 0;
                    Branch = 4'b0000;
                    nextState = S7;
                end
            S7:    begin
                    ResultSrc = 2'b00;
                    RegWrite = 1;
                    ALUSrcA = 2'b00;
                    ALUSrcB = 2'b00;
                    ALUOp = 2'b00;
                    IRWrite = 0;
                    PCUpdate = 0;
                    MemWrite = 0;
                    Branch = 4'b0000;
                    AdrSrc = 0;
                    nextState = S0;
                end
            S8:    begin
                    ALUSrcA = 2'b10;
                    ALUSrcB = 2'b01;
                    ALUOp = 2'b10;
                    AdrSrc = 0;
                    IRWrite = 0;
                    ResultSrc = 2'b00;
                    PCUpdate = 0;
                    RegWrite = 0;
                    MemWrite = 0;
                    Branch = 4'b0000;
                    nextState = S7;
                end
            S9:    begin
                    ALUSrcA = 2'b01;
                    ALUSrcB = 2'b10;
                    ALUOp = 2'b00;
                    ResultSrc = 2'b00;
                    PCUpdate = 1;
                    AdrSrc = 0;
                    IRWrite = 0;
                    RegWrite = 0;
                    MemWrite = 0;
                    Branch = 4'b0000;
                    nextState = S7;
                end
            S10:begin
                    case(funct3)
                        3'b000: Branch = 4'b0001; // beq
                        3'b001: Branch = 4'b0010; // bne
                        3'b100: Branch = 4'b0100; // blt
                        3'b101: Branch = 4'b1000; // bge
                    endcase
                    ALUSrcA = 2'b10;
                    ALUSrcB = 2'b00;
                    ALUOp = 2'b01;
                    ResultSrc = 2'b00;
                    AdrSrc = 0;
                    IRWrite = 0;
                    PCUpdate = 0;
                    RegWrite = 0;
                    MemWrite = 0;
                    nextState = S0;
                end
            S11:begin
                    ALUSrcA = 2'b11;
                    ALUSrcB = 2'b01;
                    ALUOp = 2'b00;
                    AdrSrc = 0;
                    IRWrite = 0;
                    ResultSrc = 2'b00;
                    PCUpdate = 0;
                    RegWrite = 0;
                    MemWrite = 0;
                    Branch = 4'b0000;
                    nextState = S7;
                end
            S12:begin
                    ALUSrcA = 2'b10;
                    ALUSrcB = 2'b01;
                    ALUOp = 2'b00;
                    AdrSrc = 0;
                    IRWrite = 0;
                    ResultSrc = 0;
                    PCUpdate = 0;
                    RegWrite = 0;
                    MemWrite = 0;
                    Branch = 4'b0000;
                    nextState = S9;
                end
        endcase
    assign PCWrite = (Branch[0] & zero) | (Branch[1] & ~zero) | (Branch[2] & lessThan) | (Branch[3] & ~ lessThan) | PCUpdate;
endmodule

module aludec(input logic opb5,
            input logic [2:0] funct3,
            input logic funct7b5,
            input logic [1:0] ALUOp,
            output logic [3:0] ALUControl);
    logic RtypeSub;
    assign RtypeSub = funct7b5 & opb5; // TRUE for R-type subtract instruction
    always_comb
        case(ALUOp)
            2'b00: ALUControl = 4'b0000; // lw, sw, lui (add)
            2'b01: ALUControl = 4'b0001; // beq (sub)
            default: case(funct3) // R-type or I-type ALU
                3'b000: if (RtypeSub)
                        ALUControl = 4'b0001; // sub
                    else
                        ALUControl = 4'b0000; // add, addi
                3'b001: ALUControl = 4'b0110; // sll, slli
                3'b101: if (~funct7b5)
                        ALUControl = 4'b0111; // srl, srli
                    else
                        ALUControl = 4'b1000; // sra, srai
                3'b010: ALUControl = 4'b0101; // slt, slti
                3'b100: ALUControl = 4'b0100; // xor, xori
                3'b110: ALUControl = 4'b0011; // or, ori
                3'b111: ALUControl = 4'b0010; // and, andi
                default: ALUControl = 4'bxxxx; // ???
            endcase
        endcase
endmodule

module instrdec(input logic [6:0] op, output logic [2:0] immsrc);
    always_comb
        case(op)
            7'b000_0011: immsrc = 3'b000; //lw
            7'b010_0011: immsrc = 3'b001; //sw
            7'b011_0011: immsrc = 3'bxxx; //R-type
            7'b110_0011: immsrc = 3'b010; //beq
            7'b001_0011: immsrc = 3'b000; //I-type
            7'b110_1111: immsrc = 3'b011; //jal
            7'b110_0111: immsrc = 3'b000; //jalr
            7'b011_0111: immsrc = 3'b100; //lui
        endcase
endmodule


/* Data Path Module Definitions */


module regfile(input  logic        clk, 
               input  logic        we3, 
               input  logic [ 4:0] a1, a2, a3, 
               input  logic [31:0] wd3, 
               output logic [31:0] rd1, rd2);

  logic [31:0] rf[31:0];

  // three ported register file
  // read two ports combinationally (A1/RD1, A2/RD2)
  // write third port on rising edge of clock (A3/WD3/WE3)
  // register 0 hardwired to 0

  always_ff @(posedge clk)
    if (we3) rf[a3] <= wd3;    

  assign rd1 = (a1 != 0) ? rf[a1] : 0;
  assign rd2 = (a2 != 0) ? rf[a2] : 0;

endmodule


module extend(input  logic [31:7] instr,
              input  logic [2:0]  immsrc,
              output logic [31:0] immext);
 
  always_comb
    case(immsrc) 
               // I-type 
      3'b000:   immext = {{20{instr[31]}}, instr[31:20]};  
               // S-type (stores)
      3'b001:   immext = {{20{instr[31]}}, instr[31:25], instr[11:7]}; 
               // B-type (branches)
      3'b010:   immext = {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0}; 
               // J-type (jal)
      3'b011:   immext = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0}; 
               // U-type (lui)
      3'b100:    immext = {{instr[31:12]}, 12'b0};
      default: immext = 32'bx; // undefined
    endcase
    
endmodule


module adder(input  [31:0] a, b,
             output [31:0] y);

  assign y = a + b;

endmodule


// no enable parameterized d ff
module flopr #(parameter WIDTH = 8)
              (input  logic             clk, reset,
               input  logic [WIDTH-1:0] d, 
               output logic [WIDTH-1:0] q);

  always_ff @(posedge clk, posedge reset)
    if (reset) q <= 0;
    else q <= d;

endmodule


// enable parameterized d ff
module eflopr #(parameter WIDTH = 8)
              (input  logic             clk, reset, enable,
               input  logic [WIDTH-1:0] d, 
               output logic [WIDTH-1:0] q);

  always_ff @(posedge clk, posedge reset)
    if (reset) q <= 0;
    else if (enable) q <= d;

endmodule


module mux2 #(parameter WIDTH = 8)
             (input  logic [WIDTH-1:0] d0, d1, 
              input  logic             s, 
              output logic [WIDTH-1:0] y);

  assign y = s ? d1 : d0; 

endmodule


module mux3 #(parameter WIDTH = 8)
             (input  logic [WIDTH-1:0] d0, d1, d2,
              input  logic [1:0]       s, 
              output logic [WIDTH-1:0] y);

  assign y = s[1] ? (s[0] ? 0 : d2) : (s[0] ? d1 : d0); // picks 0 with input 11

endmodule


// New idmem which manages a couple control signals.
// Importantly chooses which data for the ReadData signal on figure
module idmem(input  logic clk, MemWrite, AdrSrc,
             input  logic [31:0] PC, DataAdr, WriteData,
             output logic [31:0] ReadData);
     
  logic [31:0] Instr, dmemReadData;
  
  imem imem(PC, Instr);
  dmem dmem(clk, MemWrite, DataAdr, WriteData, dmemReadData);
  
  assign ReadData = (AdrSrc != 1) ? Instr : dmemReadData;

endmodule


module imem(input  logic [31:0] a,
            output logic [31:0] rd);

  logic [31:0] RAM[63:0];

  initial
      $readmemh("riscv_test_program.txt",RAM);

  assign rd = RAM[a[31:2]]; // word aligned

endmodule


module dmem(input  logic        clk, we,
            input  logic [31:0] a, wd,
            output logic [31:0] rd);

  logic [31:0] RAM[63:0];

  assign rd = RAM[a[31:2]]; // word aligned

  always_ff @(posedge clk)
    if (we) RAM[a[31:2]] <= wd;

endmodule


module alu(input  logic [31:0] a, b,
           input  logic [3:0]  alucontrol,
           output logic [31:0] result,
           output logic        zero, lessThan);

  logic [31:0] condinvb, sum;
  logic        v;              // overflow
  logic        isAddSub;       // true when is add or subtract operation

  assign condinvb = alucontrol[0] ? ~b : b;
  assign sum = a + condinvb + alucontrol[0];
  assign isAddSub = ~alucontrol[3] & ~alucontrol[2] & ~alucontrol[1] | ~alucontrol[1] & alucontrol[0]; //4'b000X or 4'bXX01

  always_comb
    case (alucontrol)
      4'b0000:  result = sum;         // add
      4'b0001:  result = sum;         // subtract
      4'b0010:  result = a & b;       // and
      4'b0011:  result = a | b;       // or
      4'b0100:  result = a ^ b;       // xor
      4'b0101:  result = sum[31] ^ v; // slt
      4'b0110:  result = a << b[4:0]; // sll
      4'b0111:  result = a >> b[4:0]; // srl
      4'b1000:    result = $unsigned($signed(a) >>> b[4:0]); //sra
      default: result = 32'bx;
    endcase

  assign zero = (result == 32'b0);
  assign lessThan = sum[31] ^ v;
  assign v = ~(alucontrol[0] ^ a[31] ^ b[31]) & (a[31] ^ sum[31]) & isAddSub;
  
endmodule



