// Functional Unit Status Table
// Tracks status of each functional unit for scoreboarding

`timescale 1ns/1ps

module fu_status #(
    parameter NUM_FUS = 4,
    parameter NUM_REGS = 32,
    parameter REG_BITS = 5,
    parameter FU_BITS = 2
)(
    input  wire        clk,
    input  wire        rst_n,
    
    // Issue interface
    input  wire        issue_grant,           // Issue granted
    input  wire [FU_BITS-1:0] issue_fu,       // Which FU to issue to
    input  wire [2:0]  issue_op,              // Operation
    input  wire [REG_BITS-1:0] issue_fi,      // Destination register
    input  wire [REG_BITS-1:0] issue_fj,      // Source register 1
    input  wire [REG_BITS-1:0] issue_fk,      // Source register 2
    
    // Read operand interface
    input  wire [NUM_FUS-1:0] read_grant,
    
    // Write result interface
    input  wire [NUM_FUS-1:0] write_grant,
    
    // Status outputs
    output wire [NUM_FUS-1:0] busy,
    output wire [NUM_FUS-1:0] rj,              // Source 1 ready
    output wire [NUM_FUS-1:0] rk,              // Source 2 ready
    
    // Register result status (which FU will write each register)
    output wire [NUM_REGS*NUM_FUS-1:0] reg_result_fu
);

    // FU status registers
    reg [NUM_FUS-1:0] busy_reg;
    reg [2:0] op_reg [0:NUM_FUS-1];
    reg [REG_BITS-1:0] fi_reg [0:NUM_FUS-1];
    reg [REG_BITS-1:0] fj_reg [0:NUM_FUS-1];
    reg [REG_BITS-1:0] fk_reg [0:NUM_FUS-1];
    reg [NUM_FUS-1:0] qj_reg [0:NUM_FUS-1];  // Which FU for Fj
    reg [NUM_FUS-1:0] qk_reg [0:NUM_FUS-1];  // Which FU for Fk
    reg [NUM_FUS-1:0] rj_reg;  // Source 1 ready
    reg [NUM_FUS-1:0] rk_reg;  // Source 2 ready
    
    // Register result status
    reg [NUM_FUS-1:0] result_fu [0:NUM_REGS-1];
    
    // Outputs
    assign busy = busy_reg;
    assign rj = rj_reg;
    assign rk = rk_reg;
    
    // Pack register result status
    genvar g;
    generate
        for (g = 0; g < NUM_REGS; g = g + 1) begin : gen_result
            assign reg_result_fu[g*NUM_FUS +: NUM_FUS] = result_fu[g];
        end
    endgenerate
    
    // Sequential logic
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy_reg <= 0;
            rj_reg <= 0;
            rk_reg <= 0;
            for (i = 0; i < NUM_FUS; i = i + 1) begin
                op_reg[i] <= 0;
                fi_reg[i] <= 0;
                fj_reg[i] <= 0;
                fk_reg[i] <= 0;
                qj_reg[i] <= 0;
                qk_reg[i] <= 0;
            end
            for (i = 0; i < NUM_REGS; i = i + 1) begin
                result_fu[i] <= 0;
            end
        end else begin
            // Handle issue
            if (issue_grant) begin
                busy_reg[issue_fu] <= 1'b1;
                op_reg[issue_fu] <= issue_op;
                fi_reg[issue_fu] <= issue_fi;
                fj_reg[issue_fu] <= issue_fj;
                fk_reg[issue_fu] <= issue_fk;
                
                // Check if sources are being produced by another FU
                qj_reg[issue_fu] <= result_fu[issue_fj];
                qk_reg[issue_fu] <= result_fu[issue_fk];
                
                // Source ready if no FU is producing it
                rj_reg[issue_fu] <= (result_fu[issue_fj] == 0) || (issue_fj == 0);
                rk_reg[issue_fu] <= (result_fu[issue_fk] == 0) || (issue_fk == 0);
                
                // Mark destination register as being produced by this FU
                if (issue_fi != 0) begin
                    result_fu[issue_fi] <= (1 << issue_fu);
                end
            end
            
            // Handle read operands complete
            for (i = 0; i < NUM_FUS; i = i + 1) begin
                if (read_grant[i]) begin
                    // Operands have been read, clear ready flags
                    rj_reg[i] <= 1'b0;
                    rk_reg[i] <= 1'b0;
                end
            end
            
            // Handle write (completion) - update waiting FUs
            for (i = 0; i < NUM_FUS; i = i + 1) begin
                if (write_grant[i]) begin
                    busy_reg[i] <= 1'b0;
                    
                    // Clear result_fu for destination
                    if (fi_reg[i] != 0) begin
                        result_fu[fi_reg[i]] <= 0;
                    end
                    
                    // Update Rj/Rk for waiting FUs
                    begin : update_waiting
                        integer j;
                        for (j = 0; j < NUM_FUS; j = j + 1) begin
                            if (qj_reg[j][i]) begin
                                rj_reg[j] <= 1'b1;
                                qj_reg[j] <= 0;
                            end
                            if (qk_reg[j][i]) begin
                                rk_reg[j] <= 1'b1;
                                qk_reg[j] <= 0;
                            end
                        end
                    end
                end
            end
        end
    end

endmodule
