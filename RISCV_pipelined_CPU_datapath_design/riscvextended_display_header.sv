module de2_display(output logic [6:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5, HEX6, HEX7, output logic [8:0] LEDG);
  logic [31:0] writedata, dataadr, PC, Result;
  logic memwrite;
  top riscv_multi_cycle(KEY[0], SW[0], writedata, dataadr, PC, Result, memwrite);
  sevenseg_decoder dec0(Result[3:0], HEX0);
  sevenseg_decoder dec1(Result[7:4], HEX1);
  sevenseg_decoder dec2(Result[11:8], HEX2);
  sevenseg_decoder dec3(Result[15:12], HEX3);
  sevenseg_decoder dec4(Result[19:16], HEX4);
  sevenseg_decoder dec5(Result[23:20], HEX5);
  sevenseg_decoder dec6(Result[27:24], HEX6);
  sevenseg_decoder dec7(Result[31:28], HEX7);
  assign LEDG = PC[8:0];
endmodule

module sevenseg_decoder(input  logic [3:0] data,
                        output logic [6:0] segments);
  always_comb
  case (data)         //Sg - Sa
    4'h0: segments = 7'b1000000;
    4'h1: segments = 7'b1111001;
    4'h2: segments = 7'b0100100;
    4'h3: segments = 7'b0110000;
    4'h4: segments = 7'b0011001;
    4'h5: segments = 7'b0010010;
    4'h6: segments = 7'b0000010;
    4'h7: segments = 7'b1111000;
    4'h8: segments = 7'b0000000;
    4'h9: segments = 7'b0011000;
    4'hA: segments = 7'b0001000;
    4'hB: segments = 7'b0000011;
    4'hC: segments = 7'b0100111;
    4'hD: segments = 7'b0100001;
    4'hE: segments = 7'b0000110;
    4'hF: segments = 7'b0001110;
  endcase

endmodule

