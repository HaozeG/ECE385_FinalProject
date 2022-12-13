module avl_interface (
    // Avalon Clock Input
    input logic CLK,

    // Avalon Reset Input
    input logic RESET,

    // Avalon-MM Slave Signals
    input logic       AVL_WRITE,     // Avalon-MM Write
    input logic       AVL_CS,        // Avalon-MM Chip Select
    input logic [7:0] AVL_ADDR,      // Avalon-MM Address
    input logic [7:0] AVL_WRITEDATA, // Avalon-MM Write Data

    // passthrough
    output logic       MAP_WRITE_ENABLE,
    output logic [7:0] MAP_WRITE_DATA,
    output logic [7:0] MAP_WRITE_ADDR,

    // HERO related
    output logic [7:0] HERO_X, HERO_Y
);

    always_ff @(posedge CLK or posedge RESET) begin
        if (RESET) begin
            MAP_WRITE_ADDR   <= 8'b00000000;
            MAP_WRITE_DATA   <= 8'b00000000;
            MAP_WRITE_ENABLE <= 1'b0;
        end else begin
            MAP_WRITE_ADDR   <= AVL_ADDR;
            MAP_WRITE_DATA   <= AVL_WRITEDATA;
            MAP_WRITE_ENABLE <= AVL_WRITE;
        end
    end
endmodule
