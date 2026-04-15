`default_nettype none

//data memory input processor
module forwarding(
    input wire [4:0] rs1_raddr,
    input wire [4:0] rs2_raddr,
    input wire [4:0] rf_waddr_mem,
    input wire rf_wen_mem,
    input wire [4:0] rf_waddr_wb,
    input wire rf_wen_wb,
    // 2 bit signal that controls whether to use forwarding signals or register value in ALU input
    // 2'b00: no forwarding - read value from register file
    // 2'b01: EX-EX - reads from alu result
    // 2'b10: MEM-EX - reads from wb result (write data of rf)
    // 2'b11: not used, default to register file
    output reg [1:0] forward_1,
    output reg [1:0] forward_2
);


    always @(*) begin
        //default case
        forward_1 = 2'b00;
        forward_2 = 2'b00;

        // EX-EX forwarding for arithmetic and logic RAW
        if(rf_wen_mem) begin
            if(rf_waddr_mem == rs1_raddr)
                forward_1 = 2'b01;
            if(rf_waddr_mem == rs2_raddr)
                forward_2 = 2'b01;
        end

        // MEM-EX forwarding for other RAW 
        if(rf_wen_wb) begin
            if(rf_waddr_wb == rs1_raddr)
                forward_1 = 2'b10;
            if(rf_waddr_wb == rs2_raddr)
                forward_2 = 2'b10;
        end

    end


endmodule

`default_nettype wire