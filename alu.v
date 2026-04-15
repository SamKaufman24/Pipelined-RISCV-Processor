`default_nettype none

//Author: Brian Huo

// The arithmetic logic unit (ALU) is responsible for performing the core
// calculations of the processor. It takes two 32-bit operands and outputs
// a 32 bit result based on the selection operation - addition, comparison,
// shift, or logical operation. This ALU is a purely combinational block, so
// you should not attempt to add any registers or pipeline it in phase 3.
module alu (
    // Major operation selection.
    // NOTE: In order to simplify instruction decoding in phase 4, both 3'b010
    // and 3'b011 are used for set less than (they are equivalent).
    // Unsigned comparison is controlled through the `i_unsigned` signal.
    //
    // 3'b000: addition/subtraction if `i_sub` asserted
    // 3'b001: shift left logical
    // 3'b010,
    // 3'b011: set less than/unsigned if `i_unsigned` asserted
    // 3'b100: exclusive or
    // 3'b101: shift right logical/arithmetic if `i_arith` asserted
    // 3'b110: or
    // 3'b111: and
    input  wire [ 2:0] i_opsel,
    // When asserted, addition operations should subtract instead.
    // This is only used for `i_opsel == 3'b000` (addition/subtraction).
    input  wire        i_sub,
    // When asserted, comparison operations should be treated as unsigned.
    // This is only used for branch comparisons and set less than.
    // For branch operations, the ALU result is not used, only the comparison
    // results.
    input  wire        i_unsigned,
    // When asserted, right shifts should be treated as arithmetic instead of
    // logical. This is only used for `i_opsel == 3'b011` (shift right).
    input  wire        i_arith,
    // First 32-bit input operand.
    input  wire [31:0] i_op1,
    // Second 32-bit input operand.
    input  wire [31:0] i_op2,
    // 32-bit output result. Any carry out (from addition) should be ignored.
    output wire [31:0] o_result,
    // Equality result. This is used downstream to determine if a
    // branch should be taken.
    output wire        o_eq,
    // Set less than result. This is used downstream to determine if a
    // branch should be taken.
    output wire        o_slt
);
    // Fill in your implementation here.
    reg [31:0] result;
    reg [31:0] shift0, shift1, shift2, shift3, shift4, shift5;
    reg slt;
    wire slt_val;

    assign slt_val = (i_unsigned) ? ((i_op1 < i_op2) ? 1'b1 : 1'b0) :
                    ((i_op1[31] != i_op2[31]) ? i_op1[31] :
                    (i_op1 < i_op2) ? 1'b1 : 1'b0);


    always @* case(i_opsel) 
        3'b000 : result = (i_sub) ? i_op1 - i_op2 : i_op1 + i_op2; //add or subtract
        3'b001 : begin
            shift0 = i_op1;
            shift1 = (i_op2[0]) ? (shift0 << 1) : shift0;
            shift2 = (i_op2[1]) ? shift1 << 2 : shift1;
            shift3 = (i_op2[2]) ? shift2 << 4 : shift2;
            shift4 = (i_op2[3]) ? shift3 << 8 : shift3;
            shift5 = (i_op2[4]) ? shift4 << 16 : shift4;
            result = shift5; //shift left logical
        end
        3'b010,
        3'b011 : result = {31'b0, slt_val};
        3'b100 : result = i_op1 ^ i_op2; //XOR
        3'b101 : begin
            shift0 = i_op1;
            shift1 = (i_op2[0]) ? ((i_arith) ? ({{1{shift0[31]}},shift0[31:1]}) : (shift0 >> 1)) : shift0;
            shift2 = (i_op2[1]) ? ((i_arith) ? ({{2{shift1[31]}},shift1[31:2]}) : (shift1 >> 2)) : shift1;
            shift3 = (i_op2[2]) ? ((i_arith) ? ({{4{shift2[31]}},shift2[31:4]}) : (shift2 >> 4)) : shift2;
            shift4 = (i_op2[3]) ? ((i_arith) ? ({{8{shift3[31]}},shift3[31:8]}) : (shift3 >> 8)) : shift3;
            shift5 = (i_op2[4]) ? ((i_arith) ? ({{16{shift4[31]}},shift4[31:16]}) : (shift4 >> 16)) : shift4;
            result = shift5; //shift right
        end
        3'b110 : result = i_op1 | i_op2; //OR
        3'b111 : result = i_op1 & i_op2; //AND

        default : result = {32{1'b0}};
    endcase

    assign o_result = result;
    assign o_eq = ((i_op1 - i_op2) == 0) ? 1'b1 : 1'b0;
    assign o_slt = slt_val;

endmodule

`default_nettype wire
