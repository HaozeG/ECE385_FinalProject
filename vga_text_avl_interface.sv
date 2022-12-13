// `define NUM_REGS 601 //80*30 characters / 4 characters per register
// `define COLOR_REG 600 //index of control register
`define COLOR_REG 32'h0800  // starting index of palette registers

module vga_text_avl_interface (
    // Avalon Clock Input, note this clock is also used for VGA, so this must be 50Mhz
    // We can put a clock divider here in the future to make this IP more generalizable
    input logic CLK,

    // Avalon Reset Input
    input logic RESET,

    // Avalon-MM Slave Signals
    input  logic        AVL_READ,       // Avalon-MM Read
    input  logic        AVL_WRITE,      // Avalon-MM Write
    input  logic        AVL_CS,         // Avalon-MM Chip Select
    input  logic [ 3:0] AVL_BYTE_EN,    // Avalon-MM Byte Enable
    input  logic [11:0] AVL_ADDR,       // Avalon-MM Address
    input  logic [31:0] AVL_WRITEDATA,  // Avalon-MM Write Data
    output logic [31:0] AVL_READDATA,   // Avalon-MM Read Data

    // Exported Conduit (mapped to VGA port - make sure you export in Platform Designer)
    output logic [3:0] red,
    green,
    blue,  // VGA color channels (mapped to output pins in top-level)
    output logic       hs,
    vs  // VGA HS/VS
);


    logic [31:0] VRAM_OUT1, VRAM_OUT2;
    logic VGA_Clk, Invert, blank, sync;
    logic [10:0] VRAM_ADDR;
    logic [23:0] COLOR_CTL;
    logic        byte_choose;
    logic [9:0] drawxsig, drawysig;
    logic [ 7:0] Font_DATA;
    logic [10:0] Font_ADDR;
    logic [ 5:0] CHAR_row;
    logic [ 6:0] CHAR_colomn;
    logic [11:0] VRAM_index;
    logic [3:0] mapped_red, mapped_green, mapped_blue;
    logic        WREN;

    // logic [31:0] LOCAL_REG[`NUM_REGS];  // Registers

    // Each color corresponds to one color
    logic [31:0] COLOR_REG[16];  // Palette Registers

    // VRAM using on-chip memory
    // address_a: read/write by AVALON bus
    // address_b: read for font data
    vram u_vram (
        .address_a(VRAM_ADDR),
        .address_b(VRAM_index),
        .byteena_a(AVL_BYTE_EN),
        .clock    (CLK),
        .data_a   (AVL_WRITEDATA),
        .data_b   (32'b0),
        .wren_a   (WREN & AVL_CS),
        .wren_b   (1'b0),
        .q_a      (VRAM_OUT1),
        .q_b      (VRAM_OUT2)
    );

    //Declare submodules..e.g. VGA controller, ROMS, etc
    vga_controller u_vga_controller (
        .Clk      (CLK),
        // 50 MHz clock
        .Reset    (RESET),
        // reset signal
        .hs       (hs),
        // Horizontal sync pulse.  Active low
        .vs       (vs),
        // Vertical sync pulse.  Active low
        .pixel_clk(VGA_Clk),
        // 25 MHz pixel clock output
        .blank    (blank),
        // Blanking interval indicator.  Active low.
        .sync     (sync),
        // Composite Sync signal.  Active low.  We don't use it in this lab,
        //   but the video DAC on the DE2 board requires an input for it.
        .DrawX    (drawxsig),
        // horizontal coordinate
        .DrawY    (drawysig)
    );

    font_rom u_font_rom (
        .addr(Font_ADDR),
        .data(Font_DATA)
    );

    color_mapper u_color_mapper (
        .Font_DATA(Font_DATA),
        .DrawX    (drawxsig),
        .Color_Ctl(COLOR_CTL),
        .INVERT   (Invert),
        .Red      (mapped_red),
        .Green    (mapped_green),
        .Blue     (mapped_blue)
    );

    // Read/write routing
    always_comb begin
        if (RESET) begin
            VRAM_ADDR    = 0;
            AVL_READDATA = 0;
            WREN         = 0;
            for (int i = 0; i < 16; i++) COLOR_REG[i] = 0;
        end else begin
            if (AVL_ADDR[11]) begin
                // Access to palette: direct r/w
                VRAM_ADDR                 = 0;
                AVL_READDATA              = 0;
                WREN                      = 0;
                COLOR_REG[AVL_ADDR[10:0]] = COLOR_REG[AVL_ADDR[10:0]];
                if (AVL_READ) begin
                    AVL_READDATA = COLOR_REG[AVL_ADDR[10:0]];
                end else if (AVL_WRITE) begin
                    COLOR_REG[AVL_ADDR[10:0]] = AVL_WRITEDATA;
                end
            end else begin
                // Access to VRAM: set VRAM_ADDR
                WREN = AVL_WRITE;
                if (AVL_READ | AVL_WRITE) begin
                    VRAM_ADDR = AVL_ADDR;
                end else VRAM_ADDR = 0;
                AVL_READDATA = VRAM_OUT1;
            end
        end
    end

    // Set Font_ADDR to read from font_rom
    // Get color info
    always_comb begin
        if (RESET) begin
            Font_ADDR   = 0;
            CHAR_row    = 0;
            CHAR_colomn = 0;
            VRAM_index  = 0;
            byte_choose = 0;
            Invert      = 0;
            COLOR_CTL   = 0;
        end else begin
            CHAR_row    = drawysig[9:4];  // divide by 16
            CHAR_colomn = drawxsig[9:3];  // divide by 8
            VRAM_index  = CHAR_row * 40 + CHAR_colomn[6:1];  // CHAR_row * 40 + CHAR_colomn / 2
            // choose from 4 bytes
            byte_choose = CHAR_colomn[0];  // modular 2
            case (byte_choose)
                1'd1: begin
                    Invert           = VRAM_OUT2[31];
                    Font_ADDR        = VRAM_OUT2[30:24] * 16 + (drawysig - CHAR_row * 16);
                    // foreground color
                    COLOR_CTL[23:12] = COLOR_REG[VRAM_OUT2[23:20]][11:0];
                    // background color
                    COLOR_CTL[11:0]  = COLOR_REG[VRAM_OUT2[19:16]][11:0];
                end
                1'd0: begin
                    Invert           = VRAM_OUT2[15];
                    Font_ADDR        = VRAM_OUT2[14:8] * 16 + (drawysig - CHAR_row * 16);
                    // foreground color
                    COLOR_CTL[23:12] = COLOR_REG[VRAM_OUT2[7:4]][11:0];
                    // background color
                    COLOR_CTL[11:0]  = COLOR_REG[VRAM_OUT2[3:0]][11:0];
                end
                default: ;
            endcase
        end
    end

    // output black in blank interval
    always_ff @(posedge VGA_Clk) begin
        if (!blank) begin
            red   <= 4'h0;
            green <= 4'h0;
            blue  <= 4'h0;
        end else begin
            red   <= mapped_red;
            green <= mapped_green;
            blue  <= mapped_blue;
        end
    end

endmodule
