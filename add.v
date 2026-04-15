`default_nettype none

module add(
    // First 32-bit input operand.
    input  wire [31:0] i_op1,
    // Second 32-bit input operand.
    input  wire [31:0] i_op2,
    // 32-bit output result.
    output wire [31:0] o_result
);

assign o_result = i_op1 + i_op2;

endmodule

`default_nettype wire