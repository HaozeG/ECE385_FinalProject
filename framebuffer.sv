module framebuffer_double #(
    parameter DATA_WIDTH = 4,
    parameter ADDR_WIDTH = 16
) (
    input                       CLK,
    RESET,
    SEL_CLK,
    RENDER_EN,
    input  [(ADDR_WIDTH - 1):0] addr_read,
    input  [(DATA_WIDTH - 1):0] FB_IN,
    input  [(ADDR_WIDTH - 1):0] RENDER_INDEX,
    output [(DATA_WIDTH - 1):0] FB_OUT

);
    logic [(DATA_WIDTH - 1):0] BUFFER_IN, BUFFER_WRITE_OUT, BUFFER_WRITE_OUT_0, BUFFER_WRITE_OUT_1;
    logic BUFFER_WE;
    // output from frame_buffer
    logic [(DATA_WIDTH - 1):0] BUFFER_OUT_0, BUFFER_OUT_1, BUFFER_OUT;

    logic BUFFER_SEL;

    always_ff @(posedge SEL_CLK or posedge RESET) begin
        if (RESET) begin
            BUFFER_SEL <= 1'b0;
        end else begin
            BUFFER_SEL <= ~BUFFER_SEL;
        end
    end

    always_comb begin : SWITCH_BUFFER
        if (BUFFER_SEL) BUFFER_OUT = BUFFER_OUT_0;
        else BUFFER_OUT = BUFFER_OUT_1;
    end

    assign BUFFER_IN = FB_IN;
    assign FB_OUT    = BUFFER_OUT;

    assign BUFFER_WE = RENDER_EN;

    // create double buffers
    framebuffer_ram #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_framebuffer_0 (
        .data_write(BUFFER_IN),
        .addr_write(RENDER_INDEX),
        .addr_read (addr_read),
        .we_write  (BUFFER_WE & BUFFER_SEL),
        .clk       (CLK),
        .q_read    (BUFFER_OUT_0)
    );

    framebuffer_ram #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_framebuffer_1 (
        .data_write(BUFFER_IN),
        .addr_write(RENDER_INDEX),
        .addr_read (addr_read),
        .we_write  (BUFFER_WE & !BUFFER_SEL),
        .clk       (CLK),
        .q_read    (BUFFER_OUT_1)
    );
endmodule


// Quartus Prime Verilog Template
// True Dual Port RAM with single clock
module framebuffer_ram #(
    parameter DATA_WIDTH = 4,
    parameter ADDR_WIDTH = 16
) (
    input      [(DATA_WIDTH-1):0] data_write,
    input      [(ADDR_WIDTH-1):0] addr_write,
    addr_read,
    input                         we_write,
    clk,
    output reg [(DATA_WIDTH-1):0] q_read
);

    // Declare the RAM variable
    reg [DATA_WIDTH-1:0] ram[2**ADDR_WIDTH-1:0];

    // Port A
    always @(posedge clk) begin
        if (we_write) begin
            ram[addr_write] <= data_write;
        end
    end

    // Port B
    always @(posedge clk) begin
        q_read <= ram[addr_read];
    end

endmodule
