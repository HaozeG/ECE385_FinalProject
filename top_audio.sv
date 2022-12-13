module top_audio (
    input        SCLK,
    LRCLK,
    AUDIO_EN,
    output logic I2S_Dout
);
    logic [ 7:0] cnt;
    logic [63:0] AUDIO_Reg;
    logic [63:0] AUDIO_Reg_in;
    logic        AUDIO_Reg_WE;
    logic [23:0] AUDIO_L, AUDIO_R;
    assign AUDIO_L  = 24'hF00000;
    assign AUDIO_R  = 24'hF00000;


    always_ff @(negedge LRCLK) begin
        if (!AUDIO_EN) begin
            cnt <= 0;
        end else begin
            cnt <= cnt + 1;
            if (cnt == 200) cnt <= 0;
        end
        if (cnt % 100 == 1) begin
            AUDIO_Reg_in <= {2'b00, AUDIO_L, 6'b000000, 2'b00, AUDIO_R, 6'b000000};
            AUDIO_Reg_WE <= 1;
        end else begin
            AUDIO_Reg_in <= 64'b0;
            AUDIO_Reg_WE <= 0;
        end
    end

    always_ff @(negedge SCLK) begin
        if (AUDIO_Reg_WE) begin
            AUDIO_Reg <= AUDIO_Reg_in;
        end else begin
            AUDIO_Reg <= {AUDIO_Reg[62:0], 1'b0};
        end
        I2S_Dout = AUDIO_Reg[63];
    end
endmodule
