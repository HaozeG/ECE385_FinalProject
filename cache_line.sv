// Quartus Prime Verilog Template
// True Dual Port RAM with single clock
// cache for a whole line output (256 pixels * 16bits/pixel(extend from 12bits))

module cache_line (
    input         clk_a,
    clk_b,
    blank,
    RESET,
    input  [15:0] data_a,
    input  [ 7:0] addr_b,
    output [15:0] q_b,
    output [ 7:0] cache_lineX_0
);
    // CACHE_LINE write
    logic [8:0] cache_lineX;
    logic       cache_lineWE;

    assign cache_lineX_0 = cache_lineX;

    // FSM to control CACHE_LINE write
    enum logic {
        IDLE,
        WRITE
    }
        curr_state, next_state;

    always_ff @(posedge clk_a) begin
        if (RESET) curr_state <= IDLE;
        else curr_state <= next_state;

        // enumerate cache_lineX
        if (curr_state == WRITE) cache_lineX <= cache_lineX + 1'b1;
        if (blank) cache_lineX <= 0;
    end

    always_comb begin
        next_state = curr_state;
        unique case (curr_state)
            IDLE:  if (!blank & cache_lineX == 9'h00) next_state = WRITE;
            WRITE: if (cache_lineX == 9'h0FF) next_state = IDLE;
        endcase

        case (curr_state)
            IDLE: begin
                cache_lineWE = 0;
            end
            WRITE: begin
                cache_lineWE = 1;
            end
            default: begin
                cache_lineWE = 0;
            end
        endcase
    end

    cache_line_ram u_cache_line_ram (
        .data_a,
        .data_b(16'b0),
        .addr_a(cache_lineX[7:0]),
        .addr_b,
        .we_a  (cache_lineWE),
        .we_b  (1'b0),
        .clk_a,
        .clk_b,
        .q_b (q_b)
    );

endmodule




module cache_line_ram #(
    parameter DATA_WIDTH = 16,
    parameter ADDR_WIDTH = 8
) (
    input      [(DATA_WIDTH-1):0] data_a,
    data_b,
    input      [(ADDR_WIDTH-1):0] addr_a,
    addr_b,
    input                         we_a,
    we_b,
    clk_a,
    clk_b,
    output reg [(DATA_WIDTH-1):0] q_a,
    q_b
);

    // Declare the RAM variable
    reg [DATA_WIDTH-1:0] ram[2**ADDR_WIDTH-1:0];

    always @(posedge clk_a) begin
        // Port A
        if (we_a) begin
            ram[addr_a] <= data_a;
            q_a         <= data_a;
        end else begin
            q_a <= ram[addr_a];
        end
    end

    always @(posedge clk_b) begin
        // Port B
        if (we_b) begin
            ram[addr_b] <= data_b;
            q_b         <= data_b;
        end else begin
            q_b <= ram[addr_b];
        end
    end


endmodule
