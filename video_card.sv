`define Xmin 10'd0191
// `define Xmin 10'd0000
`define Xmax 10'd0446
// `define Xmax 10'd0255
`define Ymin 10'd0111
// `define Ymin 10'd0000
`define Ymax 10'd0366
// `define Ymax 10'd0255

module video_card (
    input logic CLK,

    input logic       RESET,
    input logic [7:0] keycode,



    // Exported Conduit (mapped to VGA port - make sure you export in Platform Designer)
    output logic [3:0] red,
    green,
    blue,  // VGA color channels (mapped to output pins in top-level)
    output logic       hs,
    vs  // VGA HS/VS
);

    logic VGA_Clk, blank, sync;
    logic [9:0] drawxsig, drawysig;
    logic [8:0] renderxsig, renderysig;
    logic [ 3:0] RENDER_DATA;
    logic        RENDER_EN;
    logic [ 7:0] cache_lineX;

    logic [ 3:0] BUFFER_OUT;
    logic [15:0] CLOUD_COORD;
    logic [ 3:0] CLOUD_DATA;
    logic [12:0] SPRITE_ADDR;
    logic [ 3:0] SPRITE_DATA;
    logic [ 1:0] SPRITE_SEL;
    logic [15:0] MAP_COORD;
    logic [ 6:0] MAP_INDEX;
    logic [ 3:0] MAP_DATA;
    logic [15:0] HERO_COORD;
    logic [ 6:0] HERO_INDEX;
    logic [ 3:0] HERO_DATA;
    logic [7:0] HERO_X, HERO_Y;


    // CLOUD
    cloud u_cloud (
        .CLK        (vs),
        .RESET      (RESET),
        .CLOUD_COORD(CLOUD_COORD - 1),  // {COORD_Y,COORD_X}
        .CLOUD_DATA (CLOUD_DATA)
    );

    // MAP
    // 16 * 16 * 8bit(128 different blocks)
    // containing map information
    map u_map (
        .CLK      (CLK),
        .MAP_COORD(MAP_COORD),
        .MAP_INDEX(MAP_INDEX)
    );

    // HERO
    hero u_hero (
        .CLK       (vs),
        .RESET     (RESET),
        .keycode   (keycode),
        .HERO_RESET(HERO_RESET),
        .HERO_COORD(HERO_COORD),
        .HERO_INDEX(HERO_INDEX),
        .HERO_X    (HERO_X),
        .HERO_Y    (HERO_Y)
    );

    // Route between map and hero
    always_comb begin
        if (SPRITE_SEL == 2'b01) begin
            SPRITE_ADDR = MAP_INDEX * 64 + ((MAP_COORD[15:8] % 16) / 2) * 8 + ((MAP_COORD[7:0] - 1) % 16) / 2;
            HERO_DATA = 4'h0;
            MAP_DATA = SPRITE_DATA;
        end else if (SPRITE_SEL == 2'b10) begin
            if (HERO_INDEX != 7'b0000000) begin
                SPRITE_ADDR  = HERO_INDEX * 64 + (HERO_COORD[15:8] - HERO_Y) / 2 * 8 + (HERO_COORD[7:0] - HERO_X) / 2;
            end else begin
                SPRITE_ADDR = 7'b0000;
            end
            // Deal with hair color change(red -> blue)
            if (SPRITE_DATA == 4'h8 & cnt[4] == 1'b0) begin
                HERO_DATA = 4'hc;
            end else begin
                HERO_DATA = SPRITE_DATA;
            end
            MAP_DATA = 4'h0;
        end else begin
            SPRITE_ADDR = 13'b0;
            HERO_DATA = 4'h0;
            MAP_DATA = 4'h0;
        end
    end

    // temp variable
    logic [6:0] cnt;
    always_ff @(posedge vs) begin
        cnt <= cnt + 1;
    end

    // SPRITE
    sprite_table u_sprite_table (
        .CLK        (CLK),
        .SPRITE_ADDR(SPRITE_ADDR),
        .SPRITE_DATA(SPRITE_DATA)
    );

    // RENDERER
    // deal with frame rendering
    // connect with ROMs/RAMs containing scene data
    renderer u_renderer (
        .CLK        (CLK),
        .vs         (vs),
        .RESET      (RESET),
        // MULTIPLE LAYERS
        // CLOUD
        .CLOUD_COORD(CLOUD_COORD),
        .CLOUD_DATA (CLOUD_DATA),
        // MAP
        .MAP_COORD  (MAP_COORD),
        .MAP_DATA   (MAP_DATA),
        .SPRITE_SEL (SPRITE_SEL),
        // HERO
        .HERO_COORD (HERO_COORD),
        .HERO_DATA  (HERO_DATA),


        .RENDER_EN  (RENDER_EN),
        .RENDER_DATA(RENDER_DATA),
        .RENDER_X   (renderxsig),
        .RENDER_Y   (renderysig)
    );

    logic [15:0] FB_ADDR;

    // DOUBLE_BUFFER
    // 2frames * 256colomns * 256rows * 4bits
    // double framebuffer for more versatile use
    // RENDER: write data into buffer
    framebuffer_double #(
        .DATA_WIDTH(4),
        .ADDR_WIDTH(16)
    ) u_framebuffer_double (
        .CLK         (CLK),
        .SEL_CLK     (vs),
        .RESET       (RESET),
        .RENDER_INDEX(256 * renderysig + renderxsig),
        .RENDER_EN   (RENDER_EN),
        .addr_read   (FB_ADDR),
        .FB_IN       (RENDER_DATA),
        .FB_OUT      (BUFFER_OUT)
    );

    // retrieve data from framebuffer
    always_comb begin
        if (drawysig >= `Ymin & drawysig <= `Ymax & drawxsig >= `Xmin & drawxsig <= `Xmax) begin
            FB_ADDR = 256 * (drawysig - `Ymin) + drawxsig - `Xmin + 4;  // additional offset considering delays
        end else begin
            FB_ADDR = 16'h0000;
        end
    end

    // PALETTE_REGS
    // 16color * 12bits/color
    // Each register corresponds to one color
    // hardcoded with certain values
    // between frame_buffer and cache_line
    logic [11:0] PALETTE_REG   [16];  // Palette Registers
    logic [11:0] PALETTE_NOW;
    logic [ 3:0] PALETTE_INDEX;
    initial begin : Palette_init
        PALETTE_REG[0]  = 12'h000;  // Transparent
        PALETTE_REG[1]  = 12'h235;
        PALETTE_REG[2]  = 12'h825;
        PALETTE_REG[3]  = 12'h085;
        PALETTE_REG[4]  = 12'hA53;
        PALETTE_REG[5]  = 12'h655;
        PALETTE_REG[6]  = 12'hCCD;
        PALETTE_REG[7]  = 12'hFFE;
        PALETTE_REG[8]  = 12'hF04;
        PALETTE_REG[9]  = 12'hFA0;
        PALETTE_REG[10] = 12'hFE3;
        PALETTE_REG[11] = 12'h0E3;
        PALETTE_REG[12] = 12'h3BF;
        PALETTE_REG[13] = 12'h87A;
        PALETTE_REG[14] = 12'hF7A;
        PALETTE_REG[15] = 12'hFCA;
    end

    always_comb begin : Palette_Access
        PALETTE_INDEX = BUFFER_OUT;
        PALETTE_NOW   = PALETTE_REG[PALETTE_INDEX];
    end

    // CACHE_LINE read
    logic [15:0] CACHE_PIXEL;  // the pixel painting now

    assign CACHE_PIXEL = PALETTE_NOW;
    // DISCARDED to simplify
    // // CACHE_LINE
    // // 16bits/pixel * 256pixels
    // // 16-bit width cache for one line in on-chip memory
    // // each address stores 12-bit RGB for certain pixel
    // // seperate processing clock(50MHz) from output clock(25MHz)
    // // port a: cache data from frame_buffer
    // // port b: output certain pixel with data info
    // cache_line u_cache_line (
    //     .RESET        (RESET),
    //     .blank        (blank),
    //     .clk_a        (CLK),
    //     .clk_b        (VGA_Clk),
    //     .data_a       ({4'b0, PALETTE_NOW}),
    //     .addr_b       (drawxsig - `Xmin + 1),
    //     .q_b          (CACHE_PIXEL),
    //     .cache_lineX_0(cache_lineX)
    // );

    // RGB_SYNCHRONIZER
    // synchronize output signals to VGA_Clk
    always_ff @(posedge VGA_Clk) begin : RGB_SYNCHRONIZER
        if ((!blank) | !(drawxsig >= `Xmin & drawxsig < `Xmax & drawysig >= `Ymin & drawysig <= `Ymax)) begin
            // if ((!blank)) begin
            red   <= 4'h0;
            green <= 4'h0;
            blue  <= 4'h0;
        end else begin
            red   <= CACHE_PIXEL[11:8];
            green <= CACHE_PIXEL[7:4];
            blue  <= CACHE_PIXEL[3:0];
        end
    end

    // VGA_CONTROLLER
    // basic VGA control signals
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
endmodule
