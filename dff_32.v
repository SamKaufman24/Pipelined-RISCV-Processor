`default_nettype none

// 32 bit wide dff
module dff_32(
    input wire clk,
    input wire rst,
    input wire [31:0] d,  
    output reg [31:0] q
);
    always @ (posedge clk) 
        begin
            if(rst)
                q[31:0] <= 32'b0;
            else
                q[31:0] <= d[31:0];
        end 
endmodule

`default_nettype wire