//-----------------------------------------------------------------------------
// mouth_anim.v
//   vsync rising edge �� ���� mouth_state ���
//-----------------------------------------------------------------------------
module mouth_anim (
  input  wire clk_pix,     // �ȼ� Ŭ�� (148.5 MHz)
  input  wire rstn,        // active-low reset
  input  wire vsync,       // VGA ��Ʈ�ѷ��κ��� vertical sync
  output reg  mouth_state  // 1=open, 0=closed
);

  reg vsync_d;

  always @(posedge clk_pix or negedge rstn) begin
    if (!rstn) begin
      vsync_d     <= 1'b0;
      mouth_state <= 1'b0;     // ���� �� ���� ������ ����
    end else begin
      // 1) vsync rising edge ����
      vsync_d <= vsync;
      if (~vsync_d & vsync) begin
        mouth_state <= ~mouth_state;  // �� �����Ӹ��� ���
      end
    end
  end

endmodule
