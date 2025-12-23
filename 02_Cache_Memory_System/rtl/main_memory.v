`timescale 1ns/1ps

// Main Memory Simulator
// Simulates slow main memory for cache testing

module main_memory (
    input  wire        clk,
    input  wire        rst_n,
    
    input  wire [31:0] addr,
    input  wire [255:0] wdata,
    input  wire        read,
    input  wire        write,
    output reg  [255:0] rdata,
    output reg         ready
);

    // Memory latency (cycles)
    parameter LATENCY = 10;
    
    // Memory storage - 4KB
    reg [7:0] mem [0:4095];
    
    // Latency counter
    reg [3:0] counter;
    reg       pending;
    reg       is_read;
    reg [31:0] pending_addr;
    reg [255:0] pending_wdata;
    
    // Initialize memory with pattern
    integer i;
    initial begin
        for (i = 0; i < 4096; i = i + 1) begin
            mem[i] = i[7:0];
        end
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter <= 0;
            pending <= 1'b0;
            ready <= 1'b0;
            rdata <= 256'b0;
            is_read <= 1'b0;
            pending_addr <= 32'b0;
            pending_wdata <= 256'b0;
        end else begin
            ready <= 1'b0;
            
            if (!pending && (read || write)) begin
                // Start new transaction
                pending <= 1'b1;
                counter <= LATENCY - 1;
                is_read <= read;
                pending_addr <= addr;
                pending_wdata <= wdata;
            end else if (pending) begin
                if (counter == 0) begin
                    // Complete transaction
                    pending <= 1'b0;
                    ready <= 1'b1;
                    
                    if (is_read) begin
                        // Read 32 bytes
                        rdata <= {
                            mem[pending_addr[11:0] + 31], mem[pending_addr[11:0] + 30],
                            mem[pending_addr[11:0] + 29], mem[pending_addr[11:0] + 28],
                            mem[pending_addr[11:0] + 27], mem[pending_addr[11:0] + 26],
                            mem[pending_addr[11:0] + 25], mem[pending_addr[11:0] + 24],
                            mem[pending_addr[11:0] + 23], mem[pending_addr[11:0] + 22],
                            mem[pending_addr[11:0] + 21], mem[pending_addr[11:0] + 20],
                            mem[pending_addr[11:0] + 19], mem[pending_addr[11:0] + 18],
                            mem[pending_addr[11:0] + 17], mem[pending_addr[11:0] + 16],
                            mem[pending_addr[11:0] + 15], mem[pending_addr[11:0] + 14],
                            mem[pending_addr[11:0] + 13], mem[pending_addr[11:0] + 12],
                            mem[pending_addr[11:0] + 11], mem[pending_addr[11:0] + 10],
                            mem[pending_addr[11:0] + 9],  mem[pending_addr[11:0] + 8],
                            mem[pending_addr[11:0] + 7],  mem[pending_addr[11:0] + 6],
                            mem[pending_addr[11:0] + 5],  mem[pending_addr[11:0] + 4],
                            mem[pending_addr[11:0] + 3],  mem[pending_addr[11:0] + 2],
                            mem[pending_addr[11:0] + 1],  mem[pending_addr[11:0] + 0]
                        };
                    end else begin
                        // Write 32 bytes
                        {mem[pending_addr[11:0] + 31], mem[pending_addr[11:0] + 30],
                         mem[pending_addr[11:0] + 29], mem[pending_addr[11:0] + 28],
                         mem[pending_addr[11:0] + 27], mem[pending_addr[11:0] + 26],
                         mem[pending_addr[11:0] + 25], mem[pending_addr[11:0] + 24],
                         mem[pending_addr[11:0] + 23], mem[pending_addr[11:0] + 22],
                         mem[pending_addr[11:0] + 21], mem[pending_addr[11:0] + 20],
                         mem[pending_addr[11:0] + 19], mem[pending_addr[11:0] + 18],
                         mem[pending_addr[11:0] + 17], mem[pending_addr[11:0] + 16],
                         mem[pending_addr[11:0] + 15], mem[pending_addr[11:0] + 14],
                         mem[pending_addr[11:0] + 13], mem[pending_addr[11:0] + 12],
                         mem[pending_addr[11:0] + 11], mem[pending_addr[11:0] + 10],
                         mem[pending_addr[11:0] + 9],  mem[pending_addr[11:0] + 8],
                         mem[pending_addr[11:0] + 7],  mem[pending_addr[11:0] + 6],
                         mem[pending_addr[11:0] + 5],  mem[pending_addr[11:0] + 4],
                         mem[pending_addr[11:0] + 3],  mem[pending_addr[11:0] + 2],
                         mem[pending_addr[11:0] + 1],  mem[pending_addr[11:0] + 0]} <= pending_wdata;
                    end
                end else begin
                    counter <= counter - 1;
                end
            end
        end
    end

endmodule
