`timescale 1ns/1ps

// TLB Entry
// Single TLB entry with tag matching

module tlb_entry #(
    parameter VPN_WIDTH = 20,
    parameter PPN_WIDTH = 20,
    parameter ASID_WIDTH = 8
)(
    input  wire        clk,
    input  wire        rst_n,
    
    // Lookup interface
    input  wire [VPN_WIDTH-1:0]  lookup_vpn,
    input  wire [ASID_WIDTH-1:0] lookup_asid,
    input  wire        lookup_valid,
    output wire        hit,
    output wire [PPN_WIDTH-1:0] ppn_out,
    output wire [3:0]  flags_out,  // RWXU bits
    
    // Write interface
    input  wire        write_en,
    input  wire [VPN_WIDTH-1:0]  write_vpn,
    input  wire [PPN_WIDTH-1:0]  write_ppn,
    input  wire [ASID_WIDTH-1:0] write_asid,
    input  wire [3:0]  write_flags,
    input  wire        write_global,
    
    // Invalidate
    input  wire        invalidate,
    input  wire        invalidate_all,
    input  wire [VPN_WIDTH-1:0]  invalidate_vpn,
    input  wire [ASID_WIDTH-1:0] invalidate_asid,
    
    // Status
    output wire        valid_out
);

    // Entry storage
    reg        valid;
    reg        global_bit;
    reg [VPN_WIDTH-1:0]  vpn;
    reg [PPN_WIDTH-1:0]  ppn;
    reg [ASID_WIDTH-1:0] asid;
    reg [3:0]  flags;  // R, W, X, U
    
    // Tag match (global entries match any ASID)
    wire asid_match = global_bit || (asid == lookup_asid);
    wire vpn_match = (vpn == lookup_vpn);
    
    assign hit = valid && vpn_match && asid_match && lookup_valid;
    assign ppn_out = ppn;
    assign flags_out = flags;
    assign valid_out = valid;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid <= 1'b0;
            global_bit <= 1'b0;
            vpn <= 0;
            ppn <= 0;
            asid <= 0;
            flags <= 4'b0;
        end else begin
            // Invalidate
            if (invalidate_all) begin
                valid <= 1'b0;
            end else if (invalidate && valid) begin
                if ((vpn == invalidate_vpn) && 
                    (global_bit || (asid == invalidate_asid))) begin
                    valid <= 1'b0;
                end
            end
            // Write new entry
            else if (write_en) begin
                valid <= 1'b1;
                vpn <= write_vpn;
                ppn <= write_ppn;
                asid <= write_asid;
                flags <= write_flags;
                global_bit <= write_global;
            end
        end
    end

endmodule
