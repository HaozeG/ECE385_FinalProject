module cloud (
    input               RESET,
    CLK,
    input        [15:0] CLOUD_COORD,  // {COORD_Y,COORD_X}
    output logic [ 3:0] CLOUD_DATA
);
    logic [7:0] X, Y;
    assign X = CLOUD_COORD[7:0];
    assign Y = CLOUD_COORD[15:8];

    logic [8:0] CLOUD0_CORNER_X, CLOUD0_CORNER_Y;
    logic [8:0] CLOUD1_CORNER_X, CLOUD1_CORNER_Y;
    logic [8:0] CLOUD2_CORNER_X, CLOUD2_CORNER_Y;
    logic [8:0] CLOUD3_CORNER_X, CLOUD3_CORNER_Y;

    logic [6:0] CLOUD0_X, CLOUD0_Y;
    logic [6:0] CLOUD1_X, CLOUD1_Y;
    logic [6:0] CLOUD2_X, CLOUD2_Y;
    logic [6:0] CLOUD3_X, CLOUD3_Y;

    assign CLOUD0_X = 7'b1100100;
    assign CLOUD0_Y = 7'b0011011;
    assign CLOUD1_X = 7'b0100111;
    assign CLOUD1_Y = 7'b0011111;
    assign CLOUD2_X = 7'b1001001;
    assign CLOUD2_Y = 7'b0110111;
    assign CLOUD3_X = 7'b1001000;
    assign CLOUD3_Y = 7'b0100101;

    logic [3:0] CLOUD0_STEP, CLOUD1_STEP, CLOUD2_STEP, CLOUD3_STEP;

    assign CLOUD0_STEP = 4'b0001;
    assign CLOUD1_STEP = 4'b0010;
    assign CLOUD2_STEP = 4'b0100;
    assign CLOUD3_STEP = 4'b0011;

    always_ff @(posedge RESET or posedge CLK) begin : Move_Cloud
        if (RESET)  // Asynchronous Reset
        begin
            CLOUD0_CORNER_X <= 8'b00000000;
            CLOUD1_CORNER_X <= 8'b00000000;
            CLOUD2_CORNER_X <= 8'b00000000;
            CLOUD3_CORNER_X <= 8'b00000000;
            CLOUD0_CORNER_Y <= 8'b00000000;
            CLOUD1_CORNER_Y <= 8'b00010000;
            CLOUD2_CORNER_Y <= 8'b01101000;
            CLOUD3_CORNER_Y <= 8'b10100100;
        end else begin
            CLOUD0_CORNER_X <= CLOUD0_CORNER_X + CLOUD0_STEP;
            CLOUD1_CORNER_X <= CLOUD1_CORNER_X + CLOUD1_STEP;
            CLOUD2_CORNER_X <= CLOUD2_CORNER_X + CLOUD2_STEP;
            CLOUD3_CORNER_X <= CLOUD3_CORNER_X + CLOUD3_STEP;
            CLOUD0_CORNER_Y <= 8'b00000000;
            CLOUD1_CORNER_Y <= 8'b00011000;
            CLOUD2_CORNER_Y <= 8'b01101000;
            CLOUD3_CORNER_Y <= 8'b10100100;
            if (CLOUD0_CORNER_X == 9'b100000000 + CLOUD0_X) CLOUD0_CORNER_X <= 9'b0;
            if (CLOUD1_CORNER_X == 9'b100000000 + CLOUD1_X) CLOUD1_CORNER_X <= 9'b0;
            if (CLOUD2_CORNER_X == 9'b100000000 + CLOUD2_X) CLOUD2_CORNER_X <= 9'b0;
            if (CLOUD3_CORNER_X == 9'b100000000 + CLOUD3_X) CLOUD3_CORNER_X <= 9'b0;
        end
    end

    always_comb begin
        if (Y > (CLOUD0_CORNER_Y) & Y < (CLOUD0_CORNER_Y + CLOUD0_Y) &
            X > (CLOUD0_CORNER_X) & X < (CLOUD0_CORNER_X + CLOUD0_X)) begin
            CLOUD_DATA = 4'h1;
        end else if (Y > (CLOUD1_CORNER_Y) & Y < (CLOUD1_CORNER_Y + CLOUD1_Y) &
            X > (CLOUD1_CORNER_X) & X < (CLOUD1_CORNER_X + CLOUD1_X)) begin
            CLOUD_DATA = 4'h1;
        end else if (Y > (CLOUD2_CORNER_Y) & Y < (CLOUD2_CORNER_Y + CLOUD2_Y) &
            X > (CLOUD2_CORNER_X) & X < (CLOUD2_CORNER_X + CLOUD2_X)) begin
            CLOUD_DATA = 4'h1;
        end else if (Y > (CLOUD3_CORNER_Y) & Y < (CLOUD3_CORNER_Y + CLOUD3_Y) &
            X > (CLOUD3_CORNER_X) & X < (CLOUD3_CORNER_X + CLOUD3_X)) begin
            CLOUD_DATA = 4'h1;
        end else begin
            CLOUD_DATA = 4'h0;
        end
    end
endmodule
