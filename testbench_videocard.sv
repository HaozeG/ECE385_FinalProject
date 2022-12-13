module testbench_videocard ();

    timeunit 10ns;  // Half clock cycle at 50 MHz
    // This is the amount of time represented by #1
    timeprecision 1ns;

    // These signals are internal because the processor will be
    // instantiated as a submodule in testbench.
    logic Clk;
    logic vs, hs;
    logic RESET;
    logic [3:0] red, green, blue;
    logic [15:0] SPRITE_COORD;
    logic [ 3:0] SPRITE_DATA;

    logic [ 6:0] MAP_INDEX;
    logic [ 6:0] SPRITE_INDEX;
    logic        SPRITE_SEL;
    logic [3:0] HERO_DATA, MAP_DATA, RENDER_DATA;
    logic [ 7:0] MAP_BLOCK;

    logic [12:0] SPRITE_ADDR;
    logic [9:0] drawxsig, drawysig;
    logic [15:0] CACHE_PIXEL;  // the pixel painting now
    logic [11:0] PALETTE_NOW;
    logic [15:0] BUFFER_OUT;
    logic [ 7:0] cache_lineX;
    logic        blank, RENDER_EN, BUFFER_SEL;
    logic [15:0] RENDER_INDEX;
    logic [15:0] FB_ADDR;







    parameter DATA_WIDTH = 16;
    parameter ADDR_WIDTH = 14;

    logic [DATA_WIDTH-1:0] ram[2**ADDR_WIDTH-1:0];
    initial begin

        $readmemh("E:/Mirror/ZJUI/2022FA/ECE385/Final_Project/FinalProject/sprite.hex", ram);
    end
    integer i;
    initial begin
        $display("data:");
        for (i = 0; i < 100; i = i + 1) $display("%d:%h", i, ram[i]);
    end

    top_video u_top_video (
        .CLK  (Clk),
        .RESET(RESET),
        // CLOUD

        // MAP

        // HERO

        // AVL_DRAW

        // Exported Conduit (mapped to VGA port - make sure you export in Platform Designer)
        .red  (red),
        .green(green),
        .blue (blue),
        // VGA color channels (mapped to output pins in top-level)
        .hs   (hs),
        // VGA HS/VS
        .vs   (vs)
    );
    logic RENDER_START;
    assign RENDER_START = u_top_video.u_renderer.RENDER_START;
    assign SPRITE_ADDR = u_top_video.SPRITE_ADDR;
    // assign SPRITE_COORD = u_top_video.SPRITE_COORD;
    assign SPRITE_DATA  = u_top_video.SPRITE_DATA;
    assign SPRITE_SEL   = u_top_video.SPRITE_SEL;
    assign MAP_INDEX    = u_top_video.MAP_INDEX;
    // assign SPRITE_INDEX    = u_top_video.SPRITE_INDEX;
    assign HERO_DATA    = u_top_video.HERO_DATA;
    assign MAP_DATA     = u_top_video.MAP_DATA;
    assign MAP_BLOCK    = u_top_video.u_map.MAP_BLOCK;
    assign drawxsig    = u_top_video.drawxsig;
    assign drawysig    = u_top_video.drawysig;
    assign CACHE_PIXEL = u_top_video.CACHE_PIXEL;
    assign PALETTE_NOW = u_top_video.PALETTE_NOW;
    assign BUFFER_OUT  = u_top_video.BUFFER_OUT;
    assign cache_lineX = u_top_video.cache_lineX;
    assign blank       = u_top_video.blank;
    assign RENDER_EN = u_top_video.RENDER_EN;
    assign RENDER_INDEX = u_top_video.u_framebuffer_double.RENDER_INDEX;
    assign BUFFER_SEL = u_top_video.u_framebuffer_double.BUFFER_SEL;
    assign RENDER_DATA = u_top_video.RENDER_DATA;
    assign FB_ADDR = u_top_video.FB_ADDR;

    // Toggle the clock
    // #1 means wait for a delay of 1 timeunit
    always begin : CLOCK_GENERATION
        #1 Clk = ~Clk;
    end

    initial begin : CLOCK_INITIALIZATION
        Clk = 0;
    end

    // Testing begins here
    // The initial block is not synthesizable
    // Everything happens sequentially inside an initial block
    // as in a software program
    initial begin : TEST_VECTORS
        RESET = 0;
        #4 RESET = 1;
        #4 RESET = 0;
    end
endmodule
