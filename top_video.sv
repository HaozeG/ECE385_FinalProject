`define Xmin 10'd0191
// `define Xmin 10'd0000
`define Xmax 10'd0446
// `define Xmax 10'd0255
`define Ymin 10'd0111
// `define Ymin 10'd0000
`define Ymax 10'd0366
// `define Ymax 10'd0255

module top_video (
    input logic CLK,
    CLK_NIOS,

    input logic RESET,

    // HERO data from AVL
    input logic       MAP_WRITE_ENABLE,
    input logic [7:0] MAP_WRITE_DATA,
    input logic [7:0] MAP_WRITE_ADDR,

    // HERO data from AVL
    input logic [7:0] HERO_X,
    HERO_Y,
    input       [2:0] HERO_INDEX_IN,
    input             HERO_FLIP_EN,
    input       [1:0] HERO_HAIR,
    input             SHAKE_EN,

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
    // logic [7:0] cache_lineX;

    logic [15:0] CLOUD_COORD;
    logic [ 3:0] CLOUD_DATA;
    logic [12:0] SPRITE_ADDR;
    logic [ 3:0] SPRITE_DATA;
    logic [ 1:0] SPRITE_SEL;
    logic [15:0] MAP_COORD;
    logic [ 6:0] MAP_INDEX;
    logic [ 3:0] MAP_DATA;
    logic [15:0] HERO_COORD;
    logic [ 6:0] HERO_INDEX;  // Index in sprite table
    logic [ 3:0] HERO_DATA;  // Color palette value
    logic        HERO_FLIP;
    // screen shaking
    logic [2:0] SS_X, SS_Y;
    logic        SS_EN;  // Trigger screen shake
    logic [ 3:0] SS_cnt;  // counter for screen shake
    logic        SS_sign;
    logic [31:0] SS_rand;  // preset random values
    assign SS_rand = 32'b10011001011010101101100010110010;

    logic [3:0] BUFFER_OUT;

    always_comb begin
        if (SHAKE_EN) begin
            SS_EN = 1;
        end else begin
            SS_EN = 0;
        end
        if (HERO_FLIP_EN) begin
            HERO_FLIP = 1;
        end else begin
            HERO_FLIP = 0;
        end
    end

    // always_ff @(posedge vs) begin
    //     if (keycode == 8'h20) begin
    //         AVL_WRITE_ENABLE = 1;
    //         AVL_WRITE_DATA = 8'b00000000;
    //         AVL_WRITE_ADDR = 8'b00000000 + SS_rand >> HERO_X;
    //     end else begin
    //         AVL_WRITE_ENABLE = 0;
    //         AVL_WRITE_DATA = 8'b00000000;
    //         AVL_WRITE_ADDR = 8'b00000000;
    //     end
    // end


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
        .CLK_NIOS (CLK_NIOS),
        .MAP_WRITE_ENABLE,
        .MAP_WRITE_DATA,
        .MAP_WRITE_ADDR,
        .MAP_COORD(MAP_COORD),
        .MAP_INDEX(MAP_INDEX)
    );

    // HERO
    hero u_hero (
        .CLK          (vs),
        .RESET        (RESET),
        .HERO_RESET   (HERO_RESET),
        .HERO_COORD   (HERO_COORD),
        .HERO_INDEX   (HERO_INDEX),
        .HERO_INDEX_IN(HERO_INDEX_IN),
        .HERO_X       (HERO_X),
        .HERO_Y       (HERO_Y)
    );

    // Route between map and hero
    always_comb begin
        if (SPRITE_SEL == 2'b01) begin
            SPRITE_ADDR = MAP_INDEX * 64 + ((MAP_COORD[15:8] % 16) / 2) * 8 + ((MAP_COORD[7:0] - 1) % 16) / 2;
            HERO_DATA = 4'h0;
            MAP_DATA = SPRITE_DATA;
        end else if (SPRITE_SEL == 2'b10) begin
            if (HERO_INDEX != 7'b0000000) begin
                // flip?
                if (HERO_FLIP) begin
                    SPRITE_ADDR  = HERO_INDEX * 64 + (HERO_COORD[15:8] - HERO_Y) / 2 * 8 + (15- HERO_COORD[7:0] + HERO_X) / 2;
                end else begin
                    SPRITE_ADDR  = HERO_INDEX * 64 + (HERO_COORD[15:8] - HERO_Y) / 2 * 8 + (HERO_COORD[7:0] - HERO_X) / 2;
                end
            end else begin
                SPRITE_ADDR = 7'b0000;
            end
            // Deal with hair color change(red -> blue)
            if (SPRITE_DATA == 4'h8 & HERO_HAIR == 2'b00) begin
                HERO_DATA = 4'hc;
            end else if (SPRITE_DATA == 4'h8 & HERO_HAIR == 2'b10) begin
                HERO_DATA = 4'hb;
            end else begin
                HERO_DATA = SPRITE_DATA;
            end
            MAP_DATA = 4'h0;
        end else begin
            SPRITE_ADDR = 13'b0;
            HERO_DATA   = 4'h0;
            MAP_DATA    = 4'h0;
        end
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

    // screen shaking effect
    enum logic {
        OFF,
        ON
    }
        SS_curr_state, SS_next_state;

    always_ff @(posedge vs or posedge RESET) begin
        if (RESET) SS_curr_state <= OFF;
        else SS_curr_state <= SS_next_state;

        if (RESET) SS_cnt <= 4'b0000;
        else if (SS_curr_state == ON) SS_cnt <= SS_cnt + 1'b1;
        else SS_cnt <= 4'b0000;
    end

    always_comb begin
        SS_next_state = SS_curr_state;
        unique case (SS_curr_state)
            OFF: if (SS_EN) SS_next_state = ON;
            ON:  if (SS_cnt == 4'b1100) SS_next_state = OFF;
        endcase
        case (SS_curr_state)
            OFF: begin
                SS_X    = 3'b000;
                SS_Y    = 3'b000;
                SS_sign = 0;
            end
            ON: begin
                SS_X    = SS_rand >> (SS_cnt % 2);
                SS_Y    = SS_rand >> ((SS_cnt + 1'b1) % 2);
                SS_sign = SS_X[0];
            end
            default: begin
                SS_X    = 3'b000;
                SS_Y    = 3'b000;
                SS_sign = 0;
            end
        endcase
    end

    // retrieve data from framebuffer
    always_comb begin
        if (SS_sign == 0) begin
            if (drawysig >= (`Ymin + SS_Y) & drawysig <= (`Ymax + SS_Y) & drawxsig >= (`Xmin + SS_X) & drawxsig <= (`Xmax + SS_X)) begin
                FB_ADDR = 256 * (drawysig - `Ymin - SS_Y) + drawxsig - `Xmin - SS_X + 4;  // additional offset considering delays
            end else begin
                FB_ADDR = 16'h0000;
            end
        end else begin
            if (drawysig >= (`Ymin - SS_Y) & drawysig <= (`Ymax - SS_Y) & drawxsig >= (`Xmin - SS_X) & drawxsig <= (`Xmax - SS_X)) begin
                FB_ADDR = 256 * (drawysig - `Ymin + SS_Y) + drawxsig - `Xmin + SS_X + 4;  // additional offset considering delays
            end else begin
                FB_ADDR = 16'h0000;
            end
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
        if (SS_sign == 0) begin
            if ((!blank) | !(drawxsig >= (`Xmin + SS_X) & drawxsig < (`Xmax + SS_X) & drawysig >= (`Ymin + SS_Y) & drawysig <= (`Ymax + SS_Y))) begin
                // if ((!blank)) begin
                red   <= 4'h0;
                green <= 4'h0;
                blue  <= 4'h0;
            end else begin
                red   <= CACHE_PIXEL[11:8];
                green <= CACHE_PIXEL[7:4];
                blue  <= CACHE_PIXEL[3:0];
            end
        end else begin
            if ((!blank) | !(drawxsig >= (`Xmin - SS_X) & drawxsig < (`Xmax - SS_X) & drawysig >= (`Ymin - SS_Y) & drawysig <= (`Ymax - SS_Y))) begin
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
