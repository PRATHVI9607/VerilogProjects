`timescale 1ns/1ps

// Hazard Detection Unit
// Detects load-use hazards and generates stall signals

module hazard_unit (
    // From ID stage
    input  wire [4:0] if_id_rs1,
    input  wire [4:0] if_id_rs2,
    
    // From ID/EX stage (for load-use hazard detection)
    input  wire [4:0] id_ex_rd,
    input  wire       id_ex_mem_read,
    input  wire       id_ex_valid,
    
    // Control outputs
    output wire       stall_if,
    output wire       stall_id,
    output wire       flush_ex
);

    // Load-use hazard detection
    // Stall pipeline if a load instruction is followed by an instruction
    // that uses the loaded value
    wire load_use_hazard;
    
    assign load_use_hazard = id_ex_mem_read && id_ex_valid && (id_ex_rd != 5'b0) &&
                            ((id_ex_rd == if_id_rs1) || (id_ex_rd == if_id_rs2));
    
    // Stall IF and ID stages, insert bubble in EX
    assign stall_if = load_use_hazard;
    assign stall_id = load_use_hazard;
    assign flush_ex = load_use_hazard;

endmodule
