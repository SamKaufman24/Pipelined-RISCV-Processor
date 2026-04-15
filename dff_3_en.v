`default_nettype none

// 3 bit wide dff
module dff_3_en(
    input wire clk,
    input wire rst,
    input wire [2:0] d,  
    output reg [2:0] q,
    input wire enable
);
    always @ (posedge clk) 
        begin
            if(rst)
                q[2:0] <= 3'b0;
            else if (enable)
                q[2:0] <= d[2:0];
        end 
endmodule

`default_nettype wire