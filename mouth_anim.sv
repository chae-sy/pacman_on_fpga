//-----------------------------------------------------------------------------
// mouth_anim.v
//   vsync rising edge 에 따라 mouth_state 토글
//-----------------------------------------------------------------------------
module mouth_anim (
  input  wire clk_pix,     // 픽셀 클럭 (148.5 MHz)
  input  wire rstn,        // active-low reset
  input  wire vsync,       // VGA 컨트롤러로부터 vertical sync
  output reg  mouth_state  // 1=open, 0=closed
);

  reg vsync_d;

  always @(posedge clk_pix or negedge rstn) begin
    if (!rstn) begin
      vsync_d     <= 1'b0;
      mouth_state <= 1'b0;     // 리셋 후 닫힌 입으로 시작
    end else begin
      // 1) vsync rising edge 검출
      vsync_d <= vsync;
      if (~vsync_d & vsync) begin
        mouth_state <= ~mouth_state;  // 한 프레임마다 토글
      end
    end
  end

endmodule
