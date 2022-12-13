module map (
    input               CLK,
    CLK_NIOS,
    input               MAP_WRITE_ENABLE,
    input        [ 7:0] MAP_WRITE_DATA,
    input        [ 7:0] MAP_WRITE_ADDR,
    input        [15:0] MAP_COORD,
    output logic [ 6:0] MAP_INDEX
);
    logic [7:0] MAP_BLOCK;
    logic [7:0] MAP_INDEX_0;
    assign MAP_BLOCK = (MAP_COORD[15:8] / 16) * 16 + (MAP_COORD[7:0] / 16);

    always_comb begin
        MAP_INDEX = MAP_INDEX_0[6:0];
    end

    map_ram #(
        .DATA_WIDTH(8),
        .ADDR_WIDTH(8)
    ) u_map_rom (
        .clk_a     (CLK_NIOS),
        .clk_b     (CLK),
        .addr_read (MAP_BLOCK),
        .addr_write(MAP_WRITE_ADDR),
        .data_write(MAP_WRITE_DATA),
        .we_write  (MAP_WRITE_ENABLE),
        .q_read    (MAP_INDEX_0)
    );
endmodule

// Quartus Prime Verilog Template
// True Dual Port RAM with single clock
module map_ram #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 8
) (
    input      [(DATA_WIDTH-1):0] data_write,
    input      [(ADDR_WIDTH-1):0] addr_write,
    addr_read,
    input                         we_write,
    clk_a,
    clk_b,
    output reg [(DATA_WIDTH-1):0] q_read
);

    // Declare the RAM variable
    reg [DATA_WIDTH-1:0] ram[2**ADDR_WIDTH-1:0];

    initial begin
        $readmemh("E:/Mirror/ZJUI/2022FA/ECE385/Final_Project/FinalProject/test.hex", ram, 0, 255);
    end

    // Port A
    always @(posedge clk_a) begin
        if (we_write) begin
            ram[addr_write] <= data_write;
        end
    end

    // Port B
    always @(posedge clk_b) begin
        q_read <= ram[addr_read];
    end

endmodule

// // Quartus Prime Verilog Template
// // Single Port ROM

// module map_rom #(
//     parameter DATA_WIDTH = 8,
//     parameter ADDR_WIDTH = 8
// ) (
//     input      [(ADDR_WIDTH-1):0] addr,
//     input                         clk,
//     output reg [(DATA_WIDTH-1):0] q
// );

//     // Declare the ROM variable
//     reg     [DATA_WIDTH-1:0] rom[2**ADDR_WIDTH-1:0];

//     // Initialize the ROM with $readmemb.  Put the memory contents
//     // in the file single_port_rom_init.txt.  Without this file,
//     // this design will not compile.

//     // See Verilog LRM 1364-2001 Section 17.2.8 for details on the
//     // format of this file, or see the "Using $readmemb and $readmemh"
//     // template later in this section.

//     integer                  i;
//     initial begin
//         // for (i = 0; i < 256; i = i + 1) rom[i] = 8'b00000001;
//         // $readmemh("E:/Mirror/ZJUI/2022FA/ECE385/Final_Project/FinalProject/map.hex", rom, 0, 255);
//         $readmemh("E:/Mirror/ZJUI/2022FA/ECE385/Final_Project/FinalProject/test.hex", rom, 0, 255);
//         // $readmemh("map.hex", rom, 0, 255);
//     end

//     initial begin
//         $display("data:");
//         for (i = 0; i < 100; i = i + 1) $display("%d:%h", i, rom[i]);
//     end

//     always @(posedge clk) begin
//         q <= rom[addr];
//     end

// endmodule



