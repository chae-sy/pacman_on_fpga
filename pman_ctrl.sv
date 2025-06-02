//-----------------------------------------------------------------------------
// pacman_ctrl.v  (������)
//-----------------------------------------------------------------------------

module pacman_ctrl (
    input  wire        clk_pix,      // 148.5 MHz pixel clock
    input  wire        rstn,         // active-low reset
    input  wire        frame_tick,   // �� �����Ӹ��� 1 Ŭ�� �޽� (VSYNC Ÿ�̹�)
    input  wire [4:0]  btn_pulse,    // {UP, LEFT, MID, RIGHT, DOWN}
    input  wire        game_reset,   // �浹 �� ���� ���� ��ȣ

    output reg  [11:0] pac_x,        // �Ѹ� X ��ǥ (�ȼ�, ���� ��� ����)
    output reg  [11:0] pac_y         // �Ѹ� Y ��ǥ (�ȼ�, ���� ��� ����)
);

  // �̵� �ӵ� (�ȼ�)
  localparam STEP     = 4;
  // ��������Ʈ ũ�� (40��40)
  localparam SPRITE_W = 40;
  localparam SPRITE_H = 40;
  // ȭ�� �ػ�
  localparam SCR_W    = 1920;
  localparam SCR_H    = 1080;
  // �Ѹ� �ʱ� ��ġ = (���� �߾�, ���� �߾�)
  localparam INIT_X   = (SCR_W - SPRITE_W)/2; //  (1920-40)/2 = 940
  localparam INIT_Y   = (SCR_H - SPRITE_H)/2; //  (1080-40)/2 = 520

  always @(posedge clk_pix or negedge rstn) begin
    if (!rstn || game_reset) begin
      // �ý��� ���� Ȥ�� ���� ���� �� �� �Ѹ� �ʱ� ��ġ
      pac_x <= INIT_X;
      pac_y <= INIT_Y;
    end else if (frame_tick) begin
      // ������ ��� �� �� ���� �̵� ó��
      // UP
      if (btn_pulse[0]) begin
        if (pac_y >= STEP)
          pac_y <= pac_y - STEP;
        else
          pac_y <= 0;
      end
      // LEFT
      if (btn_pulse[1]) begin
        if (pac_x >= STEP)
          pac_x <= pac_x - STEP;
        else
          pac_x <= 0;
      end
      // MID (����) �� �ƹ� ���� ����

      // RIGHT
      if (btn_pulse[3]) begin
        if (pac_x + STEP <= SCR_W - SPRITE_W)
          pac_x <= pac_x + STEP;
        else
          pac_x <= SCR_W - SPRITE_W;
      end

      // DOWN
      if (btn_pulse[4]) begin
        if (pac_y + STEP <= SCR_H - SPRITE_H)
          pac_y <= pac_y + STEP;
        else
          pac_y <= SCR_H - SPRITE_H;
      end
    end
    // �� ��(�������� �ƴ� ��)�� pac_x, pac_y ����
  end

endmodule
