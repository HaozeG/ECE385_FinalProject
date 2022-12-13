module testbench_audio ();

    timeunit 100us;  // Half clock cycle at 50 MHz
    // This is the amount of time represented by #1
    timeprecision 1ns;

    // These signals are internal because the processor will be
    // instantiated as a submodule in testbench.
    logic Clk;
    logic RESET;
    logic [6:0] cnt;
    logic SCLK, LRCLK;
    logic AUDIO_EN;
    assign AUDIO_EN = RESET;
    assign SCLK = Clk;
    assign LRCLK = cnt[6];
    logic [63:0] AUDIO_Reg;
    logic [7:0] tmp;


    top_audio u_top_audio (
        .SCLK    (SCLK),
        .LRCLK   (LRCLK),
        .AUDIO_EN(AUDIO_EN),
        .I2S_Dout(I2S_Dout)
    );


    assign AUDIO_Reg = u_top_audio.AUDIO_Reg;
    assign tmp = u_top_audio.cnt;




    // Toggle the clock
    // #1 means wait for a delay of 1 timeunit
    always begin : CLOCK_GENERATION
        #1 Clk = ~Clk;
        cnt = cnt + 1;
    end

    initial begin : CLOCK_INITIALIZATION
        Clk = 0;
        cnt = 0;
    end

    // Testing begins here
    // The initial block is not synthesizable
    // Everything happens sequentially inside an initial block
    // as in a software program
    initial begin : TEST_VECTORS
        RESET = 1;
        #4 RESET = 0;
        #200 RESET = 1;
    end
endmodule
