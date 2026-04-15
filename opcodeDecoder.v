`default_nettype none

//Author: Ian Cherkauer

// The opcode decoder is responsible for creating a one-hot
// signal that feeds into the immediate decoder to tell it
// what kind of immediate encoding the current instruction has
module opcodeDecoder(
    // Input is the opcode of the current instruction
    input wire [6:0] i_opcode,

    // Output a 1-hot encoded value for imm.v
    // [0] R-type (don't-care, see below) (gets handled by default case)
    // [1] I-type
    // [2] S-type
    // [3] B-type
    // [4] U-type
    // [5] J-type
    output reg [5:0] o_instType
);

// Constants that define the opcodes for different instruction types
localparam R_TYPE = 7'b011_0011;
localparam I_ARITH = 7'b001_0011;
localparam LOAD = 7'b000_0011;
localparam S_TYPE = 7'b010_0011;
localparam B_TYPE = 7'b110_0011;
localparam LUI = 7'b011_0111;
localparam AUIPC = 7'b001_0111;
localparam JALR = 7'b110_0111;
localparam JAL = 7'b110_1111;
localparam EBREAK = 7'b111_0011;

// Pick out the immediate encoding by checking opcodes
always @(*) begin
    o_instType = 6'b000000; // default assignment
    case (i_opcode)
        I_ARITH, LOAD, JALR: o_instType = 6'b000010;
        S_TYPE:              o_instType = 6'b000100;
        B_TYPE:              o_instType = 6'b001000;
        LUI, AUIPC:          o_instType = 6'b010000;
        JAL:                 o_instType = 6'b100000;
        // default is already handled above
    endcase
end


endmodule

`default_nettype wire