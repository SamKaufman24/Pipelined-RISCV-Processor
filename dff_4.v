`default_nettype none

// 4 bit wide dff
module dff_4(
    input wire clk,
    input wire rst,
    input wire [3:0] d,  
    output reg [3:0] q
);
    always @ (posedge clk) 
        begin
            if(rst)
                q[3:0] <= 4'b0;
            else
                q[3:0] <= d[3:0];
        end 
endmodule

`default_nettype wire