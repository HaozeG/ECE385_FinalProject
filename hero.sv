module hero (
    input               CLK,
    RESET,
    HERO_RESET,
    input  logic [15:0] HERO_COORD,
    input  logic [ 2:0] HERO_INDEX_IN,
    output logic [ 6:0] HERO_INDEX,
    input  logic [ 7:0] HERO_X,
    HERO_Y
);
    logic [7:0] DRAW_X, DRAW_Y;
    assign DRAW_Y = HERO_COORD[15:8];
    assign DRAW_X = HERO_COORD[7:0];

    logic [6:0] HERO_INDEX_0;
    // Change apperance base on WASD
    always_ff @(posedge CLK or posedge RESET) begin
        if (RESET) begin
            HERO_INDEX_0 = 7'b0000001;
        end else begin
            HERO_INDEX_0 <= {4'b0000, HERO_INDEX_IN};
        end
    end

    // logic [7:0] cnt;
    // always_ff @(posedge CLK) begin
    //     cnt <= cnt + 1;
    // end

    // // always_ff @(posedge CLK or posedge HERO_RESET or posedge RESET) begin
    // //     if (RESET) begin
    // //         HERO_X <= 8'd020;
    // //     end else begin
    // //         HERO_X <= HERO_X + 1;
    // //     end
    // // end
    // // assign HERO_X = 8'd020 + cnt;
    // // assign HERO_Y = 8'd020;

    always_comb begin
        if (DRAW_X >= HERO_X & DRAW_X <= HERO_X + 15 & DRAW_Y >= HERO_Y & DRAW_Y <= HERO_Y + 15) begin
            HERO_INDEX = HERO_INDEX_0;
        end else begin
            HERO_INDEX = 7'b0000000;
        end
    end



endmodule

