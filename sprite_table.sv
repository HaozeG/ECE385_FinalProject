module sprite_table (
    input               CLK,
    input  logic [12:0] SPRITE_ADDR,
    output logic [ 3:0] SPRITE_DATA
);
    // ADDR顺序: 先SPRITE内部，再SPRITE间

    sprite_rom u_sprite_rom (
        .addr(SPRITE_ADDR),
        .clk (CLK),
        .q   (SPRITE_DATA)
    );

endmodule

// Quartus Prime Verilog Template
// Single Port ROM

module sprite_rom #(
    parameter DATA_WIDTH = 4,
    parameter ADDR_WIDTH = 13
) (
    input      [(ADDR_WIDTH-1):0] addr,
    input                         clk,
    output reg [(DATA_WIDTH-1):0] q
);

    // Declare the ROM variable
    reg [DATA_WIDTH-1:0] rom[2**ADDR_WIDTH-1:0];

    // Initialize the ROM with $readmemb.  Put the memory contents
    // in the file single_port_rom_init.txt.  Without this file,
    // this design will not compile.

    // See Verilog LRM 1364-2001 Section 17.2.8 for details on the
    // format of this file, or see the "Using $readmemb and $readmemh"
    // template later in this section.

    initial begin
        $readmemh("E:/Mirror/ZJUI/2022FA/ECE385/Final_Project/FinalProject/sprite.hex", rom, 0, 8191);
    end

    integer i;
    initial begin
        $display("data:");
        for (i = 0; i < 100; i = i + 1) $display("%d:%h", i, rom[i]);
    end
    always @(posedge clk) begin
        q <= rom[addr];
    end

endmodule
