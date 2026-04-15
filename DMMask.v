`default_nettype none

//data memory input processor
module DMMask(
    // Input instruction[14:12] (funct3)
    // Since we only enable data memory writing on load/store,
    // we only care what happens when there's a load/store instruction
    // and they are differentiated by funct3 (load and store b/h funct3 match)
    input wire [2:0] i_funct3,

    // Input Data Memory (DM) address from ALU
    // We only need the 2 LSBs to tell what the mask needs to be
    input wire [1:0] i_addr,

    // Input data from register
    input wire [31:0] i_regReadData,

    // Output data to Data Memory (DM)
    output reg [31:0] o_DMWriteData,

    // Output mask data
    output reg [3:0] o_DMMask
);
localparam BYTE = 3'b000;
localparam HALF = 3'b001;
localparam WORD = 3'b010;
localparam LBU = 3'b100;
localparam LHU = 3'b101;

always @(*) begin
    // Default setting to make sure we set the output
    o_DMMask[3:0] = 4'b1111;
    o_DMWriteData[31:0] = 32'b0; 
    case (i_funct3)
        BYTE, LBU: begin
            if(i_addr == 2'b00) begin
                o_DMMask[3:0] = 4'b0001;
                o_DMWriteData[31:0] = i_regReadData[31:0];
            end
                
            else if(i_addr == 2'b01) begin
                o_DMMask[3:0] = 4'b0010;
                o_DMWriteData[31:0] = {i_regReadData[23:0], 8'b0};
            end
                
            else if(i_addr == 2'b10) begin
                o_DMMask[3:0] = 4'b0100;
                o_DMWriteData[31:0] = {i_regReadData[15:0], 16'b0};
            end
                
            else if(i_addr == 2'b11) begin
                o_DMMask[3:0] = 4'b1000;
                o_DMWriteData[31:0] = {i_regReadData[7:0], 24'b0};
            end
                
        end 

        HALF, LHU: begin
            if(i_addr == 2'b00) begin
                o_DMMask[3:0] = 4'b0011;
                o_DMWriteData[31:0] = i_regReadData[31:0];
            end
                
            else if(i_addr == 2'b01) begin
                o_DMMask[3:0] = 4'b0110;
                o_DMWriteData[31:0] = {i_regReadData[23:0], 8'b0};
            end
                
            else if(i_addr == 2'b10) begin
                o_DMMask[3:0] = 4'b1100;
                o_DMWriteData[31:0] = {i_regReadData[15:0], 16'b0};
            end
                
        end

        WORD: begin
            o_DMMask[3:0] = 4'b1111;
            o_DMWriteData[31:0] = i_regReadData[31:0];
        end

        default: begin
            o_DMMask[3:0] = 4'b0000;
            o_DMWriteData[31:0] = 32'b0;
        end
    endcase
end
endmodule

`default_nettype wire