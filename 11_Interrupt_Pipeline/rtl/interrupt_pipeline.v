`timescale 1ns/1ps

// Interrupt-Enabled Pipeline - Top Module
// 5-stage pipeline with interrupt and exception handling

module interrupt_pipeline #(
    parameter XLEN = 32,
    parameter NUM_IRQS = 16
)(
    input  wire        clk,
    input  wire        rst_n,
    
    // Instruction memory interface
    output wire [XLEN-1:0] imem_addr,
    output wire        imem_req,
    input  wire [XLEN-1:0] imem_rdata,
    input  wire        imem_ready,
    
    // Data memory interface
    output wire [XLEN-1:0] dmem_addr,
    output wire        dmem_read,
    output wire        dmem_write,
    output wire [XLEN-1:0] dmem_wdata,
    input  wire [XLEN-1:0] dmem_rdata,
    input  wire        dmem_ready,
    
    // Interrupt inputs
    input  wire [NUM_IRQS-1:0] irq_lines,
    input  wire        timer_irq,
    input  wire        sw_irq,
    
    // Status
    output wire [1:0]  priv_mode,
    output wire [XLEN-1:0] pc_out,
    output wire        halted
);

    // Pipeline registers
    // IF/ID
    reg [XLEN-1:0] if_id_pc;
    reg [XLEN-1:0] if_id_instr;
    reg if_id_valid;
    
    // ID/EX
    reg [XLEN-1:0] id_ex_pc;
    reg [XLEN-1:0] id_ex_rs1_data;
    reg [XLEN-1:0] id_ex_rs2_data;
    reg [XLEN-1:0] id_ex_imm;
    reg [4:0] id_ex_rd;
    reg [4:0] id_ex_rs1, id_ex_rs2;
    reg [3:0] id_ex_alu_op;
    reg id_ex_mem_read, id_ex_mem_write;
    reg id_ex_reg_write;
    reg id_ex_valid;
    
    // EX/MEM
    reg [XLEN-1:0] ex_mem_pc;
    reg [XLEN-1:0] ex_mem_alu_result;
    reg [XLEN-1:0] ex_mem_rs2_data;
    reg [4:0] ex_mem_rd;
    reg ex_mem_mem_read, ex_mem_mem_write;
    reg ex_mem_reg_write;
    reg ex_mem_valid;
    
    // MEM/WB
    reg [XLEN-1:0] mem_wb_pc;
    reg [XLEN-1:0] mem_wb_result;
    reg [4:0] mem_wb_rd;
    reg mem_wb_reg_write;
    reg mem_wb_valid;
    
    // Register file
    reg [XLEN-1:0] regfile [0:31];
    
    // CSRs (simplified)
    reg [XLEN-1:0] mstatus;    // Machine status
    reg [XLEN-1:0] mie;        // Machine interrupt enable
    reg [XLEN-1:0] mip;        // Machine interrupt pending
    reg [XLEN-1:0] mtvec;      // Machine trap vector
    reg [XLEN-1:0] mepc;       // Machine exception PC
    reg [XLEN-1:0] mcause;     // Machine cause
    reg [XLEN-1:0] mtval;      // Machine trap value
    reg [XLEN-1:0] medeleg;    // Machine exception delegation
    reg [XLEN-1:0] mideleg;    // Machine interrupt delegation
    reg [XLEN-1:0] stvec;      // Supervisor trap vector
    reg [1:0] priv_mode_reg;   // Current privilege mode
    
    // Program counter
    reg [XLEN-1:0] pc;
    
    // Control signals
    wire stall;
    wire [XLEN-1:0] next_pc;
    
    // Interrupt controller signals
    wire irq_pending;
    wire [3:0] irq_num;
    wire [7:0] irq_vector;
    wire irq_ack;
    
    // Exception signals
    wire exc_illegal;
    wire exc_ecall;
    wire exc_ebreak;
    wire exception_valid;
    wire [XLEN-1:0] exception_cause;
    wire [XLEN-1:0] exception_tval;
    wire [XLEN-1:0] exception_pc;
    wire [XLEN-1:0] trap_vector;
    
    // Flush signals
    wire flush_if, flush_id, flush_ex, flush_mem;
    wire pc_redirect;
    wire [XLEN-1:0] redirect_pc;
    wire pipeline_flush_busy;
    wire [XLEN-1:0] mepc_save;
    wire irq_taken, exc_taken;
    
    // Global interrupt enable from mstatus
    wire mie_bit = mstatus[3];  // MIE bit
    wire interrupt_enable = mie_bit && (priv_mode_reg < 2'b11 || mstatus[3]);
    
    // Default interrupt priorities (lower number = higher priority)
    wire [3:0] default_irq_priority [0:NUM_IRQS-1];
    genvar gp;
    generate
        for (gp = 0; gp < NUM_IRQS; gp = gp + 1) begin : gen_priority
            assign default_irq_priority[gp] = gp[3:0];
        end
    endgenerate
    
    // Interrupt controller
    interrupt_controller #(
        .NUM_INTERRUPTS(NUM_IRQS)
    ) u_irq_ctrl (
        .clk(clk),
        .rst_n(rst_n),
        .irq_lines(irq_lines),
        .irq_ack(irq_ack),
        .irq_ack_num(irq_num),
        .irq_pending(irq_pending),
        .irq_num(irq_num),
        .irq_vector(irq_vector),
        .irq_enable(mie[NUM_IRQS-1:0]),
        .irq_edge({NUM_IRQS{1'b0}}),  // All level-triggered
        .irq_priority(default_irq_priority),
        .vector_base(mtvec[7:0]),
        .irq_status(),
        .irq_pending_mask()
    );
    
    // Exception handler
    exception_handler #(
        .XLEN(XLEN)
    ) u_exc_handler (
        .clk(clk),
        .rst_n(rst_n),
        .exc_illegal_instr(exc_illegal),
        .exc_misaligned_fetch(1'b0),
        .exc_misaligned_load(1'b0),
        .exc_misaligned_store(1'b0),
        .exc_ecall(exc_ecall),
        .exc_ebreak(exc_ebreak),
        .exc_page_fault_fetch(1'b0),
        .exc_page_fault_load(1'b0),
        .exc_page_fault_store(1'b0),
        .exc_pc(id_ex_pc),
        .exc_instr(if_id_instr),
        .exc_addr(ex_mem_alu_result),
        .priv_mode(priv_mode_reg),
        .exception_valid(exception_valid),
        .exception_cause(exception_cause),
        .exception_tval(exception_tval),
        .exception_pc(exception_pc),
        .target_priv(),
        .mtvec(mtvec),
        .stvec(stvec),
        .medeleg(medeleg),
        .trap_vector(trap_vector)
    );
    
    // Pipeline flush controller
    pipeline_flush_ctrl #(
        .XLEN(XLEN)
    ) u_flush_ctrl (
        .clk(clk),
        .rst_n(rst_n),
        .interrupt_pending(irq_pending),
        .interrupt_vector({24'b0, irq_vector}),
        .exception_valid(exception_valid),
        .exception_vector(trap_vector),
        .if_pc(pc),
        .id_pc(if_id_pc),
        .ex_pc(id_ex_pc),
        .mem_pc(ex_mem_pc),
        .wb_pc(mem_wb_pc),
        .if_valid(1'b1),
        .id_valid(if_id_valid),
        .ex_valid(id_ex_valid),
        .mem_valid(ex_mem_valid),
        .wb_valid(mem_wb_valid),
        .interrupt_enable(interrupt_enable),
        .pipeline_stall(stall),
        .flush_if(flush_if),
        .flush_id(flush_id),
        .flush_ex(flush_ex),
        .flush_mem(flush_mem),
        .flush_wb(),
        .flush_all(),
        .pc_redirect(pc_redirect),
        .redirect_pc(redirect_pc),
        .pipeline_flush_busy(pipeline_flush_busy),
        .mepc_out(mepc_save),
        .irq_taken(irq_taken),
        .exc_taken(exc_taken)
    );
    
    // Instruction decode (simplified)
    wire [6:0] opcode = if_id_instr[6:0];
    wire [4:0] rd = if_id_instr[11:7];
    wire [2:0] funct3 = if_id_instr[14:12];
    wire [4:0] rs1 = if_id_instr[19:15];
    wire [4:0] rs2 = if_id_instr[24:20];
    wire [6:0] funct7 = if_id_instr[31:25];
    
    // Exception detection
    assign exc_illegal = if_id_valid && (opcode == 7'b0000000);  // Simplified
    assign exc_ecall = if_id_valid && (opcode == 7'b1110011) && (if_id_instr[31:20] == 12'h000);
    assign exc_ebreak = if_id_valid && (opcode == 7'b1110011) && (if_id_instr[31:20] == 12'h001);
    
    // Memory stall
    assign stall = (id_ex_mem_read || id_ex_mem_write) && !dmem_ready;
    
    // PC logic
    assign next_pc = pc_redirect ? redirect_pc :
                     stall ? pc :
                     pc + 4;
    
    // Outputs
    assign imem_addr = pc;
    assign imem_req = !stall && !pipeline_flush_busy;
    assign dmem_addr = ex_mem_alu_result;
    assign dmem_read = ex_mem_mem_read;
    assign dmem_write = ex_mem_mem_write;
    assign dmem_wdata = ex_mem_rs2_data;
    assign priv_mode = priv_mode_reg;
    assign pc_out = pc;
    assign halted = 1'b0;
    
    assign irq_ack = irq_taken;
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset state
            pc <= 32'h80000000;  // Reset vector
            priv_mode_reg <= 2'b11;  // Machine mode
            mstatus <= 32'h00001800;  // MPP=11
            mie <= 0;
            mip <= 0;
            mtvec <= 32'h80000004;
            mepc <= 0;
            mcause <= 0;
            mtval <= 0;
            medeleg <= 0;
            mideleg <= 0;
            stvec <= 0;
            
            // Pipeline registers
            if_id_valid <= 0;
            id_ex_valid <= 0;
            ex_mem_valid <= 0;
            mem_wb_valid <= 0;
            
            // Register file
            begin : reset_regs
                integer i;
                for (i = 0; i < 32; i = i + 1) begin
                    regfile[i] <= 0;
                end
            end
        end else begin
            // PC update
            pc <= next_pc;
            
            // IF/ID stage
            if (flush_if) begin
                if_id_valid <= 0;
            end else if (!stall) begin
                if_id_pc <= pc;
                if_id_instr <= imem_rdata;
                if_id_valid <= imem_ready;
            end
            
            // ID/EX stage
            if (flush_id) begin
                id_ex_valid <= 0;
            end else if (!stall) begin
                id_ex_pc <= if_id_pc;
                id_ex_rs1_data <= regfile[rs1];
                id_ex_rs2_data <= regfile[rs2];
                id_ex_rd <= rd;
                id_ex_rs1 <= rs1;
                id_ex_rs2 <= rs2;
                id_ex_valid <= if_id_valid;
                // Simplified decode
                id_ex_mem_read <= (opcode == 7'b0000011);
                id_ex_mem_write <= (opcode == 7'b0100011);
                id_ex_reg_write <= (opcode == 7'b0110011) || (opcode == 7'b0010011) || (opcode == 7'b0000011);
            end
            
            // EX/MEM stage
            if (flush_ex) begin
                ex_mem_valid <= 0;
            end else if (!stall) begin
                ex_mem_pc <= id_ex_pc;
                ex_mem_alu_result <= id_ex_rs1_data + id_ex_rs2_data;  // Simplified ALU
                ex_mem_rs2_data <= id_ex_rs2_data;
                ex_mem_rd <= id_ex_rd;
                ex_mem_mem_read <= id_ex_mem_read;
                ex_mem_mem_write <= id_ex_mem_write;
                ex_mem_reg_write <= id_ex_reg_write;
                ex_mem_valid <= id_ex_valid;
            end
            
            // MEM/WB stage
            if (flush_mem) begin
                mem_wb_valid <= 0;
            end else begin
                mem_wb_pc <= ex_mem_pc;
                mem_wb_result <= ex_mem_mem_read ? dmem_rdata : ex_mem_alu_result;
                mem_wb_rd <= ex_mem_rd;
                mem_wb_reg_write <= ex_mem_reg_write;
                mem_wb_valid <= ex_mem_valid;
            end
            
            // Writeback
            if (mem_wb_valid && mem_wb_reg_write && mem_wb_rd != 0) begin
                regfile[mem_wb_rd] <= mem_wb_result;
            end
            
            // CSR updates on trap
            if (irq_taken || exc_taken) begin
                mepc <= mepc_save;
                mcause <= irq_taken ? {1'b1, 31'd0} | {28'b0, irq_num} : exception_cause;
                mtval <= exception_tval;
                // Save and update mstatus
                mstatus[7] <= mstatus[3];  // MPIE <= MIE
                mstatus[3] <= 1'b0;        // MIE <= 0
                mstatus[12:11] <= priv_mode_reg;  // MPP <= current privilege
                priv_mode_reg <= 2'b11;    // Go to machine mode
            end
        end
    end

endmodule
