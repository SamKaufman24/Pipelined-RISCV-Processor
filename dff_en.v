`default_nettype none

//data memory input processor
module dff_en(
    input wire clk,
    input wire rst,
    input wire d,  
    output reg q,
    input wire enable
);

    always @ (posedge clk) 
    begin
        if(rst)
            q <= 1'b0;
        else if (enable)
            q <= d;
    end 

endmodule

`default_nettype wire