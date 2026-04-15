`default_nettype none

module generalControl (

    // 32 bit instruction from instruction memory 
    input wire [31:0] instruction,

    // Single bit output used as selector bit for a 4:1 MUX
    // When high, the PC value is used as part of the write data input of the Register File
    output reg o_RegInPCSrc,

    // Single bit output used as selector bit for a 4:1 MUX
    // When low, an immediate value is used as part of the write data input for the Register File
    output reg o_RegInNon_Imm,

    // Single bit output used as a selector bit for a 2:1 MUX 
    // When high, this indicates that the instruction given is loading memory data to a register. 
    // This output bit allows the MUX to send down the memory data to the register file write data input.
    output reg o_MemToReg,

    // Single bit output used to set Read Enable of the Data Memory.
    // When high, Reading is enabled for the Data Memory
    output reg o_MemRead,

    // Single bit output used to set Write Enable of the Data Memory.
    // When high, writing is enabled for the Data Memory
    output reg o_MemWrite,

    // Single bit output used as a selector bit of a 2:1 MUX
    // When high, the MUX outputs register data as the second operator of the ALU
    // When low, the MUX outputs an immediate value as the second operator of the ALU
    output reg o_ALU_op2_reg,

    // Single bit output used to enable Register Write for the Register File 
    // When high, Writing to a register is enabled.
    output reg o_RegWrite,

    // Single bit output used to select ALU subtraction
    output reg o_ALU_subtract,

    // Single bit output used to select ALU arithmetic right shift
    output reg o_ALU_arith,

    // Single bit output used to specify ALU unsigned operations & comparison
    output reg o_ALU_unsigned,

    // ALU opcode output
    // NOTE: In order to simplify instruction decoding in phase 4, both 3'b010
    // and 3'b011 are used for set less than (they are equivalent).
    // Unsigned comparison is controlled through the `i_unsigned` signal.
    //
    // 3'b000: addition/subtraction if `i_sub` asserted
    // 3'b001: shift left logical
    // 3'b010,
    // 3'b011: set less than/unsigned if `i_unsigned` asserted
    // 3'b100: exclusive or
    // 3'b101: shift right logical/arithmetic if `i_arith` asserted
    // 3'b110: or
    // 3'b111: and
    output reg [2:0] o_ALU_opcode,

    // Signals that an EBREAK instruction is happening
    output reg o_ebreak,

    // Signals the PC to remain at its current value
    output reg o_halt,

    // Signals that a TRAP is happening
    output reg o_trap
);

// Extract the 7 bit opcode from the 32 bit instruction 
wire [6:0] opcode = instruction[6:0];

// funct3 bits from instruction.
wire [2:0] funct3 = instruction[14:12];

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

// Branch Instruction funct3 bits
localparam BEQ = 3'b000;
localparam BNE = 3'b001;
localparam BLT = 3'b100;
localparam BGE = 3'b101;
localparam BLTU = 3'b110;
localparam BGEU = 3'b111;

// The outputs of this module are specified by this case statement
// It chooses the outputs based on opcodes, because they remain consistent within opcodes
always @(*) begin
    // These are defaults to make sure that the value we expect is applied if nothing is specified.

    // Defaults in English:
    // Register input defaults to the ALU/dataMem mux
    // Do not set the PC to the ALU output
    // Register input is from ALU result
    // Disable memory reading/writing
    // ALU op2 is the immediate decoder output
    // Enable register writing (most of our instructions do)

    // ALU add operations add
    // ALU arith follows instruction[30]
    // ALU does signed operations
    // Use ALU add operation

    o_RegInPCSrc = 0;
    o_RegInNon_Imm = 1;
    o_MemToReg = 0;
    o_MemRead = 0;
    o_MemWrite = 0;
    o_ALU_op2_reg = 0;
    o_RegWrite = 1;
    o_trap = 0;

    o_ALU_subtract = 0;
    o_ALU_arith = instruction[30];
    o_ALU_unsigned = 0;
    o_ALU_opcode = 3'b0;

    o_ebreak = 0;
    o_halt = 0;
    
    case (opcode)
        R_TYPE: begin
            o_ALU_op2_reg = 1;
            o_ALU_opcode = funct3[2:0];

            // If it's an sltu instruction, set ALU unsigned
            if(funct3 == 3'b011)
                o_ALU_unsigned = 1;

            // If it's an add instruction, enable subtraction signal
            if(funct3 == 3'b000)
                o_ALU_subtract = instruction[30];

        end

        I_ARITH: begin
            o_ALU_opcode = funct3;
            o_ALU_arith = (funct3 == 3'b101) ? instruction[30] : 0; // srli=0, srai=1
            o_ALU_unsigned = (funct3 == 3'b011) ? 1 : 0;
        end

        L_TYPE: begin
            o_MemToReg = 1;
            o_MemRead = 1;
        end

        S_TYPE: begin
            o_MemWrite = 1;
            o_RegWrite = 0;
        end

        B_TYPE: begin
            o_ALU_op2_reg = 1;
            o_RegWrite = 0;

            // ALU unsigned logic
            // Can optimize this by checking funct3[1]
            o_ALU_unsigned = (funct3 == BLTU || funct3 == BGEU);
        end

        LUI: begin
            o_RegInNon_Imm = 0;
        end

        AUIPC: begin
            o_RegInPCSrc = 1;
            o_RegInNon_Imm = 0;
        end

        JALR: begin
            o_RegInPCSrc = 1;
        end

        JAL: begin
            o_RegInPCSrc = 1;
        end
        EBREAK: begin
            o_RegWrite = 0;
            o_ebreak = 1;
            o_halt = 1;
        end
        default: begin
            // This means there was an invalid opcode, so activate the trap card
            o_halt = 1'b1;
            o_trap = 1;
        end

    endcase
    
end

endmodule

`default_nettype wire
