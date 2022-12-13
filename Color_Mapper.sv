module color_mapper (
    input        [ 9:0] DrawX,
    DrawY,
    input        [15:0] CACHE_DATA,
    input        [11:0] PALETTE_NOW,
    output       [ 3:0] PALETTE_INDEX,
    output logic [ 3:0] Red,
    Green,
    Blue
);
logic scene_on;
    always_comb begin : RGB_Display
        if (scene_on) begin
            Red   = PALETTE_NOW[11:8];
            Green = PALETTE_NOW[7:4];
            Blue  = PALETTE_NOW[3:0];
        end else begin
            Red   = 0;
            Green = 0;
            Blue  = 0;
        end
    end

endmodule
