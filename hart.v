module hart #(
    // After reset, the program counter (PC) should be initialized to this
    // address and start executing instructions from there.
    parameter RESET_ADDR = 32'h00000000
) (
    // Global clock.
    input  wire        i_clk,
    // Synchronous active-high reset.
    input  wire        i_rst,
    // Instruction fetch goes through a read only instruction memory (imem)
    // port. The port accepts a 32-bit address (e.g. from the program counter)
    // per cycle and combinationally returns a 32-bit instruction word. This
    // is not representative of a realistic memory interface; it has been
    // modeled as more similar to a DFF or SRAM to simplify phase 3. In
    // later phases, you will replace this with a more realistic memory.
    //
    // 32-bit read address for the instruction memory. This is expected to be
    // 4 byte aligned - that is, the two LSBs should be zero.
    output wire [31:0] o_imem_raddr,
    // Instruction word fetched from memory, available synchronously after
    // the next clock edge.
    // NOTE: This is different from the previous phase. To accomodate a
    // multi-cycle pipelined design, the instruction memory read is
    // now synchronous.
    input  wire [31:0] i_imem_rdata,
    // Data memory accesses go through a separate read/write data memory (dmem)
    // that is shared between read (load) and write (stored). The port accepts
    // a 32-bit address, read or write enable, and mask (explained below) each
    // cycle. Reads are combinational - values are available immediately after
    // updating the address and asserting read enable. Writes occur on (and
    // are visible at) the next clock edge.
    //
    // Read/write address for the data memory. This should be 32-bit aligned
    // (i.e. the two LSB should be zero). See `o_dmem_mask` for how to perform
    // half-word and byte accesses at unaligned addresses.
    output wire [31:0] o_dmem_addr,
    // When asserted, the memory will perform a read at the aligned address
    // specified by `i_addr` and return the 32-bit word at that address
    // immediately (i.e. combinationally). It is illegal to assert this and
    // `o_dmem_wen` on the same cycle.
    output wire        o_dmem_ren,
    // When asserted, the memory will perform a write to the aligned address
    // `o_dmem_addr`. When asserted, the memory will write the bytes in
    // `o_dmem_wdata` (specified by the mask) to memory at the specified
    // address on the next rising clock edge. It is illegal to assert this and
    // `o_dmem_ren` on the same cycle.
    output wire        o_dmem_wen,
    // The 32-bit word to write to memory when `o_dmem_wen` is asserted. When
    // write enable is asserted, the byte lanes specified by the mask will be
    // written to the memory word at the aligned address at the next rising
    // clock edge. The other byte lanes of the word will be unaffected.
    output wire [31:0] o_dmem_wdata,
    // The dmem interface expects word (32 bit) aligned addresses. However,
    // WISC-25 supports byte and half-word loads and stores at unaligned and
    // 16-bit aligned addresses, respectively. To support this, the access
    // mask specifies which bytes within the 32-bit word are actually read
    // from or written to memory.
    //
    // To perform a half-word read at address 0x00001002, align `o_dmem_addr`
    // to 0x00001000, assert `o_dmem_ren`, and set the mask to 0b1100 to
    // indicate that only the upper two bytes should be read. Only the upper
    // two bytes of `i_dmem_rdata` can be assumed to have valid data; to
    // calculate the final value of the `lh[u]` instruction, shift the rdata
    // word right by 16 bits and sign/zero extend as appropriate.
    //
    // To perform a byte write at address 0x00002003, align `o_dmem_addr` to
    // `0x00002000`, assert `o_dmem_wen`, and set the mask to 0b1000 to
    // indicate that only the upper byte should be written. On the next clock
    // cycle, the upper byte of `o_dmem_wdata` will be written to memory, with
    // the other three bytes of the aligned word unaffected. Remember to shift
    // the value of the `sb` instruction left by 24 bits to place it in the
    // appropriate byte lane.
    output wire [ 3:0] o_dmem_mask,
    // The 32-bit word read from data memory. When `o_dmem_ren` is asserted,
    // after the next clock edge, this will reflect the contents of memory
    // at the specified address, for the bytes enabled by the mask. When
    // read enable is not asserted, or for bytes not set in the mask, the
    // value is undefined.
    // NOTE: This is different from the previous phase. To accomodate a
    // multi-cycle pipelined design, the data memory read is
    // now synchronous.
    input  wire [31:0] i_dmem_rdata,
	// The output `retire` interface is used to signal to the testbench that
    // the CPU has completed and retired an instruction. A single cycle
    // implementation will assert this every cycle; however, a pipelined
    // implementation that needs to stall (due to internal hazards or waiting
    // on memory accesses) will not assert the signal on cycles where the
    // instruction in the writeback stage is not retiring.
    //
    // Asserted when an instruction is being retired this cycle. If this is
    // not asserted, the other retire signals are ignored and may be left invalid.
    output wire        o_retire_valid,
    // The 32 bit instruction word of the instrution being retired. This
    // should be the unmodified instruction word fetched from instruction
    // memory.
    output wire [31:0] o_retire_inst,
    // Asserted if the instruction produced a trap, due to an illegal
    // instruction, unaligned data memory access, or unaligned instruction
    // address on a taken branch or jump.
    output wire        o_retire_trap,
    // Asserted if the instruction is an `ebreak` instruction used to halt the
    // processor. This is used for debugging and testing purposes to end
    // a program.
    output wire        o_retire_halt,
    // The first register address read by the instruction being retired. If
    // the instruction does not read from a register (like `lui`), this
    // should be 5'd0.
    output wire [ 4:0] o_retire_rs1_raddr,
    // The second register address read by the instruction being retired. If
    // the instruction does not read from a second register (like `addi`), this
    // should be 5'd0.
    output wire [ 4:0] o_retire_rs2_raddr,
    // The first source register data read from the register file (in the
    // decode stage) for the instruction being retired. If rs1 is 5'd0, this
    // should also be 32'd0.
    output wire [31:0] o_retire_rs1_rdata,
    // The second source register data read from the register file (in the
    // decode stage) for the instruction being retired. If rs2 is 5'd0, this
    // should also be 32'd0.
    output wire [31:0] o_retire_rs2_rdata,
    // The destination register address written by the instruction being
    // retired. If the instruction does not write to a register (like `sw`),
    // this should be 5'd0.
    output wire [ 4:0] o_retire_rd_waddr,
    // The destination register data written to the register file in the
    // writeback stage by this instruction. If rd is 5'd0, this field is
    // ignored and can be treated as a don't care.
    output wire [31:0] o_retire_rd_wdata,
    // The following data memory retire interface is used to record the
    // memory transactions completed by the instruction being retired.
    // As such, it mirrors the transactions happening on the main data
    // memory interface (o_dmem_* and i_dmem_*) but is delayed to match
    // the retirement of the instruction. You can hook this up by just
    // registering the main dmem interface signals into the writeback
    // stage of your pipeline.
    //
    // All these fields are don't-care for instructions that do not
    // access data memory (o_retire_dmem_ren and o_retire_dmem_wen
    // not asserted).
    // NOTE: This interface is new for phase 5 in order to account for
    // the delay between data memory accesses and instruction retire.
    //
    // The 32-bit data memory address accessed by the instruction.
    output wire [31:0] o_retire_dmem_addr,
    // The byte masked used for the data memory access.
    output wire [ 3:0] o_retire_dmem_mask,
    // Asserted if the instruction performed a read (load) from data memory.
    output wire        o_retire_dmem_ren,
    // Asserted if the instruction performed a write (store) to data memory.
    output wire        o_retire_dmem_wen,
    // The 32-bit data read from memory by a load instruction.
    output wire [31:0] o_retire_dmem_rdata,
    // The 32-bit data written to memory by a store instruction.
    output wire [31:0] o_retire_dmem_wdata,
    // The current program counter of the instruction being retired - i.e.
    // the instruction memory address that the instruction was fetched from.
    output wire [31:0] o_retire_pc,
    // the next program counter after the instruction is retired. For most
    // instructions, this is `o_retire_pc + 4`, but must be the branch or jump
    // target for *taken* branches and jumps.
    output wire [31:0] o_retire_next_pc

`ifdef RISCV_FORMAL
    ,`RVFI_OUTPUTS,
`endif
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



// Net Instantiation: divide by pipeline stage

      /////////////////
     // 1: IF Fetch //
    /////////////////


    // pc wires
    wire [31:0] pc_in, pc_out, pc_next;

    // instruction is read from i_imem_rdata
    // Flush signal used to indicate a flush is needed and pipeline registers must be flushed.
    wire c_flush;

    // Signal that enables the pipeline registers, allowing them to be updated when signal is high 
    // and forcing them to hold their old value when signal is low
    wire c_enable;

    // Signal is used to indicate a misaligned PC value.
    wire c_badPC;
    
    // Signals used to cause a delay after a reset to allow enough time to pass.
    wire flopped_rst1, flopped_rst2, flopped_rst3, flopped_rst4, flopped_rst5;

      //////////////////
     // 2: ID Decode //
    //////////////////

  wire flopped_ebreak1, flopped_ebreak2, flopped_ebreak3, flopped_ebreak4;

    // ID pipeline register wires
    wire [31:0] pc_ID;
    wire [31:0] instruction_ID;
    // pipeline register control wires
    wire c_RegWrite_ID, c_RegInPCSrc_ID, c_RegInNon_Imm_ID;
    wire c_MemToReg_ID, c_MemWrite_ID, c_MemRead_ID;
    wire c_ALU_subtract_ID, c_ALU_arith_ID, c_ALU_unsigned_ID;
    wire [2:0] c_ALU_opcode_ID;
    wire c_ALU_op2_reg_ID;
    wire c_flush_ID;

    // immediate wires
    wire [5:0] instType_format;
    wire [31:0] immediate_ID;

    // rf wires
    wire [31:0] rf_write_data, rf_rs1_rdata_ID, rf_rs2_rdata_ID;

    // Register data wires 
    wire [31:0] rs1_data_ID, rs2_data_ID;

    // Forwarding MUX wires
    wire r1_ForwardingSel, r2_ForwardingSel;
    wire [31:0] r1_ForwardValue, r2_ForwardValue;


      ///////////////////
     // 3: EX Execute //
    ///////////////////


    // EX pipeline register wires
    wire [31:0] pc_EX, pc_MEM, pc_WB;
    wire [31:0] instruction_EX;
    wire [31:0] immediate_EX;
    // pipeline register control wires
    wire c_RegWrite_EX, c_RegInPCSrc_EX, c_RegInNon_Imm_EX;
    wire c_MemToReg_EX, c_MemWrite_EX, c_MemRead_EX;
    wire c_ALU_subtract_EX, c_ALU_arith_EX, c_ALU_unsigned_EX;
    wire [2:0] c_ALU_opcode_EX;
    wire c_ALU_op2_reg_EX;
    wire c_flush_EX;
    wire c_badDmem;

    // pipeline register rf wires
    wire [31:0] rf_rs1_rdata_EX, rf_rs2_rdata_EX;

    // pc logic wires
    wire [31:0] pc_mux_branch, pc_add_imm_EX, pc_add_4_EX, pcEX_add_4_EX;
    // control wires
    wire c_JALR, c_Branch, c_HALT, c_TRAP, c_EBREAK, c_LUI;
    wire c_ALU_equal, c_ALU_slt;
    // ALU wires
    wire [31:0] ALU_i2_data, ALU_result_EX;
    // Data memory mask gen wires
    wire [31:0] o_dmem_wdata_EX;
    wire [3:0] o_dmem_mask_EX;

    // Misaligned address 
    wire word_misaligned, half_misaligned;


      //////////////////////////
     // 4: MEM Memory Access //
    //////////////////////////

    wire c_flush_MEM;

    // MEM pipeline register wires
    wire [31:0] instruction_MEM;
    wire [31:0] immediate_MEM;
    // pipeline register pc logic wires
    wire [31:0] pc_add_imm_MEM, pc_add_4_MEM;
    // pipeline register control wires
    wire c_RegWrite_MEM, c_RegInPCSrc_MEM, c_RegInNon_Imm_MEM;
    wire c_MemToReg_MEM, c_MemWrite_MEM, c_MemRead_MEM;
    // pipeline register rf wires
    wire [31:0] rf_rs1_rdata_MEM, rf_rs2_rdata_MEM;
    // pipeline register ALU wire
    wire [31:0] ALU_result_MEM;
    // Data memory mask gen wires
    wire [31:0] o_dmem_wdata_MEM;
    wire [3:0] o_dmem_mask_MEM;

      //////////////////////
     // 5: WB Write Back //
    //////////////////////

    // WB pipeline register wires
    wire [31:0] instruction_WB;
    wire [31:0] immediate_WB;
    // pipeline register pc logic wires
    wire [31:0] pc_add_imm_WB, pc_add_4_WB;
    // pipeline register control wires
    wire c_RegWrite_WB, c_RegInPCSrc_WB, c_RegInNon_Imm_WB, c_MemToReg_WB;
    // pipeline register rf wires
    wire [31:0] rf_rs1_rdata_WB, rf_rs2_rdata_WB;
    // pipeline register ALU wire
    wire [31:0] ALU_result_WB;

    // rf 4:1 mux wires
    wire [31:0] rf_mux_dmem, rf_dmem_out;

    // data memory pipeline register wires
    wire [31:0] r_dmem_addr_WB;
    wire [3:0] r_dmem_mask_WB;
    wire r_dmem_ren_WB, r_dmem_wen_WB;
    wire [31:0] r_dmem_wdata_WB;

// Module Instantiation: divide by pipeline stage

      /////////////////
     // 1: IF Fetch //
    /////////////////


    // Send PC value to instruction memory Read Address 
    pc iPC(.i_clk(i_clk), .i_rst(i_rst), .i_d(pc_in), .o_q(pc_out), .enable(c_enable));


      ////////////////////////////////
     // IF/ID: Register Pipeline 1 //
    ////////////////////////////////

    // pipeline registers

    // Sequence of DFFs in series. These 5 DFFs are propagate a 1 bit high signal, since there's 5 DFFs it takes 5 cycles for the 5th DFF to 
    // be updated with the high signal. This allows us to use any one of these signals show us how long its been since a reset. 
    // Counting the number of cycles after a reset allows us to avoid propagating garbage data that would lead to a trap being triggered.
    dff_1       iDFF_rst1(.clk(i_clk), .rst(i_rst), .d(1'b1), .q(flopped_rst1));
    dff_1       iDFF_rst2(.clk(i_clk), .rst(i_rst), .d(flopped_rst1), .q(flopped_rst2));
    dff_1       iDFF_rst3(.clk(i_clk), .rst(i_rst), .d(flopped_rst2), .q(flopped_rst3));
    dff_1       iDFF_rst4(.clk(i_clk), .rst(i_rst), .d(flopped_rst3), .q(flopped_rst4));
    dff_1       iDFF_rst5(.clk(i_clk), .rst(i_rst), .d(flopped_rst4), .q(flopped_rst5));
    
    // Hold the old value of the PC until we need to freeze ID stage
    // Here iDFFpc1 holds the the PC value which is also the instruction address for Instruction memory
    // Then the next cycle to determine the next instruction address for Instruction Memory, we either choose the new PC or we Choose the old PC from last cycle
    // This allows us to stall the propagation of instructions.
    dff_32_en iDFFpc1(.clk(i_clk), .rst(i_rst), .d(o_imem_raddr), .q(pc_ID), .enable(c_enable));    // DFF stores the current PC which is the input address for Instruction Memory
    assign o_imem_raddr = (c_enable & flopped_rst1) ? pc_out : (pc_ID !== 32'bx ? pc_ID : 32'b0);   // Next instruction address for instruction memory is determined 

    // Single Bit register that stores a flush signal. When a branch is taken or we have a Jump instruction we must flush
    // Since we find out that we need to flush at end of EX stage, we don't have enough time to flush in the same cycle.
    // So we must ensure that we have a flush signal that initiates a flush in the cycle after we discover we need to flush.
    dff_1       iDFF_flush1(.clk(i_clk), .rst(i_rst), .d(c_Branch | c_JALR), .q(c_flush_ID));

    // Propagate instruction or flush
    assign instruction_ID[31:0] = (c_flush_ID) ? 32'h00000013 : i_imem_rdata[31:0];
      //////////////////
     // 2: ID Decode //
    //////////////////


    // Flush signal to flush instruction before control signals are

    // Control signal processor
    generalControl iControl(
        .instruction(instruction_ID),                                                                                                         // Inputs
        .o_RegInPCSrc(c_RegInPCSrc_ID), .o_RegInNon_Imm(c_RegInNon_Imm_ID), .o_ALU_op2_reg(c_ALU_op2_reg_ID),                                 // Control muxes
        .o_MemToReg(c_MemToReg_ID), .o_MemRead(c_MemRead_ID), .o_MemWrite(c_MemWrite_ID),  .o_RegWrite(c_RegWrite_ID),                        // DM stuff
        .o_ALU_subtract(c_ALU_subtract_ID), .o_ALU_arith(c_ALU_arith_ID), .o_ALU_unsigned(c_ALU_unsigned_ID), .o_ALU_opcode(c_ALU_opcode_ID), // ALU stuff
        .o_ebreak(c_EBREAK), .o_halt(c_HALT), .o_trap(c_TRAP));                                                                               // Instruction checking stuff

    // Immediate generator
    imm iIMM(.i_inst(instruction_ID), .i_format(instType_format), .o_immediate(immediate_ID));

    // 1-hot encoder for immediate generator
    opcodeDecoder iOpcode(.i_opcode(instruction_ID[6:0]), .o_instType(instType_format));

    // Register file
    rf rf(.i_clk(i_clk), .i_rst(i_rst), .i_rs1_raddr(instruction_ID[19:15]), .o_rs1_rdata(rf_rs1_rdata_ID), 
        .i_rs2_raddr(instruction_ID[24:20]), .o_rs2_rdata(rf_rs2_rdata_ID), 
        .i_rd_wen(c_RegWrite_WB), .i_rd_waddr(instruction_WB[11:7]), .i_rd_wdata(rf_write_data));
      
    // Forwarding MUXs
    mux2 r1_Forwarding_MUX(.i_op1(rf_rs1_rdata_ID), .i_op2(r1_ForwardValue), .i_sel(r1_ForwardingSel), .o_result(rs1_data_ID));
    
    mux2 r2_Forwarding_MUX(.i_op1(rf_rs2_rdata_ID), .i_op2(r2_ForwardValue), .i_sel(r2_ForwardingSel), .o_result(rs2_data_ID));

      ////////////////////////////////
     // ID/EX: Register Pipeline 2 //
    ////////////////////////////////

    // EBREAK instruction delay. The EBREAK instruction is identified by the general control module in the ID stage, 
    // but we don't want to end the program until the instruciton has fully propagated through.
    // So If its found in ID stage, it still need to go through the EX, MEM, and WB stages so thats 3 cycles that need to pass until we can end the program due to an EBREAK 
    dff_1       iDFF_ebreak1(.clk(i_clk), .rst(i_rst), .d(c_EBREAK), .q(flopped_ebreak1));
    dff_1       iDFF_ebreak2(.clk(i_clk), .rst(i_rst), .d(flopped_ebreak1), .q(flopped_ebreak2));
    dff_1       iDFF_ebreak3(.clk(i_clk), .rst(i_rst), .d(flopped_ebreak2), .q(flopped_ebreak3));
    dff_1       iDFF_ebreak4(.clk(i_clk), .rst(i_rst), .d(flopped_ebreak3), .q(flopped_ebreak4));
    
    // ID/EX pipeline registers
    dff_32_en iDFFpc2(.clk(i_clk), .rst(i_rst), .d(pc_ID), .q(pc_EX), .enable(c_enable));                                                     // PC Register, Holds PC of instruction in this stage
    dff_32_en iDFFinstr2(.clk(i_clk), .rst(i_rst | ((c_flush | c_flush_ID))), .d(instruction_ID), .q(instruction_EX), .enable(c_enable));    // Instruction Register
    dff_32_en iDFFimm2(.clk(i_clk), .rst(i_rst), .d(immediate_ID), .q(immediate_EX), .enable(c_enable));                                      // Immediate Register

    // control pipeline registers (set regwrite & dmem bits to 0 for flush here)
    dff_1       iDFF_flush2(.clk(i_clk), .rst(i_rst), .d(c_flush_ID), .q(c_flush_EX));                                                          
    dff_en    iDFF_RegWrite2(.clk(i_clk), .rst(i_rst | c_flush | c_flush_ID), .d(c_RegWrite_ID), .q(c_RegWrite_EX), .enable(c_enable));     
    dff_en    iDFF_RegInPCSrc2(.clk(i_clk), .rst(i_rst), .d(c_RegInPCSrc_ID), .q(c_RegInPCSrc_EX), .enable(c_enable));                        
    dff_en    iDFF_RegInNon_Imm2(.clk(i_clk), .rst(i_rst), .d(c_RegInNon_Imm_ID), .q(c_RegInNon_Imm_EX), .enable(c_enable));
    dff_en    iDFF_MemToReg2(.clk(i_clk), .rst(i_rst), .d(c_MemToReg_ID), .q(c_MemToReg_EX), .enable(c_enable));
    dff_en    iDFF_MemWrite2(.clk(i_clk), .rst(i_rst | c_flush | c_flush_ID), .d(c_MemWrite_ID), .q(c_MemWrite_EX), .enable(c_enable));
    dff_en    iDFF_MemRead2(.clk(i_clk), .rst(i_rst | c_flush | c_flush_ID), .d(c_MemRead_ID), .q(c_MemRead_EX), .enable(c_enable));
    dff_en    iDFF_ALU_subtract2(.clk(i_clk), .rst(i_rst), .d(c_ALU_subtract_ID), .q(c_ALU_subtract_EX), .enable(c_enable));
    dff_en    iDFF_ALU_arith2(.clk(i_clk), .rst(i_rst), .d(c_ALU_arith_ID), .q(c_ALU_arith_EX), .enable(c_enable));
    dff_en    iDFF_ALU_unsigned2(.clk(i_clk), .rst(i_rst), .d(c_ALU_unsigned_ID), .q(c_ALU_unsigned_EX), .enable(c_enable));
    dff_en    iDFF_ALU_op2_reg2(.clk(i_clk), .rst(i_rst), .d(c_ALU_op2_reg_ID), .q(c_ALU_op2_reg_EX), .enable(c_enable));

    // register file pipeline registers
    dff_32_en iDFF_rf_rs1_rdata2(.clk(i_clk), .rst(i_rst), .d(rs1_data_ID), .q(rf_rs1_rdata_EX), .enable(c_enable));
    dff_32_en iDFF_rf_rs2_rdata2(.clk(i_clk), .rst(i_rst), .d(rs2_data_ID), .q(rf_rs2_rdata_EX), .enable(c_enable));
    //dff_5_en iDFF_rf_rs1_raddr2(.clk(i_clk), .rst(i_rst), .d(instruction_ID[19:15]), .q(rf_rs2_rdata_EX), .enable(c_enable));    // ID/EX pipeline register that hold register 1 address
    //dff_5_en iDFF_rf_rs2_raddr2(.clk(i_clk), .rst(i_rst), .d(instruction_ID[24:20]), .q(rf_rs2_rdata_EX), .enable(c_enable));    // ID/EX pipeline register that hold register 2 address


      ///////////////////
     // 3: EX Execute //
    ///////////////////
    

    // Adder that adds 4 to the pc_out value (used by default to advance to the next inst)
    assign pc_add_4_EX = pc_out + 4;

    // Adder that adds 4 to PC_EX
    assign pcEX_add_4_EX = pc_EX + 4;

    // Adder that adds immediate to PC_EX
    assign pc_add_imm_EX = pc_EX + immediate_EX;

    // Mux that decides whether to use pc+4 or pc+imm (for branch instructions)
    mux2 i2MUX1(.i_op1(pc_add_4_EX), .i_op2(pc_add_imm_EX), .i_sel(c_Branch), .o_result(pc_mux_branch));

    // Mux that decides whether to use the ALU output or output for other adder (for JALR instructions)
    assign pc_next = (pc_out === 32'bx) ? 32'b0 : pc_mux_branch;
    mux2 i2MUX2(.i_op1(pc_next), .i_op2({ALU_result_EX[31:1],1'b0}), .i_sel(c_JALR), .o_result(pc_in));

    // Branch and flush logic
    branchControl bControl(.i_opcode(instruction_EX[6:0]), .i_funct3(instruction_EX[14:12]), .i_ALU_equal(c_ALU_equal), .i_ALU_slt(c_ALU_slt), .o_Branch(c_Branch), .o_JALR(c_JALR), .o_LUI(c_LUI));


    // Mux to select whether ALU op2 is RS2 or immediate
    mux2 i2MUXalu(.i_op1(immediate_EX), .i_op2(rf_rs2_rdata_EX), .i_sel(c_ALU_op2_reg_EX), .o_result(ALU_i2_data));

    // Make ALU opcode (This was moved out of generalControl because of a setup time violation in post-synth simulation)
    assign c_ALU_opcode_EX = (instruction_EX[6:0] == I_ARITH) ? instruction_EX[14:12] :
    (instruction_EX[6:0] == R_TYPE) ? instruction_EX[14:12] : 3'b0;
    

    // ALU - Arithmetic Logic Unit
    alu iALU(.i_opsel(c_ALU_opcode_EX), .i_sub(c_ALU_subtract_EX), .i_unsigned(c_ALU_unsigned_EX), .i_arith(c_ALU_arith_EX), 
        .i_op1((c_LUI) ? 32'b0 : rf_rs1_rdata_EX), .i_op2(ALU_i2_data), .o_result(ALU_result_EX), .o_eq(c_ALU_equal), .o_slt(c_ALU_slt));

    // Check for the possibility of misaligned data
    // A word instruction can has misaligned data if the 2 LSBs of the address being read or writen to are not 0 since the address should be multiple of 4
    // A half-word instruction can have misaligned data if the LSB of the address being read or writen to is not 0 since the address should be a multiple of 2
    // A byte instruction can have have 1's or 0's as the LSBs of the address being read or writen to because its a single byte so address should be a multiple of 1.
    assign word_misaligned = ALU_result_EX[1:0] == 2'b00 ? 0 : 1;
    assign half_misaligned = ALU_result_EX[0] == 1'b0 ? 0 : 1; 

    // Singal indicates when we have misaligned data. This can occur when performing load or store instructions on word or half-words. 
    // the instruction bits [14:12] are the funct3 bits. funct3 = 3'b010 indicates a word instruction, funct3 = 3'b001 indicates a half-word instruction.
    assign c_badDmem = (c_MemRead_EX | c_MemWrite_EX) & ((word_misaligned & (instruction_EX[14:12] == 3'b010))| (half_misaligned & (instruction_EX[14:12] == 3'b001)));

    // Data memory mask generator
    DMMask iDMMask(.i_funct3(instruction_EX[14:12]), .i_addr(ALU_result_EX[1:0]), .i_regReadData(rf_rs2_rdata_EX[31:0]), 
        .o_DMWriteData(o_dmem_wdata_EX), .o_DMMask(o_dmem_mask_EX));

    assign c_badPC = pc_in[1] | pc_in[0];

    // Hazard and Halt Unit
    hazardHalt iHazardHalt(
        .mem_wAddr(instruction_MEM[11:7]), .mem_RegWrite(c_RegWrite_MEM), .mem_Result(ALU_result_MEM), .mem_ReadData(rf_dmem_out), .mem_Opcode(instruction_MEM[6:0]),        // MEM pipeline registers 
        .ex_wAddr(instruction_EX[11:7]), .ex_RegWrite(c_RegWrite_EX), .ex_Result(ALU_result_EX), .ex_Opcode(instruction_EX[6:0]),                                                                               // EX pipeline registers 
        .i_rs1_raddr(instruction_ID[19:15]), .i_rs2_raddr(instruction_ID[24:20]),                                                                                                                         // Address of Registers being read in ID stage
        .i_badOpcode(c_HALT), .i_IdOpcode(instruction_ID[6:0]), .i_badPC(c_badPC), .i_badDmem(c_badDmem), 
        .i_branch(c_Branch), .i_jalr(c_JALR), .flopped_rst2(flopped_rst3), .i_flush_ID(c_flush_ID), 
        .r1_Forwarding(r1_ForwardingSel), .r2_Forwarding(r2_ForwardingSel), .r1_ForwardValue(r1_ForwardValue), .r2_ForwardValue(r2_ForwardValue),
        .o_flush(c_flush), .o_enable(c_enable));


      /////////////////////////////////
     // EX/MEM: Register Pipeline 3 //
    /////////////////////////////////

    dff_1       iDFF_flush3(.clk(i_clk), .rst(i_rst), .d(c_flush_EX), .q(c_flush_MEM));

    // pipeline registers
    dff_32  iDFFinstr3(.clk(i_clk), .rst(i_rst), .d(instruction_EX), .q(instruction_MEM));
    dff_32  iDFFpc3(.clk(i_clk), .rst(i_rst), .d(pc_EX), .q(pc_MEM));
    dff_32  iDFFimm3(.clk(i_clk), .rst(i_rst), .d(immediate_EX), .q(immediate_MEM));
    // pc logic pipeline registers
    dff_32  iDFF_pc_add_imm3(.clk(i_clk), .rst(i_rst), .d(pc_add_imm_EX), .q(pc_add_imm_MEM));
    dff_32  iDFF_pc_add_4_3(.clk(i_clk), .rst(i_rst), .d(pcEX_add_4_EX), .q(pc_add_4_MEM));
    // control pipeline registers
    dff_1     iDFF_RegWrite3(.clk(i_clk), .rst(i_rst), .d(c_RegWrite_EX), .q(c_RegWrite_MEM));
    dff_1     iDFF_RegInPCSrc3(.clk(i_clk), .rst(i_rst), .d(c_RegInPCSrc_EX), .q(c_RegInPCSrc_MEM));
    dff_1     iDFF_RegInNon_Imm3(.clk(i_clk), .rst(i_rst), .d(c_RegInNon_Imm_EX), .q(c_RegInNon_Imm_MEM));
    dff_1     iDFF_MemToReg3(.clk(i_clk), .rst(i_rst), .d(c_MemToReg_EX), .q(c_MemToReg_MEM));
    dff_1     iDFF_MemWrite3(.clk(i_clk), .rst(i_rst), .d(c_MemWrite_EX), .q(c_MemWrite_MEM));
    dff_1     iDFF_MemRead3(.clk(i_clk), .rst(i_rst), .d(c_MemRead_EX), .q(c_MemRead_MEM));
    // ALU result pipeline register
    dff_32  iDFF_ALU_result3(.clk(i_clk), .rst(i_rst), .d(ALU_result_EX), .q(ALU_result_MEM));
    // data memory mask gen pipeline registers
    dff_32  iDFF_o_dmem_wdata3(.clk(i_clk), .rst(i_rst), .d(o_dmem_wdata_EX), .q(o_dmem_wdata_MEM));
    dff_4   iDFF_o_dmem_mask3(.clk(i_clk), .rst(i_rst), .d(o_dmem_mask_EX), .q(o_dmem_mask_MEM));
    // register file pipeline registers
    dff_32  iDFF_rf_rs1_rdata3(.clk(i_clk), .rst(i_rst), .d(rf_rs1_rdata_EX), .q(rf_rs1_rdata_MEM));
    dff_32  iDFF_rf_rs2_rdata3(.clk(i_clk), .rst(i_rst), .d(rf_rs2_rdata_EX), .q(rf_rs2_rdata_MEM));

      //////////////////////////
     // 4: MEM Memory Access //
    //////////////////////////


    // Data Memory
    assign o_dmem_addr = {ALU_result_MEM[31:2], 2'b0};
    assign o_dmem_wdata = o_dmem_wdata_MEM;
    assign o_dmem_mask = o_dmem_mask_MEM;
    assign o_dmem_ren = c_MemRead_MEM;
    assign o_dmem_wen = c_MemWrite_MEM;

      /////////////////////////////////
     // MEM/WB: Register Pipeline 4 //
    /////////////////////////////////

    // pipeline registers
    dff_32  iDFFinstr4(.clk(i_clk), .rst(i_rst), .d(instruction_MEM), .q(instruction_WB));
    dff_32  iDFFpc4(.clk(i_clk), .rst(i_rst), .d(pc_MEM), .q(pc_WB));
    dff_32  iDFFimm4(.clk(i_clk), .rst(i_rst), .d(immediate_MEM), .q(immediate_WB));
    // pc logic pipeline registers
    dff_32  iDFF_pc_add_imm4(.clk(i_clk), .rst(i_rst), .d(pc_add_imm_MEM), .q(pc_add_imm_WB));
    dff_32  iDFF_pc_add_4_4(.clk(i_clk), .rst(i_rst), .d(pc_add_4_MEM), .q(pc_add_4_WB));
    // control pipeline registers
    dff_1     iDFF_RegWrite4(.clk(i_clk), .rst(i_rst), .d(c_RegWrite_MEM), .q(c_RegWrite_WB));
    dff_1     iDFF_RegInPCSrc4(.clk(i_clk), .rst(i_rst), .d(c_RegInPCSrc_MEM), .q(c_RegInPCSrc_WB));
    dff_1     iDFF_RegInNon_Imm4(.clk(i_clk), .rst(i_rst), .d(c_RegInNon_Imm_MEM), .q(c_RegInNon_Imm_WB));
    dff_1     iDFF_MemToReg4(.clk(i_clk), .rst(i_rst), .d(c_MemToReg_MEM), .q(c_MemToReg_WB));
    // ALU result pipeline register
    dff_32  iDFF_ALU_result4(.clk(i_clk), .rst(i_rst), .d(ALU_result_MEM), .q(ALU_result_WB));
    // register file pipeline registers
    dff_32  iDFF_rf_rs1_rdata4(.clk(i_clk), .rst(i_rst), .d(rf_rs1_rdata_MEM), .q(rf_rs1_rdata_WB));
    dff_32  iDFF_rf_rs2_rdata4(.clk(i_clk), .rst(i_rst), .d(rf_rs2_rdata_MEM), .q(rf_rs2_rdata_WB));

      //////////////////////
     // 5: WB Write Back //
    //////////////////////
    

    // Data memory result processor (removes invalid values from masked read data)
    DMresult iDMresult(.i_funct3(instruction_WB[14:12]), .i_addr(ALU_result_WB[1:0]), .i_DMReadData(i_dmem_rdata),
        .o_regWriteData(rf_dmem_out));

    // Select between ALU and DM output
    mux2 i2MUXwb(.i_op1(ALU_result_WB), .i_op2(rf_dmem_out), .i_sel(c_MemToReg_WB), .o_result(rf_mux_dmem));

    // Mux on register file input
    mux4 i4MUXrf(.i_op1(immediate_WB), .i_op2(rf_mux_dmem), .i_op3(pc_add_imm_WB), .i_op4(pc_add_4_WB), .i_sel({c_RegInPCSrc_WB,c_RegInNon_Imm_WB}), .o_result(rf_write_data));


      ////////////////////////////////////
     // Testbench pass through signals //
    ////////////////////////////////////

    // The output `retire` interface is used to signal to the testbench that
    // the CPU has completed and retired an instruction. A single cycle
    // implementation will assert this every cycle; however, a pipelined
    // implementation that needs to stall (due to internal hazards or waiting
    // on memory accesses) will not assert the signal on cycles where the
    // instruction in the writeback stage is not retiring.
    //
    // Asserted when an instruction is being retired this cycle. If this is
    // not asserted, the other retire signals are ignored and may be left invalid.
    // We set the propagted instruction to 0 when stalling, so we're checking for that
    assign o_retire_valid = (~((instruction_WB == 32'b0))) & flopped_rst4;
    // The 32 bit instruction word of the instrution being retired. This
    // should be the unmodified instruction word fetched from instruction
    // memory.
    assign o_retire_inst [31:0] = instruction_WB[31:0];
    // Asserted if the instruction produced a trap, due to an illegal
    // instruction, unaligned data memory access, or unaligned instruction
    // address on a taken branch or jump.
    // Asserted if the instruction produced a trap, due to an illegal
    // instruction, unaligned data memory access, or unaligned instruction
    // address on a taken branch or jump.
    assign o_retire_trap = ((c_HALT & ~(c_Branch | c_JALR | c_flush_ID | c_flush_EX | c_flush_MEM)) | c_badDmem | c_badPC) & flopped_rst2 & ~(
      c_EBREAK | flopped_ebreak1 | flopped_ebreak2 | flopped_ebreak3 | flopped_ebreak4);
    
    // Asserted if the instruction is an `ebreak` instruction used to halt the
    // processor. This is used for debugging and testing purposes to end
    // a program.
    assign o_retire_halt = ((instruction_WB == 32'h00100073) | (o_retire_trap & ~c_EBREAK)) & flopped_rst2;

    // Extract the 7 bit opcode from the 32 bit instruction 
    wire [6:0] opcode = instruction_WB[6:0];
    
    // The first register address read by the instruction being retired. If
    // the instruction does not read from a register (like `lui`), this
    // should be 5'd0.
    assign o_retire_rs1_raddr [4:0] = (opcode == LUI |
                                      opcode == AUIPC |
                                      opcode == EBREAK) ?
                                      5'b0 : instruction_WB[19:15];
    // The second register address read by the instruction being retired. If
    // the instruction does not read from a second register (like `addi`), this
    // should be 5'd0.
    assign o_retire_rs2_raddr [4:0] = (opcode == I_ARITH |
                                      opcode == L_TYPE |
                                      opcode == JALR |
                                      opcode == JAL |
                                      opcode == LUI |
                                      opcode == AUIPC |
                                      opcode == EBREAK) ? 
                                      5'b0 : instruction_WB[24:20];
    // The first source register data read from the register file (in the
    // decode stage) for the instruction being retired. If rs1 is 5'd0, this
    // should also be 32'd0.
    assign o_retire_rs1_rdata [31:0] = rf_rs1_rdata_WB[31:0];
    // The second source register data read from the register file (in the
    // decode stage) for the instruction being retired. If rs2 is 5'd0, this
    // should also be 32'd0.
    assign o_retire_rs2_rdata [31:0] = rf_rs2_rdata_WB[31:0];
    // The destination register address written by the instruction being
    // retired. If the instruction does not write to a register (like `sw`),
    // this should be 5'd0.
    assign o_retire_rd_waddr [4:0]= (c_RegWrite_WB) ? instruction_WB[11:7] : 5'b0;
    // The destination register data written to the register file in the
    // writeback stage by this instruction. If rd is 5'd0, this field is
    // ignored and can be treated as a don't care.
    assign o_retire_rd_wdata [31:0] = rf_write_data[31:0];
    
    // The following data memory retire interface is used to record the
    // memory transactions completed by the instruction being retired.
    // As such, it mirrors the transactions happening on the main data
    // memory interface (o_dmem_* and i_dmem_*) but is delayed to match
    // the retirement of the instruction. You can hook this up by just
    // registering the main dmem interface signals into the writeback
    // stage of your pipeline.
    //
    // All these fields are don't-care for instructions that do not
    // access data memory (o_retire_dmem_ren and o_retire_dmem_wen
    // not asserted).
    // NOTE: This interface is new for phase 5 in order to account for
    // the delay between data memory accesses and instruction retire.
    //
    dff_32  iDFF_dmem_addr(.clk(i_clk), .rst(i_rst), .d({ALU_result_MEM[31:2], 2'b0}), .q(r_dmem_addr_WB));
    dff_4   iDFF_dmem_mask(.clk(i_clk), .rst(i_rst), .d(o_dmem_mask_MEM), .q(r_dmem_mask_WB));
    dff_1     iDFF_dmem_ren(.clk(i_clk), .rst(i_rst), .d(c_MemRead_MEM), .q(r_dmem_ren_WB));
    dff_1     iDFF_dmem_wen(.clk(i_clk), .rst(i_rst), .d(c_MemWrite_MEM), .q(r_dmem_wen_WB));
    // dmem read data has dedicated register pipeline above
    dff_32  iDFF_dmem_wdata(.clk(i_clk), .rst(i_rst), .d(o_dmem_wdata_MEM), .q(r_dmem_wdata_WB));

    // The 32-bit data memory address accessed by the instruction.
    assign o_retire_dmem_addr [31:0]  = r_dmem_addr_WB;
    // The byte masked used for the data memory access.
    assign o_retire_dmem_mask [ 3:0]  = r_dmem_mask_WB;
    // Asserted if the instruction performed a read (load) from data memory.
    assign o_retire_dmem_ren          = r_dmem_ren_WB;
    // Asserted if the instruction performed a write (store) to data memory.
    assign o_retire_dmem_wen          = r_dmem_wen_WB;
    // The 32-bit data read from memory by a load instruction.
    assign o_retire_dmem_rdata [31:0] = i_dmem_rdata;
    // The 32-bit data written to memory by a store instruction.
    assign o_retire_dmem_wdata [31:0] = r_dmem_wdata_WB;

    // The current program counter of the instruction being retired - i.e.
    // the instruction memory address that the instruction was fetched from.
    assign o_retire_pc [31:0] = pc_WB;
    // the next program counter after the instruction is retired. For most
    // instructions, this is `o_retire_pc + 4`, but must be the branch or jump
    // target for *taken* branches and jumps.
    assign o_retire_next_pc [31:0] = (c_Branch | c_JALR) ? pc_in[31:0] : pc_EX[31:0];

endmodule

`default_nettype wire
