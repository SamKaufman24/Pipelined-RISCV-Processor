`default_nettype none

//data memory input processor
module dff_1(
    input wire clk,
    input wire rst,
    input wire d,  
    output reg q
);

    always @ (posedge clk) 
    begin
        if(rst)
            q <= 1'b0;
        else
            q <= d;
    end 

endmodule

`default_nettype wire