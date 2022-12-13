module renderer (
    input               CLK,
    RESET,
    vs,
    // MULTIPLE LAYERS
    // CLOUD
    output       [15:0] CLOUD_COORD,
    input        [ 3:0] CLOUD_DATA,
    // MAP
    output logic [ 1:0] SPRITE_SEL,
    output       [15:0] MAP_COORD,
    input        [ 3:0] MAP_DATA,
    // HERO
    output       [15:0] HERO_COORD,
    input        [ 3:0] HERO_DATA,
    output logic        RENDER_EN,
    output logic [15:0] RENDER_DATA,
    output logic [ 8:0] RENDER_X,
    RENDER_Y
);

    logic COUNTER_EN;
    logic [8:0] counterxsig, counterysig;
    assign RENDER_X    = counterxsig;
    assign RENDER_Y    = counterysig;
    // blending RENDER_DATA

    assign CLOUD_COORD = {counterysig[7:0], counterxsig[7:0]} - 2;
    assign MAP_COORD   = {counterysig[7:0], counterxsig[7:0]} - 2;
    assign HERO_COORD  = {counterysig[7:0], counterxsig[7:0]} - 2;


    logic       temp;
    logic [8:0] cnt;

    always_ff @(negedge vs) begin
        // temp <= ~temp;
        temp <= 0;
        cnt  <= cnt + 1;
        //     RENDER_START <= 1;
        //     // if (curr_state == FINISH) RENDER_START <= 0;
    end


    // control render start
    logic RENDER_START;
    always_comb begin
        if (!vs) RENDER_START = 1;
        else RENDER_START = 0;
    end

    // FSM
    enum logic [3:0] {
        IDLE,
        CLEAR,
        WRITE_CLOUD_0,
        WRITE_CLOUD,
        WRITE_MAP_0,
        WRITE_MAP,
        WRITE_HERO_0,
        WRITE_HERO,
        FINISH
    }
        curr_state, next_state;

    always_ff @(posedge CLK) begin
        if (RESET) curr_state <= IDLE;
        else curr_state <= next_state;

    end

    always_comb begin
        next_state = curr_state;
        unique case (curr_state)
            IDLE: if (RENDER_START) next_state = CLEAR;
            CLEAR: if (counterysig == 256) next_state = WRITE_CLOUD_0;
            WRITE_CLOUD_0: next_state = WRITE_CLOUD;
            WRITE_CLOUD: if (counterysig == 256) next_state = WRITE_MAP_0;
            // WRITE_CLOUD: if (counterysig == 256) next_state = WRITE_HERO_0;
            WRITE_MAP_0: next_state = WRITE_MAP;
            WRITE_MAP: if (counterysig == 256) next_state = WRITE_HERO_0;
            WRITE_HERO_0: next_state = WRITE_HERO;
            WRITE_HERO: if (counterysig == 256) next_state = FINISH;
            FINISH: next_state = IDLE;
        endcase

        case (curr_state)
            IDLE: begin
                RENDER_DATA = 0;
                COUNTER_EN  = 0;
                RENDER_EN   = 0;
                SPRITE_SEL  = 2'b00;  //01: MAP; 10: HERO
            end
            CLEAR: begin
                RENDER_DATA = 4'h0;
                COUNTER_EN  = 1;
                RENDER_EN   = 1;
                SPRITE_SEL  = 2'b00;  //01: MAP; 10: HERO
            end
            WRITE_CLOUD_0: begin
                RENDER_DATA = 0;
                COUNTER_EN  = 0;
                RENDER_EN   = 0;
                SPRITE_SEL  = 2'b00;  //01: MAP; 10: HERO
            end
            WRITE_CLOUD: begin
                RENDER_DATA = CLOUD_DATA;
                COUNTER_EN  = 1;
                RENDER_EN   = (RENDER_DATA == 4'h0 ? 0 : 1);  // Skip transparent pixels
                SPRITE_SEL  = 2'b00;  //01: MAP; 10: HERO
            end
            WRITE_MAP_0: begin
                RENDER_DATA = 0;
                COUNTER_EN  = 0;
                RENDER_EN   = 0;
                SPRITE_SEL  = 2'b00;  //01: MAP; 10: HERO
            end
            WRITE_MAP: begin
                RENDER_DATA = MAP_DATA;
                COUNTER_EN  = 1;
                RENDER_EN   = (RENDER_DATA == 4'h0 ? 0 : 1);
                SPRITE_SEL  = 2'b01;  //01: MAP; 10: HERO
            end
            WRITE_HERO_0: begin
                RENDER_DATA = 0;
                COUNTER_EN  = 0;
                RENDER_EN   = 0;
                SPRITE_SEL  = 2'b00;  //01: MAP; 10: HERO
            end
            WRITE_HERO: begin
                RENDER_DATA = HERO_DATA;
                COUNTER_EN  = 1;
                RENDER_EN   = (RENDER_DATA == 4'h0 ? 0 : 1);
                SPRITE_SEL  = 2'b10;  //01: MAP; 10: HERO
            end
            default: begin
                RENDER_DATA = 0;
                COUNTER_EN  = 0;
                RENDER_EN   = 0;
                SPRITE_SEL  = 2'b00;  //01: MAP; 10: HERO
            end
        endcase
    end

    //Runs the horizontal counter  when it resets vertical counter is incremented
    always_ff @(posedge CLK or posedge RESET or negedge COUNTER_EN) begin : counter_proc
        if (RESET | !COUNTER_EN) begin
            counterxsig <= 9'b000000000;
            counterysig <= 9'b000000000;
        end else begin
            counterysig <= counterysig;
            if ( counterxsig == 255 )  //If counterxsig has reached the end of pixel count
            begin
                counterxsig <= 9'b000000000;
                counterysig <= (counterysig + 1);
            end else
                counterxsig <= (counterxsig + 1);  //no statement about counterysig, implied counterysig <= counterysig;
        end
    end


endmodule
