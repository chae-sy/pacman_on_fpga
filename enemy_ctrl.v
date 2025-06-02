//-----------------------------------------------------------------------------
// enemy_ctrl_flat.v
//   - 4������ ��(Enemy)�� 40��40 ũ��� Ȯ���ϰ�, �������� �����̴� ���
//   - rstn=0 �Ǵ� game_reset=1 ��: �� �𼭸��� �ʱ�ȭ
//   - �� frame_tick���� STEP��ŭ ���� ���⡤���� �Ÿ��� �̵�
//   - Flat Bus ���: enemy0_x, enemy0_y, ��, enemy3_y 8�� ��Ʈ
//-----------------------------------------------------------------------------

module enemy_ctrl_flat (
    input  wire        clk_pix,       // 148.5 MHz pixel clock
    input  wire        rstn,          // active-low reset (�񵿱�)
    input  wire        frame_tick,    // �� ������(VSYNC ���)�� 1�޽�
    input  wire        game_reset,    // �浹 �� 1�� �Ǵ� ��ȣ

    // ���: 4���� ���� ���� ��� ��ǥ (12��Ʈ)
    output reg  [11:0] enemy0_x,      
    output reg  [11:0] enemy0_y,
    output reg  [11:0] enemy1_x,
    output reg  [11:0] enemy1_y,
    output reg  [11:0] enemy2_x,
    output reg  [11:0] enemy2_y,
    output reg  [11:0] enemy3_x,
    output reg  [11:0] enemy3_y
);

  //==================================================
  // 1) �Ķ���� �� ���� �������� ����
  //==================================================
  localparam SCR_W      = 1920;  // ȭ�� �ʺ�
  localparam SCR_H      = 1080;  // ȭ�� ����
  localparam ENEMY_SIZE = 40;    // �� ũ�� = 40��40
  localparam STEP       = 2;     // �� frame_tick�� �̵� �ȼ� ��

  // LFSR (16��Ʈ) �� ���� ������ ����
  reg [15:0] lfsr;
  wire       lfsr_fb = lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10];

  // �� ������ ���� "�̵� ����" (2��Ʈ: 00=Up, 01=Down, 10=Left, 11=Right)
  reg [1:0] dir0, dir1, dir2, dir3;

  // �� ������ "���� �̵� �Ÿ�" (6��Ʈ: 0~63)
  reg [5:0] dist0, dist1, dist2, dist3;


  //==================================================
  // 2) �ϳ��� always ��� �ȿ����� �������͸� ����̺�
  //    - rstn=0 �Ǵ� game_reset=1 ��: ���� �� �𼭸��� �ʱ�ȭ
  //    - �� ��: frame_tick=1 �̸� �̵�, �׷��� ������ �״�� Ȧ��
  //==================================================
  always @(posedge clk_pix or negedge rstn) begin
    if (!rstn) begin
      // ----------------------------------
      // (1) �ý��� ����(rstn=0) �� �ʱ�ȭ
      // ----------------------------------
      lfsr     <= 16'hABCD;  // �ʱ� LFSR �õ�

      // �� 4���� �� �𼭸��� ��ġ
      enemy0_x <= 12'd0;                   enemy0_y <= 12'd0;                    // ���� ��
      enemy1_x <= (SCR_W - ENEMY_SIZE);    enemy1_y <= 12'd0;                    // ������ ��
      enemy2_x <= 12'd0;                   enemy2_y <= (SCR_H - ENEMY_SIZE);     // ���� �Ʒ�
      enemy3_x <= (SCR_W - ENEMY_SIZE);    enemy3_y <= (SCR_H - ENEMY_SIZE);     // ������ �Ʒ�

      // �̵� ����/�Ÿ� �ʱ�ȭ(ù frame_tick���� �������� ����)
      dir0  <= 2'b00;  dist0 <= 6'd0;
      dir1  <= 2'b00;  dist1 <= 6'd0;
      dir2  <= 2'b00;  dist2 <= 6'd0;
      dir3  <= 2'b00;  dist3 <= 6'd0;

    end else if (game_reset) begin
      // ----------------------------------
      // (2) �浹 �߻� ��(game_reset=1) �� �ʱ�ȭ
      // ----------------------------------
      // ���� �� �𼭸��� �ǵ��� (LFSR �õ�� ����)
      enemy0_x <= 12'd0;                   enemy0_y <= 12'd0;
      enemy1_x <= (SCR_W - ENEMY_SIZE);    enemy1_y <= 12'd0;
      enemy2_x <= 12'd0;                   enemy2_y <= (SCR_H - ENEMY_SIZE);
      enemy3_x <= (SCR_W - ENEMY_SIZE);    enemy3_y <= (SCR_H - ENEMY_SIZE);

      // ����/�Ÿ��� �ٽ� 0���� ����
      dir0  <= 2'b00;  dist0 <= 6'd0;
      dir1  <= 2'b00;  dist1 <= 6'd0;
      dir2  <= 2'b00;  dist2 <= 6'd0;
      dir3  <= 2'b00;  dist3 <= 6'd0;

    end else begin
      // -----------------------------------
      // (3) "�� ��"�� ���: frame_tick ó��
      // -----------------------------------
      // (3-1) �� Ŭ������ LFSR ������Ʈ
      lfsr <= { lfsr[14:0], lfsr_fb };

      if (frame_tick) begin
        // =========================
        //   (3-2) �� 0 �̵�
        // =========================
        if (dist0 == 6'd0) begin
          // �� ���� ����/�Ÿ� �̱�
          dir0  <= lfsr[15:14];
          dist0 <= lfsr[13:8];

          // ���� �������� ��� STEP��ŭ �̵�
          case (lfsr[15:14])
            2'b00: begin // UP
              if (enemy0_y >= STEP) 
                enemy0_y <= enemy0_y - STEP;
              else 
                enemy0_y <= 12'd0;
            end
            2'b01: begin // DOWN
              if (enemy0_y + ENEMY_SIZE + STEP <= SCR_H) 
                enemy0_y <= enemy0_y + STEP;
              else 
                enemy0_y <= (SCR_H - ENEMY_SIZE);
            end
            2'b10: begin // LEFT
              if (enemy0_x >= STEP) 
                enemy0_x <= enemy0_x - STEP;
              else 
                enemy0_x <= 12'd0;
            end
            2'b11: begin // RIGHT
              if (enemy0_x + ENEMY_SIZE + STEP <= SCR_W) 
                enemy0_x <= enemy0_x + STEP;
              else 
                enemy0_x <= (SCR_W - ENEMY_SIZE);
            end
          endcase

          // ���� �Ÿ����� 1��ŭ ����
          dist0 <= (lfsr[13:8] > 0) ? (lfsr[13:8] - 6'd1) : 6'd0;

        end else begin
          // dist0 != 0 �� ������ ������ dir0 �������� STEP��ŭ �̵�
          case (dir0)
            2'b00: begin // UP
              if (enemy0_y >= STEP) 
                enemy0_y <= enemy0_y - STEP;
              else 
                enemy0_y <= 12'd0;
            end
            2'b01: begin // DOWN
              if (enemy0_y + ENEMY_SIZE + STEP <= SCR_H) 
                enemy0_y <= enemy0_y + STEP;
              else 
                enemy0_y <= (SCR_H - ENEMY_SIZE);
            end
            2'b10: begin // LEFT
              if (enemy0_x >= STEP) 
                enemy0_x <= enemy0_x - STEP;
              else 
                enemy0_x <= 12'd0;
            end
            2'b11: begin // RIGHT
              if (enemy0_x + ENEMY_SIZE + STEP <= SCR_W) 
                enemy0_x <= enemy0_x + STEP;
              else 
                enemy0_x <= (SCR_W - ENEMY_SIZE);
            end
          endcase
          dist0 <= dist0 - 6'd1;
        end


        // =========================
        //   (3-3) �� 1 �̵�
        // =========================
        if (dist1 == 6'd0) begin
          dir1  <= lfsr[15:14];
          dist1 <= lfsr[13:8];
          case (lfsr[15:14])
            2'b00: begin // UP
              if (enemy1_y >= STEP) 
                enemy1_y <= enemy1_y - STEP;
              else 
                enemy1_y <= 12'd0;
            end
            2'b01: begin // DOWN
              if (enemy1_y + ENEMY_SIZE + STEP <= SCR_H) 
                enemy1_y <= enemy1_y + STEP;
              else 
                enemy1_y <= (SCR_H - ENEMY_SIZE);
            end
            2'b10: begin // LEFT
              if (enemy1_x >= STEP) 
                enemy1_x <= enemy1_x - STEP;
              else 
                enemy1_x <= 12'd0;
            end
            2'b11: begin // RIGHT
              if (enemy1_x + ENEMY_SIZE + STEP <= SCR_W) 
                enemy1_x <= enemy1_x + STEP;
              else 
                enemy1_x <= (SCR_W - ENEMY_SIZE);
            end
          endcase
          dist1 <= (lfsr[13:8] > 0) ? (lfsr[13:8] - 6'd1) : 6'd0;

        end else begin
          case (dir1)
            2'b00: begin // UP
              if (enemy1_y >= STEP) 
                enemy1_y <= enemy1_y - STEP;
              else 
                enemy1_y <= 12'd0;
            end
            2'b01: begin // DOWN
              if (enemy1_y + ENEMY_SIZE + STEP <= SCR_H) 
                enemy1_y <= enemy1_y + STEP;
              else 
                enemy1_y <= (SCR_H - ENEMY_SIZE);
            end
            2'b10: begin // LEFT
              if (enemy1_x >= STEP) 
                enemy1_x <= enemy1_x - STEP;
              else 
                enemy1_x <= 12'd0;
            end
            2'b11: begin // RIGHT
              if (enemy1_x + ENEMY_SIZE + STEP <= SCR_W) 
                enemy1_x <= enemy1_x + STEP;
              else 
                enemy1_x <= (SCR_W - ENEMY_SIZE);
            end
          endcase
          dist1 <= dist1 - 6'd1;
        end


        // =========================
        //   (3-4) �� 2 �̵�
        // =========================
        if (dist2 == 6'd0) begin
          dir2  <= lfsr[15:14];
          dist2 <= lfsr[13:8];
          case (lfsr[15:14])
            2'b00: begin // UP
              if (enemy2_y >= STEP) 
                enemy2_y <= enemy2_y - STEP;
              else 
                enemy2_y <= 12'd0;
            end
            2'b01: begin // DOWN
              if (enemy2_y + ENEMY_SIZE + STEP <= SCR_H) 
                enemy2_y <= enemy2_y + STEP;
              else 
                enemy2_y <= (SCR_H - ENEMY_SIZE);
            end
            2'b10: begin // LEFT
              if (enemy2_x >= STEP) 
                enemy2_x <= enemy2_x - STEP;
              else 
                enemy2_x <= 12'd0;
            end
            2'b11: begin // RIGHT
              if (enemy2_x + ENEMY_SIZE + STEP <= SCR_W) 
                enemy2_x <= enemy2_x + STEP;
              else 
                enemy2_x <= (SCR_W - ENEMY_SIZE);
            end
          endcase
          dist2 <= (lfsr[13:8] > 0) ? (lfsr[13:8] - 6'd1) : 6'd0;

        end else begin
          case (dir2)
            2'b00: begin // UP
              if (enemy2_y >= STEP) 
                enemy2_y <= enemy2_y - STEP;
              else 
                enemy2_y <= 12'd0;
            end
            2'b01: begin // DOWN
              if (enemy2_y + ENEMY_SIZE + STEP <= SCR_H) 
                enemy2_y <= enemy2_y + STEP;
              else 
                enemy2_y <= (SCR_H - ENEMY_SIZE);
            end
            2'b10: begin // LEFT
              if (enemy2_x >= STEP) 
                enemy2_x <= enemy2_x - STEP;
              else 
                enemy2_x <= 12'd0;
            end
            2'b11: begin // RIGHT
              if (enemy2_x + ENEMY_SIZE + STEP <= SCR_W) 
                enemy2_x <= enemy2_x + STEP;
              else 
                enemy2_x <= (SCR_W - ENEMY_SIZE);
            end
          endcase
          dist2 <= dist2 - 6'd1;
        end


        // =========================
        //   (3-5) �� 3 �̵�
        // =========================
        if (dist3 == 6'd0) begin
          dir3  <= lfsr[15:14];
          dist3 <= lfsr[13:8];
          case (lfsr[15:14])
            2'b00: begin // UP
              if (enemy3_y >= STEP) 
                enemy3_y <= enemy3_y - STEP;
              else 
                enemy3_y <= 12'd0;
            end
            2'b01: begin // DOWN
              if (enemy3_y + ENEMY_SIZE + STEP <= SCR_H) 
                enemy3_y <= enemy3_y + STEP;
              else 
                enemy3_y <= (SCR_H - ENEMY_SIZE);
            end
            2'b10: begin // LEFT
              if (enemy3_x >= STEP) 
                enemy3_x <= enemy3_x - STEP;
              else 
                enemy3_x <= 12'd0;
            end
            2'b11: begin // RIGHT
              if (enemy3_x + ENEMY_SIZE + STEP <= SCR_W) 
                enemy3_x <= enemy3_x + STEP;
              else 
                enemy3_x <= (SCR_W - ENEMY_SIZE);
            end
          endcase
          dist3 <= (lfsr[13:8] > 0) ? (lfsr[13:8] - 6'd1) : 6'd0;

        end else begin
          case (dir3)
            2'b00: begin // UP
              if (enemy3_y >= STEP) 
                enemy3_y <= enemy3_y - STEP;
              else 
                enemy3_y <= 12'd0;
            end
            2'b01: begin // DOWN
              if (enemy3_y + ENEMY_SIZE + STEP <= SCR_H) 
                enemy3_y <= enemy3_y + STEP;
              else 
                enemy3_y <= (SCR_H - ENEMY_SIZE);
            end
            2'b10: begin // LEFT
              if (enemy3_x >= STEP) 
                enemy3_x <= enemy3_x - STEP;
              else 
                enemy3_x <= 12'd0;
            end
            2'b11: begin // RIGHT
              if (enemy3_x + ENEMY_SIZE + STEP <= SCR_W) 
                enemy3_x <= enemy3_x + STEP;
              else 
                enemy3_x <= (SCR_W - ENEMY_SIZE);
            end
          endcase
          dist3 <= dist3 - 6'd1;
        end

      end else begin
        // frame_tick = 0 �� ���: �� ��ǥ�� dir/dist ��� �״�� ����
        enemy0_x <= enemy0_x;  enemy0_y <= enemy0_y;
        enemy1_x <= enemy1_x;  enemy1_y <= enemy1_y;
        enemy2_x <= enemy2_x;  enemy2_y <= enemy2_y;
        enemy3_x <= enemy3_x;  enemy3_y <= enemy3_y;

        dir0  <= dir0;   dist0 <= dist0;
        dir1  <= dir1;   dist1 <= dist1;
        dir2  <= dir2;   dist2 <= dist2;
        dir3  <= dir3;   dist3 <= dist3;
      end
    end
  end

endmodule
