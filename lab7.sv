//-------------------------------------------------------------------------
//      ECE 385 - Summer 2021 Lab 7 Top-level                            --
//                                                                       --
//      Updated Fall 2021 as Lab 7                                       --
//      For use with ECE 385                                             --
//      UIUC ECE Department                                              --
//-------------------------------------------------------------------------


module lab7 (

    ///////// Clocks /////////
    input MAX10_CLK1_50,

    ///////// KEY /////////
    input [1:0] KEY,

    ///////// SW /////////
    input [9:0] SW,

    ///////// LEDR /////////
    output [9:0] LEDR,

    ///////// HEX /////////
    output [7:0] HEX0,
    output [7:0] HEX1,
    output [7:0] HEX2,
    output [7:0] HEX3,
    output [7:0] HEX4,
    output [7:0] HEX5,

    ///////// SDRAM /////////
    output        DRAM_CLK,
    output        DRAM_CKE,
    output [12:0] DRAM_ADDR,
    output [ 1:0] DRAM_BA,
    inout  [15:0] DRAM_DQ,
    output        DRAM_LDQM,
    output        DRAM_UDQM,
    output        DRAM_CS_N,
    output        DRAM_WE_N,
    output        DRAM_CAS_N,
    output        DRAM_RAS_N,

    ///////// VGA /////////
    output       VGA_HS,
    output       VGA_VS,
    output [3:0] VGA_R,
    output [3:0] VGA_G,
    output [3:0] VGA_B,





    ///////// ARDUINO /////////
    inout [15:0] ARDUINO_IO,
    inout        ARDUINO_RESET_N

);

    //=======================================================
    //  REG/WIRE declarations
    //=======================================================
    logic SPI0_CS_N, SPI0_SCLK, SPI0_MISO, SPI0_MOSI, USB_GPX, USB_IRQ, USB_RST;
    logic CLK_100;
    logic [3:0] hex_num_4, hex_num_3, hex_num_1, hex_num_0;  //4 bit input hex digits
    logic [1:0] signs;
    logic [1:0] hundreds;
    logic [7:0] keycode;
    logic [1:0] aud_mclk_ctr;
    logic
        i2c_serial_scl_oe,
        i2c_serial_scl_in,
        i2c_serial_sda_oe,
        i2c_serial_sda_in,
        arduino_adc_scl,
        arduino_adc_sda;
    logic       MAP_WRITE_ENABLE;
    logic [7:0] MAP_WRITE_DATA;
    logic [7:0] MAP_WRITE_ADDR;
    logic SCLK, LRCLK, AUDIO_EN, I2S_Dout;
    logic [7:0] HERO_X, HERO_Y;
    logic [2:0] HERO_INDEX;
    logic       HERO_FLIP;
    logic [1:0] HERO_HAIR;
    logic SHAKE_EN, SOUND_EN;

    //=======================================================
    //  Structural coding
    //=======================================================
    assign ARDUINO_IO[10]  = SPI0_CS_N;
    assign ARDUINO_IO[13]  = SPI0_SCLK;
    assign ARDUINO_IO[11]  = SPI0_MOSI;
    assign ARDUINO_IO[12]  = 1'bZ;
    assign SPI0_MISO       = ARDUINO_IO[12];

    assign ARDUINO_IO[9]   = 1'bZ;
    assign USB_IRQ         = ARDUINO_IO[9];

    //Assignments specific to Sparkfun USBHostShield-v13
    //assign ARDUINO_IO[7] = USB_RST;
    //assign ARDUINO_IO[8] = 1'bZ;
    //assign USB_GPX = ARDUINO_IO[8];

    //Assignments specific to Circuits At Home UHS_20
    assign ARDUINO_RESET_N = USB_RST;
    assign ARDUINO_IO[8]   = 1'bZ;
    //GPX is unconnected to shield, not needed for standard USB host - set to 0 to prevent interrupt
    assign USB_GPX         = 1'b0;

    //HEX drivers to convert numbers to HEX output
    HexDriver hex_driver4 (
        hex_num_4,
        HEX4[6:0]
    );
    assign HEX4[7] = 1'b1;

    HexDriver hex_driver3 (
        hex_num_3,
        HEX3[6:0]
    );
    assign HEX3[7] = 1'b1;

    HexDriver hex_driver1 (
        hex_num_1,
        HEX1[6:0]
    );
    assign HEX1[7] = 1'b1;

    HexDriver hex_driver0 (
        hex_num_0,
        HEX0[6:0]
    );
    assign HEX0[7]       = 1'b1;

    //fill in the hundreds digit as well as the negative sign
    assign HEX5          = {1'b1, ~signs[1], 3'b111, ~hundreds[1], ~hundreds[1], 1'b1};
    assign HEX2          = {1'b1, ~signs[0], 3'b111, ~hundreds[0], ~hundreds[0], 1'b1};


    assign {Reset_h}     = ~(KEY[0]);

    //assign signs = 2'b00;
    //assign hex_num_4 = 4'h4;
    //assign hex_num_3 = 4'h3;
    //assign hex_num_1 = 4'h1;
    //assign hex_num_0 = 4'h0;

    // I2C clock
    assign ARDUINO_IO[3] = aud_mclk_ctr[1];  //generate 12.5MHz CODEC mclk
    always_ff @(posedge MAX10_CLK1_50) begin
        aud_mclk_ctr <= aud_mclk_ctr + 1;
    end
    // I2C connection
    assign i2c_serial_scl_in = ARDUINO_IO[15];
    assign ARDUINO_IO[15]    = i2c_serial_scl_oe ? 1'b0 : 1'bz;
    assign i2c_serial_sda_in = ARDUINO_IO[14];
    assign ARDUINO_IO[14]    = i2c_serial_sda_oe ? 1'b0 : 1'bz;

    // I2S
    assign SCLK              = ARDUINO_IO[5];
    assign LRCLK             = ARDUINO_IO[4];
    assign ARDUINO_IO[1]     = I2S_Dout;  // I2S_Dout
    assign ARDUINO_IO[2]     = I2S_Dout;  // I2S_Din

    // logic [20:0] cnt;
    // always_ff @(posedge SCLK) begin
    //     cnt       <= cnt + 1;
    //     hex_num_0 <= cnt[19];
    // end
    // logic [20:0] cnt_0;
    // always_ff @(posedge LRCLK) begin
    //     cnt_0     <= cnt_0 + 1;
    //     hex_num_1 <= cnt_0[19];
    // end

    pll u_pll (
        .inclk0(MAX10_CLK1_50),
        .c0    (CLK_100)
    );

    //remember to rename the SOC as necessary
    final_soc u0 (
        .clk_clk      (CLK_100),  //clk.clk
        .reset_reset_n(1'b1),     //reset.reset_n
        // .altpll_0_locked_conduit_export   (),               //altpll_0_locked_conduit.export
        // .altpll_0_phasedone_conduit_export(),               //altpll_0_phasedone_conduit.export
        // .altpll_0_areset_conduit_export   (),               //altpll_0_areset_conduit.export

        .key_external_connection_export(KEY),  //key_external_connection.export

        //SDRAM
        .sdram_clk_clk   (DRAM_CLK),                //clk_sdram.clk
        .sdram_wire_addr (DRAM_ADDR),               //sdram_wire.addr
        .sdram_wire_ba   (DRAM_BA),                 //.ba
        .sdram_wire_cas_n(DRAM_CAS_N),              //.cas_n
        .sdram_wire_cke  (DRAM_CKE),                //.cke
        .sdram_wire_cs_n (DRAM_CS_N),               //.cs_n
        .sdram_wire_dq   (DRAM_DQ),                 //.dq
        .sdram_wire_dqm  ({DRAM_UDQM, DRAM_LDQM}),  //.dqm
        .sdram_wire_ras_n(DRAM_RAS_N),              //.ras_n
        .sdram_wire_we_n (DRAM_WE_N),               //.we_n

        //USB SPI
        .spi0_SS_n(SPI0_CS_N),
        .spi0_MOSI(SPI0_MOSI),
        .spi0_MISO(SPI0_MISO),
        .spi0_SCLK(SPI0_SCLK),

        //USB GPIO
        .usb_rst_export(USB_RST),
        .usb_irq_export(USB_IRQ),
        .usb_gpx_export(USB_GPX),

        //LEDs and HEX
        .hex_digits_export({hex_num_4, hex_num_3, hex_num_1, hex_num_0}),
        .leds_export      ({hundreds, signs, LEDR}),
        .keycode_export   (keycode),

        // I2C
        .i2c_serial_sda_in,  //i2c_serial.sda_in
        .i2c_serial_scl_in,  //.scl_in
        .i2c_serial_sda_oe,  //.sda_oe
        .i2c_serial_scl_oe,  //.scl_oe

        .map_write_map_write_enable(MAP_WRITE_ENABLE),  //               map_write.map_write_enable
        .map_write_map_write_data(MAP_WRITE_DATA),  //                        .map_write_data
        .map_write_map_write_addr(MAP_WRITE_ADDR),  //                        .map_write_addr
        .hero_data_export({HERO_INDEX, HERO_X, HERO_Y, HERO_FLIP, HERO_HAIR, SHAKE_EN, SOUND_EN})
    );

    top_video u_top_video (
        .CLK     (MAX10_CLK1_50),
        .CLK_NIOS(CLK_100),
        .RESET   (Reset_h),

        // map data from AVL
        .MAP_WRITE_ENABLE(MAP_WRITE_ENABLE),
        .MAP_WRITE_DATA  (MAP_WRITE_DATA),
        .MAP_WRITE_ADDR  (MAP_WRITE_ADDR),
        .HERO_X          (HERO_X),
        .HERO_Y          (HERO_Y),
        .HERO_INDEX_IN   (HERO_INDEX),
        .HERO_FLIP_EN    (HERO_FLIP),
        .HERO_HAIR       (HERO_HAIR),
        .SHAKE_EN        (SHAKE_EN),



        // Exported Conduit (mapped to VGA port - make sure you export in Platform Designer)
        .red  (VGA_R),
        .green(VGA_G),
        .blue (VGA_B),
        // VGA color channels (mapped to output pins in top-level)
        .hs   (VGA_HS),
        // VGA HS/VS
        .vs   (VGA_VS)
    );

    top_audio u_top_audio (
        .SCLK    (SCLK),
        .LRCLK   (LRCLK),
        .AUDIO_EN(AUDIO_EN),
        .I2S_Dout(I2S_Dout)
    );

    // Play audio for ~0.5s
    logic [14:0] cnt;
    logic        cnt_EN;

    // FSM
    enum logic {
        PAUSE,
        PLAY
    }
        curr_state, next_state;

    always_ff @(posedge MAX10_CLK1_50) begin
        if (Reset_h) curr_state <= PAUSE;
        else curr_state <= next_state;
        if (cnt_EN) cnt <= cnt + 1;
        else cnt <= 0;
    end

    always_comb begin
        next_state = curr_state;
        unique case (curr_state)
            PAUSE: if (SOUND_EN) next_state = PLAY;
            PLAY:  if (cnt == 15'd16384) next_state = PAUSE;
        endcase

        case (curr_state)
            PAUSE: begin
                AUDIO_EN = 0;
                cnt_EN   = 0;
            end
            PLAY: begin
                AUDIO_EN = 1;
                cnt_EN   = 1;
            end
        endcase
    end
endmodule
