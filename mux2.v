`default_nettype none

module mux2(
    // First 32-bit input operand.
    input  wire [31:0] i_op1,
    // Second 32-bit input operand.
    input  wire [31:0] i_op2,
    // mux select input
    input  wire i_sel,
    // 32-bit output result.
    output wire [31:0] o_result

);

assign o_result = (i_sel) ? i_op2 : i_op1;

endmodule