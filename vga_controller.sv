//-----------------------------------------------------------------------------
// vga_controller_1080p.v
//   VGA controller for 1920¡¿1080 @60 Hz (analog VGA)
//   pixel clock: clk_pix (148.5 MHz)
//-----------------------------------------------------------------------------
module vga_controller_1080p (
    input  wire        clk_pix,    // 148.5 MHz pixel clock
    input  wire        rstn,       // active-low reset
    output wire        hsync,      // HSYNC (active low)
    output wire        vsync,      // VSYNC (active low)
    output wire        video_on,   // high during visible area
    output wire [11:0] pixel_x,    // 0¡¦1919
    output wire [11:0] pixel_y     // 0¡¦1079
);

    // timing parameters for 1080p60
    localparam H_VIS   = 1920;
    localparam H_FP    =   88;
    localparam H_SYNC  =   44;
    localparam H_BP    =  148;
    localparam H_TOT   = H_VIS + H_FP + H_SYNC + H_BP; // 2200

    localparam V_VIS   = 1080;
    localparam V_FP    =    4;
    localparam V_SYNC  =    5;
    localparam V_BP    =   36;
    localparam V_TOT   = V_VIS + V_FP + V_SYNC + V_BP; // 1125

    reg [11:0] h_cnt, v_cnt;

    // horizontal counter
    always @(posedge clk_pix or negedge rstn) begin
        if (!rstn)                 h_cnt <= 0;
        else if (h_cnt == H_TOT-1) h_cnt <= 0;
        else                       h_cnt <= h_cnt + 1;
    end

    // vertical counter
    always @(posedge clk_pix or negedge rstn) begin
        if (!rstn)                     v_cnt <= 0;
        else if (h_cnt == H_TOT-1) begin
            if (v_cnt == V_TOT-1)      v_cnt <= 0;
            else                       v_cnt <= v_cnt + 1;
        end
    end

    // sync & valid
    assign hsync    = ~((h_cnt >= (H_VIS + H_FP)) &&
                        (h_cnt <  (H_VIS + H_FP + H_SYNC)));
    assign vsync    = ~((v_cnt >= (V_VIS + V_FP)) &&
                        (v_cnt <  (V_VIS + V_FP + V_SYNC)));
    assign video_on = (h_cnt < H_VIS) && (v_cnt < V_VIS);

    assign pixel_x  = (h_cnt < H_VIS) ? h_cnt : 12'd0;
    assign pixel_y  = (v_cnt < V_VIS) ? v_cnt : 12'd0;

endmodule
