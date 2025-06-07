//-----------------------------------------------------------------------------
// pacman_ctrl.v
//   - �Ѹ��� 40��40 ũ��� ���������� �̵���Ű�� ���
//   - rstn=0 �� �߾�(940,520)���� �ʱ�ȭ
//   - frame_tick���� btn_pulse ������ STEP��ŭ �̵�
//   - ��(WALL)�� �ε����� �̵��� ���߰�, btn_pulse�� ����(= ƨ�� ����)
//-----------------------------------------------------------------------------

module pacman_ctrl (
    input  wire        clk_pix,       // 148.5 MHz pixel clock
    input  wire        rstn,          // active-low reset (�񵿱�)
    input  wire        frame_tick,    // �� �����Ӵ�(=VSYNC ���) 1�޽�
    input  wire [4:0]  btn_pulse,     // {UP, LEFT, MID, RIGHT, DOWN}

    // �� �浹 �˻��: ���� �Ѹ��� �̵��� �� ���� Ÿ�� �ּ� + �ڵ�
    input  wire [10:0] tile_addr,     // (0..48��27-1)
    input  wire [3:0]  tile_code,     // 0=BG, 1=WALL, 2=COIN

    output reg  [11:0] pac_x,         // �Ѹ� X (�ȼ�)
    output reg  [11:0] pac_y          // �Ѹ� Y (�ȼ�)
);

  //==================================================
  // 1) �Ķ���� ����
  //==================================================
  localparam SCR_W      = 1920;
  localparam SCR_H      = 1080;
  localparam PAC_SIZE   = 40;    // �Ѹ� ũ�� = 40��40
  localparam STEP       = 4;     // �� �����Ӵ� �̵� �ȼ� ��

  //==================================================
  // 2) ���� �� �߾� ��ġ
  //    �� (1920 - 40)/2 = 940, (1080 - 40)/2 = 520
  //==================================================
  always @(posedge clk_pix or negedge rstn) begin
    if (!rstn) begin
      pac_x <= (SCR_W - PAC_SIZE) >> 1;  // 940
      pac_y <= (SCR_H - PAC_SIZE) >> 1;  // 520
    end else if (frame_tick) begin
      //==================================================
      // 3) frame_tick���� btn_pulse �浹 �˻� �� �̵�
      //    - UP (btn_pulse[0])
      //    - LEFT (btn_pulse[1])
      //    - MID (btn_pulse[2]) �� ����
      //    - RIGHT (btn_pulse[3])
      //    - DOWN (btn_pulse[4])
      //    - �̵� ���� "�浹 �˻� �� tile_code==1�̸� ���� ��ġ�� �ǵ���"
      //==================================================

      // (3-1) UP
      if (btn_pulse[0]) begin
        // �ϴ� ������ �̵� �õ�
        if (pac_y >= STEP) 
          pac_y <= pac_y - STEP;
        else 
          pac_y <= 12'd0;

        // �̵� �� "Ÿ�� �浹 �˻�"
        if (tile_code == 4'd1) begin
          // WALL�� ��Ҵٸ�, �̵� ����(����ġ)���� ����
          pac_y <= pac_y + STEP; 
        end
      end

      // (3-2) LEFT
      else if (btn_pulse[1]) begin
        if (pac_x >= STEP) 
          pac_x <= pac_x - STEP;
        else 
          pac_x <= 12'd0;

        if (tile_code == 4'd1) begin
          pac_x <= pac_x + STEP;
        end
      end

      // (3-3) MID �� ���� (�ƹ� ���� ����)

      // (3-4) RIGHT
      else if (btn_pulse[3]) begin
        if (pac_x + STEP <= (SCR_W - PAC_SIZE)) 
          pac_x <= pac_x + STEP;
        else 
          pac_x <= (SCR_W - PAC_SIZE);

        if (tile_code == 4'd1) begin
          pac_x <= pac_x - STEP;
        end
      end

      // (3-5) DOWN
      else if (btn_pulse[4]) begin
        if (pac_y + STEP <= (SCR_H - PAC_SIZE)) 
          pac_y <= pac_y + STEP;
        else 
          pac_y <= (SCR_H - PAC_SIZE);

        if (tile_code == 4'd1) begin
          pac_y <= pac_y - STEP;
        end
      end

      // �ƹ� Ű�� �� �������� ����

    end
  end

endmodule
