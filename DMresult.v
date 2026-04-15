`default_nettype none

//data memory result processor
module DMresult(
    // Input instruction[14:12] (funct3)
    // Since we only enable data memory writing on load,
    // we only care what happens when there's a load instruction
    // and they are differentiated by funct3
    input wire [2:0] i_funct3,

    // Input Data Memory (DM) address from ALU
    // We only need the 2 LSBs to tell what parts of the data are valid
    input wire [1:0] i_addr,

    // Input data from Data Memory (DM)
    input wire [31:0] i_DMReadData,

    // Output data to register
    output reg [31:0] o_regWriteData
);
localparam LB = 3'b000;
localparam LH = 3'b001;
localparam LW = 3'b010;
localparam LBU = 3'b100;
localparam LHU = 3'b101;



always @(*) begin
    // Default setting in case something is not assigned
    o_regWriteData[31:0] = 32'b0;
    case (i_funct3)
        LB: begin
            if(i_addr == 2'b00)
                o_regWriteData[31:0] = {{24{i_DMReadData[7]}}, i_DMReadData[7:0]};
            if(i_addr == 2'b01)
                o_regWriteData[31:0] = {{24{i_DMReadData[7]}}, i_DMReadData[15:8]};
            if(i_addr == 2'b10)
                o_regWriteData[31:0] = {{24{i_DMReadData[7]}}, i_DMReadData[23:16]};
            if(i_addr == 2'b11)
                o_regWriteData[31:0] = {{24{i_DMReadData[7]}}, i_DMReadData[31:24]};
        end 

        LBU: begin
            if(i_addr == 2'b00)
                o_regWriteData[31:0] = {24'b0, i_DMReadData[7:0]};
            if(i_addr == 2'b01)
                o_regWriteData[31:0] = {24'b0, i_DMReadData[15:8]};
            if(i_addr == 2'b10)
                o_regWriteData[31:0] = {24'b0, i_DMReadData[23:16]};
            if(i_addr == 2'b11)
                o_regWriteData[31:0] = {24'b0, i_DMReadData[31:24]};
        end

        LH: begin
            if(i_addr == 2'b00)
                o_regWriteData[31:0] = {{16{i_DMReadData[15]}}, i_DMReadData[15:0]};
            if(i_addr == 2'b01)
                o_regWriteData[31:0] = {{16{i_DMReadData[15]}}, i_DMReadData[23:8]};
            if(i_addr == 2'b10)
                o_regWriteData[31:0] = {{16{i_DMReadData[15]}}, i_DMReadData[31:16]};
        end

        LHU: begin
            if(i_addr == 2'b00)
                o_regWriteData[31:0] = {16'b0, i_DMReadData[15:0]};
            if(i_addr == 2'b01)
                o_regWriteData[31:0] = {16'b0, i_DMReadData[23:8]};
            if(i_addr == 2'b10)
                o_regWriteData[31:0] = {16'b0, i_DMReadData[31:16]};
        end

        LW: begin
            o_regWriteData[31:0] = i_DMReadData[31:0];
        end

        default: begin
            o_regWriteData[31:0] = 32'b0;
        end
    endcase
end
endmodule

`default_nettype wire