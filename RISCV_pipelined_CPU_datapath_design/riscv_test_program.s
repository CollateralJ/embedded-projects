lui s0, 0x12345
addi s0, s0, 0x678        # s0 = 0x12345678
addi s1, zero, 10        # s1 = 10
addi s2, zero, 5        # s2 = 5
addi s3, zero, 15        # s3 = 15
sub s4, s3, s2            # s4 = 15 - 5 = 10
beq s4, s1, beqlabel    # 10 = 10, should be taken
add s1, zero, zero        # shouldn't happen, s1 = 0
beqlabel:
blt s1, s2, bltlabel    # 10 < 5 ? shouldn't be taken
slli s5, s0, 4            # s5 = 0x23456780
bltlabel:
andi s5, s5, 0x07F        # s5 = 0
jal ra, shiftright
bge s0, s5, bgelabel    # 0x12345678 > 0, should be taken
add s0, zero, zero        # shouldn't happen, s0 = 0
bgelabel:
sw, s0, 0x100(zero)        # mem[100] = 0x12345678
lw, s6, 0x100(zero)        # s6 = mem[100] = 0x12345678
slli s6, s6, 3          # s6 = 0x91A2B3C0
srai, s6, s6, 4            # s6 = 0xF91A2B3C
slt s7, s2, s1            # s7 = 5 < 10 = 1
slt s7, s1, s2            # s7 = 10 < 5 = 0
xori s8, s3, 7            # s8 = 1111 ^ 0111 = 0x8
or s9, s1, s2            # s9 = 1010 | 0101 = 0xF
bne zero, s0, end
shiftright:    # function. current state should be: s0 = 0x12345678, s3 = 15
srl s5, s0, s3            # s5 = 0x00002468
jalr zero, ra, 0
end:
beq zero, zero, end

