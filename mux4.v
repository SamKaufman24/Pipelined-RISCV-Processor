`default_nettype none

module mux4(
    // First 32-bit input operand.
    input  wire [31:0] i_op1,
    // Second 32-bit input operand.
    input  wire [31:0] i_op2,
    // Third 32-bit input operand.
    input  wire [31:0] i_op3,
    // Fourth 32-bit input operand.
    input  wire [31:0] i_op4,
    // mux select input
    input  wire [1:0] i_sel,
    // 32-bit output result.
    output wire [31:0] o_result

);
assign o_result = (i_sel[1] & i_sel[0]) ? i_op4 :
(i_sel[1] & ~i_sel[0]) ? i_op3 :
(~i_sel[1] & i_sel[0]) ? i_op2 : i_op1;

endmodule

`default_nettype wire