`default_nettype none

module branchControl (

    // 7 bit instruction from the instruction (instruction 6:0)
    input wire [6:0] i_opcode,

    // 3 bit funct3 from the instruction (instruction[14:12])
    input wire [2:0] i_funct3,

    // Single bit input from the ALU
    // Used to determine when the ALU inputs are equal for branch instructions
    input wire i_ALU_equal,

    // Single bit input from the ALU
    // Used to determine next steps in a branch instructions
    input wire i_ALU_slt,

    // Single bit output used as a selector bit for a 2:1 MUX
    // When high, this indicates a branch condition has been met and allows the calculated
    // instruction address to be sent to the PC
    output wire o_Branch,

    // Single bit output used to indicate a JALR instruction
    // When high, this indicates a JALR instruction is being executed
    // allowing the PC to be set appropriately
    output wire o_JALR,

    output wire o_LUI

);
  // Constants that define the opcodes for different instruction types
  localparam R_TYPE = 7'b011_0011;
  localparam I_ARITH = 7'b001_0011;
  localparam L_TYPE = 7'b000_0011;
  localparam S_TYPE = 7'b010_0011;
  localparam B_TYPE = 7'b110_0011;
  localparam LUI = 7'b011_0111;
  localparam AUIPC = 7'b001_0111;
  localparam JALR = 7'b110_0111;
  localparam JAL = 7'b110_1111;
  localparam EBREAK = 7'b111_0011;

  // Branch Instruction funct3 bits
  localparam BEQ = 3'b000;
  localparam BNE = 3'b001;
  localparam BLT = 3'b100;
  localparam BGE = 3'b101;
  localparam BLTU = 3'b110;
  localparam BGEU = 3'b111;

  // Branch selection logic
  assign o_Branch = (i_opcode == JAL) |
                    ((i_opcode == B_TYPE) & (
                    ((i_funct3 == BEQ) & i_ALU_equal)  |
                    ((i_funct3 == BNE) & ~i_ALU_equal) |
                    ((i_funct3 == BLT) & i_ALU_slt)    |
                    ((i_funct3 == BGE) & ~i_ALU_slt)   |
                    ((i_funct3 == BLTU) & i_ALU_slt)   |
                    ((i_funct3 == BGEU) & ~i_ALU_slt)));

// JALR Instruction detection
assign o_JALR = (i_opcode == JALR);

// LUI instruction detection
assign o_LUI = (i_opcode == LUI);


endmodule
`default_nettype wire