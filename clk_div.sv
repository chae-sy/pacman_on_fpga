// clock_divider.v
//  100MHz ¡æ ~25MHz (¡À4)
module clock_divider (
    input  wire clk_in,
    input  wire rst_n,
    output reg  clk_out
);
    reg [1:0] cnt;
    always @(posedge clk_in or negedge rst_n) begin
        if (!rst_n) begin
            cnt     <= 0;
            clk_out <= 0;
        end else begin
            cnt <= cnt + 1;
            if (cnt == 2'd1) begin
                clk_out <= ~clk_out;
            end
        end
    end
endmodule
