`timescale 1ns/1ps

// Interrupt Controller
// Vectored interrupt controller with priority encoding

module interrupt_controller #(
    parameter NUM_INTERRUPTS = 16,
    parameter VECTOR_WIDTH = 8
)(
    input  wire        clk,
    input  wire        rst_n,
    
    // Interrupt inputs
    input  wire [NUM_INTERRUPTS-1:0] irq_lines,
    
    // CPU interface
    input  wire        irq_ack,          // CPU acknowledges interrupt
    input  wire [3:0]  irq_ack_num,      // Which interrupt to acknowledge
    output wire        irq_pending,       // Interrupt pending
    output wire [3:0]  irq_num,          // Highest priority interrupt number
    output wire [VECTOR_WIDTH-1:0] irq_vector, // Interrupt vector address
    
    // Configuration
    input  wire [NUM_INTERRUPTS-1:0] irq_enable,  // Per-interrupt enable
    input  wire [NUM_INTERRUPTS-1:0] irq_edge,    // 1=edge, 0=level triggered
    input  wire [3:0]  irq_priority [0:NUM_INTERRUPTS-1], // Priority per IRQ
    input  wire [VECTOR_WIDTH-1:0] vector_base,  // Base vector address
    
    // Status
    output wire [NUM_INTERRUPTS-1:0] irq_status,
    output wire [NUM_INTERRUPTS-1:0] irq_pending_mask
);

    // Edge detection
    reg [NUM_INTERRUPTS-1:0] irq_prev;
    wire [NUM_INTERRUPTS-1:0] irq_edge_detected;
    
    // Pending interrupt register
    reg [NUM_INTERRUPTS-1:0] pending_reg;
    
    // In-service register (currently being handled)
    reg [NUM_INTERRUPTS-1:0] in_service;
    
    // Edge detection
    assign irq_edge_detected = irq_lines & ~irq_prev;
    
    // Effective interrupt (edge or level based)
    wire [NUM_INTERRUPTS-1:0] irq_effective;
    genvar g;
    generate
        for (g = 0; g < NUM_INTERRUPTS; g = g + 1) begin : gen_effective
            assign irq_effective[g] = irq_edge[g] ? 
                                      (irq_edge_detected[g] | pending_reg[g]) : 
                                      irq_lines[g];
        end
    endgenerate
    
    // Enabled and pending interrupts
    wire [NUM_INTERRUPTS-1:0] irq_active = irq_effective & irq_enable & ~in_service;
    
    // Priority encoder - find highest priority interrupt
    reg [3:0] highest_priority_num;
    reg [3:0] highest_priority_val;
    reg found_interrupt;
    
    integer i;
    always @(*) begin
        highest_priority_num = 0;
        highest_priority_val = 4'hF; // Lowest priority
        found_interrupt = 0;
        
        for (i = 0; i < NUM_INTERRUPTS; i = i + 1) begin
            if (irq_active[i] && irq_priority[i] < highest_priority_val) begin
                highest_priority_val = irq_priority[i];
                highest_priority_num = i[3:0];
                found_interrupt = 1;
            end
        end
    end
    
    // Outputs
    assign irq_pending = found_interrupt;
    assign irq_num = highest_priority_num;
    assign irq_vector = vector_base + {4'b0, highest_priority_num};
    assign irq_status = irq_lines;
    assign irq_pending_mask = pending_reg;
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            irq_prev <= 0;
            pending_reg <= 0;
            in_service <= 0;
        end else begin
            // Edge detection history
            irq_prev <= irq_lines;
            
            // Set pending on edge detection (for edge-triggered)
            for (i = 0; i < NUM_INTERRUPTS; i = i + 1) begin
                if (irq_edge[i] && irq_edge_detected[i] && irq_enable[i]) begin
                    pending_reg[i] <= 1'b1;
                end
            end
            
            // Handle acknowledgment
            if (irq_ack) begin
                // Move to in-service
                in_service[irq_ack_num] <= 1'b1;
                // Clear pending
                pending_reg[irq_ack_num] <= 1'b0;
            end
        end
    end
    
    // End of interrupt (EOI) - would be handled by software write
    // For simplicity, auto-clear in_service after some cycles
    // In real implementation, software sends EOI command

endmodule
