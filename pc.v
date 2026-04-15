`default_nettype none

module pc(
    // Global clock.
    input  wire i_clk,
    // Synchronous active-high reset.
    input  wire i_rst,
    // new PC value
    input  wire [31:0] i_d,
    // output PC value
    output reg [31:0] o_q,
    // enable
    input wire enable
);

always @(posedge i_clk) begin
    if(i_rst)
        o_q <= 32'b0;
    else if(enable)
        o_q <= i_d;
end

endmodule

`default_nettype wire