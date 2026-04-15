
`default_nettype none
module hazardHalt (

    // Input from the memory (MEM) stage giving the register file 
    // write address from the pipelined instruction
    input wire [4:0] mem_wAddr,

    // MEM stage control signal that indicates if Instruction in MEM stage is writing to a register
    input wire mem_RegWrite,

    // MEM stage register that hold the value of the ALU result for the instruction in the MEM stage
    input wire [31:0] mem_Result,

    // MEM stage instruction opcode
    input wire [6:0] mem_Opcode,

    // MEM stage data that was read from Data Memory
    input wire [31:0] mem_ReadData,

    // Input from the execute (EX) stage giving the register file 
    // write address from the pipelined instruction
    input wire [4:0] ex_wAddr,

    // EX stage control signal that indicated if Instruction in EX stage is writing to a register
    input wire  ex_RegWrite,

    // EX stage register that holds the value of the ALU result for the instruction in the EX stage
    input wire [31:0] ex_Result,

    //EX stage instruction opcode
    input wire [6:0] ex_Opcode,

    // Inputs from the instruction decode (ID) stage giving the register file
    // read addresses, pulled from the pipelined ID instruction
    input wire [4:0] i_rs1_raddr,
    input wire [4:0] i_rs2_raddr,

    //ID instruction OPCode
    input wire [6:0] i_IdOpcode,

    // Signal from generalControl signaling bad opcode or Ebreak instruction
    input wire i_badOpcode,

    // Last two bits of PC, and neither should be 1
    input wire i_badPC,

    // Signal from MEM stage indicating a bad data memory address (last 2 bits are nonzero)
    input wire i_badDmem,

    // Signals from Branch control indicating that there has been a branch/jalr this cycle
    // If that's the case, we need to flush the next two instructions because they were wrongly fetched
    input wire i_branch,
    input wire i_jalr,

    input wire flopped_rst2,

    input wire i_flush_ID,

    // Forwarding signals
    output wire r1_Forwarding, r2_Forwarding,
    output wire [31:0] r1_ForwardValue, r2_ForwardValue,


    // This wire goes to the ID and EX pipeline registers to set their write control signal bits to 0
    // so that wrongly fetched instructions can't write to anything (and also dmem read, just in case)
    output wire o_flush,

    // Single bit output used as a selector bit for a 2:1 MUX
    // When high, this indicates a branch condition has been met and allows the calculated
    // instruction address to be sent to the PC
    output wire o_enable

);

    // Constants that define the opcodes for different instruction types
    localparam R_TYPE = 7'b011_0011;
    localparam I_ARITH = 7'b001_0011;
    localparam L_TYPE = 7'b000_0011;
    localparam S_TYPE = 7'b010_0011;
    localparam B_TYPE = 7'b110_0011;
    localparam LUI = 7'b011_0111;
    localparam AUIPC = 7'b001_0111;
    localparam JALR = 7'b110_0111;
    localparam JAL = 7'b110_1111;
    localparam EBREAK = 7'b111_0011;


    // Declare internal signals
    wire rs1_read, rs2_read, trap, rs1RawHazard, rs2RawHazard, branching, Load_Stall;
    wire [31:0] MEM_EX_Type;
    
    // 2 bit signal that controls whether to use forwarding signals or register value in ALU input
    // 2'b00: no forwarding - read value from register file
    // 2'b01: EX-EX - reads from alu result
    // 2'b10: MEM-EX - reads from wb result (write data of rf)
    // 2'b11: not used, default to register file
    wire [1:0] r1_ForwardingType;
    wire [1:0] r2_ForwardingType;

    // Determine if we're branching to a non-zero value
    assign branching = (i_branch | i_jalr);

    // Determine if rs1 is being read with this instruction
    assign rs1_read = ((i_IdOpcode == JALR) |                       
                   (i_IdOpcode == R_TYPE) |
                   (i_IdOpcode == I_ARITH) |
                   (i_IdOpcode == L_TYPE) |
                   (i_IdOpcode == S_TYPE) |
                   (i_IdOpcode == B_TYPE)) ? 1'b1 : 1'b0;

    // Determine if rs2 is being read with this instruction
    assign rs2_read = ((i_IdOpcode == R_TYPE) |
                    (i_IdOpcode == S_TYPE) |
                    (i_IdOpcode == B_TYPE)) ? 1'b1 : 1'b0;

    // Determine if there's a TRAP that needs to happen
    assign trap = (i_badOpcode & ~branching) | i_badDmem | i_badPC;


    // Determine if there's a RAW hazard
    // Also ignore RAW hazard if there's a branch/jal/jalr or if read register is x0
    // RAW hazard when register is read in ID before it's written to from an instruction
    // in EX or MEM (we can ignore WB because we have rf forwarding)

    // Signal indicates if RawHazard is possible
    assign rs1RawHazard = rs1_read & (~(i_rs1_raddr == 5'b0));
    assign rs2RawHazard = rs2_read & (~(i_rs2_raddr == 5'b0)); 

    assign r1_ForwardingType = 
        ((rs1RawHazard & ex_RegWrite & (i_rs1_raddr == ex_wAddr))   ? 2'b01 :  // EX-EX Forwarding
        ((rs1RawHazard & mem_RegWrite & (i_rs1_raddr == mem_wAddr)) ? 2'b10 :  // MEM-EX Forwarding
        2'b00));                                                                 // No Forwarding

    assign r2_ForwardingType = 
        ((rs2RawHazard & ex_RegWrite & (i_rs2_raddr == ex_wAddr))   ? 2'b01 :  // EX-EX Forwarding
        ((rs2RawHazard & mem_RegWrite & (i_rs2_raddr == mem_wAddr)) ? 2'b10 :  // MEM-EX Forwarding
        2'b00));                                                                 // No Forwarding

    assign r1_Forwarding = (r1_ForwardingType == 2'b00) ? 1'b0 : 1'b1;
    assign r2_Forwarding = (r2_ForwardingType == 2'b00) ? 1'b0 : 1'b1;

    // Since MEM-EX Forwarding can be Reg-Reg OR Mem-Reg we need to determine which one is required for each case
    assign MEM_EX_Type =  (mem_Opcode == L_TYPE) ? mem_ReadData : mem_Result;

    assign r1_ForwardValue = 
        ((r1_ForwardingType == 2'b01) ? ex_Result   :                             // EX-EX
        ((r1_ForwardingType == 2'b10) ? MEM_EX_Type :                             // MEM-EX
        (32'b0)));                                                                // No forwarding, Don't care.

    assign r2_ForwardValue = 
        ((r2_ForwardingType == 2'b01) ? ex_Result   :                             // EX-EX
        ((r2_ForwardingType == 2'b10) ? MEM_EX_Type :                             // MEM-EX
        (32'b0)));                                                                // No forwarding, Don't care.
    
    // When we have a load instruction in MEM stage and we need to forward its read data, we need to stall
    // Also need to stall when forwarding is triggered in EXE stage by a load instruction, memory value isnt ready yet
    wire r1_ex_load = (ex_Opcode == L_TYPE) & (r1_ForwardingType == 2'b01);
    wire r2_ex_load = (ex_Opcode == L_TYPE) & (r2_ForwardingType == 2'b01);
    wire r1_mem_load = (mem_Opcode == L_TYPE) & (r1_ForwardingType == 2'b10);
    wire r2_mem_load = (mem_Opcode == L_TYPE) & (r2_ForwardingType == 2'b10);

    assign Load_Stall = r1_ex_load | r2_ex_load | r1_mem_load | r2_mem_load;


    // Disable the PC and IF/ID, ID/EX registers if there's a RAW hazard (in memory or the register file) 
    // and we're not branching and we have no halt signals and
    // we've gone a few cycles past reset (to avoid false trips at startup)
    assign o_enable = ( (~flopped_rst2 & (i_rs1_raddr == 5'b0) & (i_rs2_raddr == 5'b0)) |
                    (~(trap & ~i_flush_ID & ~(i_IdOpcode == EBREAK))) ) &
                    (~Load_Stall);

    // Turn off the control bits for regWrite, memWrite, and memRead if the conditions for
    // o_enable = 0 are met or we're branching
    assign o_flush = (~o_enable | branching);


endmodule
`default_nettype wire