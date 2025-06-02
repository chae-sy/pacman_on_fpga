//-----------------------------------------------------------------------------
// top_1080p_vga.v
//   - �Ѹ�(pacman_ctrl), ��� Ÿ�ϸ�, �� 4����(enemy_ctrl_flat) ����
//   - �浹 ���� �� ���� ����
//   - ��(Enemy)�� ���� ���(40��40 ����: �� �Ӹ� + �ٸ� 4��)���� �׷���
//   - VGA ���: 1920��1080 @60Hz
//-----------------------------------------------------------------------------

module top_1080p_vga (
    input  wire        sys_clk_100m,   // 100 MHz board clock
    input  wire        rstn,           // active-low reset
    
    // VGA ��� ��
    output wire [3:0]  vga_r,
    output wire [3:0]  vga_g,
    output wire [3:0]  vga_b,
    output wire        vga_hs,
    output wire        vga_vs,

    // ��ư �Է� (5�� ����ġ)
    input  sw_up,
    input  sw_left,
    input  sw_mid,
    input  sw_right,
    input  sw_down,

    // ����׿� LED
    //   led1: frame_tick ��� Ȯ��(�� 60Hz)
    //   led2: �Ѹ�+�� �浹 ǥ��
    output led1,
    output led2
);

  //==================================================
  // 1) Clocking Wizard �� 148.5 MHz pixel clock ����
  //==================================================
  wire clk_pix, clk_locked;
  clk_wiz_0 u_clk (
    .clk_in1  (sys_clk_100m),
    .resetn   (rstn),
    .clk_pix  (clk_pix),
    .locked   (clk_locked)
  );
  wire active = rstn & clk_locked;

  //==================================================
  // 2) VGA Timing Generator (1920��1080 @60Hz)
  //==================================================
  wire        video_on;
  wire [11:0] pixel_x, pixel_y;
  vga_controller_1080p u_vga (
    .clk_pix   (clk_pix),
    .rstn      (active),
    .hsync     (vga_hs),
    .vsync     (vga_vs),
    .video_on  (video_on),
    .pixel_x   (pixel_x),
    .pixel_y   (pixel_y)
  );

  //==================================================
  // 3) ��ư IF & frame_tick ����
  //==================================================
  wire [4:0] btn_pulse;
  button u_btn (
    .clk      (clk_pix),
    .reset    (active),
    .sw_up    (sw_up),
    .sw_left  (sw_left),
    .sw_mid   (sw_mid),
    .sw_right (sw_right),
    .sw_down  (sw_down),
    // button ��� �� LED�� ������� �����Ƿ� ��� ���� ����
    .led1     (),
    .led2     (),
    .led3     (),
    .led4     (),
    .led5     ()
  );
  assign btn_pulse = {sw_up, sw_left, sw_mid, sw_right, sw_down};

  reg vsync_d;
  always @(posedge clk_pix) vsync_d <= vga_vs;
  // VSYNC ��� �������� 1�޽� ����
  wire frame_tick = (~vsync_d & vga_vs) & active;

  // frame_tick �����: LED1 ��� (�� 60Hz ������)
  reg frame_led;
  always @(posedge clk_pix or negedge rstn) begin
    if (!rstn)
      frame_led <= 1'b0;
    else if (frame_tick)
      frame_led <= ~frame_led;
  end
  assign led1 = frame_led;


  //==================================================
  // 4) Pac-Man control (�Ѹ� ���� �� �ʱ�ȭ)
  //    - game_reset=1 �� �Ѹ��� �߾����� ����
  //==================================================
  wire [11:0] pac_x, pac_y;
  wire        game_reset;

  pacman_ctrl u_pac (
    .clk_pix    (clk_pix),
    .rstn       (active),
    .frame_tick (frame_tick),
    .btn_pulse  (btn_pulse),
    .game_reset (game_reset),
    .pac_x      (pac_x),
    .pac_y      (pac_y)
  );


  //==================================================
  // 5) ��� Ÿ�ϸ� (48��27 Ÿ��, �� Ÿ�� 40��40)
  //==================================================
  localparam MAP_W  = 48, MAP_H = 27;
  localparam H_VIS  = 1920, V_VIS = 1080;
  localparam TILE_W = H_VIS / MAP_W;   // 40
  localparam TILE_H = V_VIS / MAP_H;   // 40

  wire [5:0] tile_x = pixel_x / TILE_W;  // 0..47
  wire [4:0] tile_y = pixel_y / TILE_H;  // 0..26
  wire [10:0] tile_addr = tile_y * MAP_W + tile_x;

  wire [3:0] tile_code;
  blk_mem_gen_0 u_map (
    .clka  (clk_pix),
    .ena   (video_on),
    .addra (tile_addr),
    .douta (tile_code)
  );

  localparam [11:0]
    WALL     = 12'hF00,  // �� ��(����)
    COIN     = 12'hF70,  // ���� ��(���-��Ȳ)
    BG_COLOR = 12'h000;  // ��� ��(����)

  wire [11:0] tile_color = (tile_code == 4'd1) ? WALL :
                           (tile_code == 4'd2) ? COIN :
                                                 BG_COLOR;


  //==================================================
  // 6) �� 4����(enemy_ctrl_flat) ����
  //==================================================
  wire [11:0] e0_x, e0_y, e1_x, e1_y, e2_x, e2_y, e3_x, e3_y;

  enemy_ctrl_flat u_enemy (
    .clk_pix     (clk_pix),
    .rstn        (active),
    .frame_tick  (frame_tick),
    .game_reset  (game_reset),

    .enemy0_x    (e0_x),
    .enemy0_y    (e0_y),
    .enemy1_x    (e1_x),
    .enemy1_y    (e1_y),
    .enemy2_x    (e2_x),
    .enemy2_y    (e2_y),
    .enemy3_x    (e3_x),
    .enemy3_y    (e3_y)
  );


  //==================================================
  // 7) �浹 ���� �� game_reset ����
  //==================================================
  localparam ENEMY_SIZE = 40;  // �� ũ��

  wire coll0 = (pac_x <  (e0_x + ENEMY_SIZE)) && (e0_x <  (pac_x + 40)) &&
               (pac_y <  (e0_y + ENEMY_SIZE)) && (e0_y <  (pac_y + 40));
  wire coll1 = (pac_x <  (e1_x + ENEMY_SIZE)) && (e1_x <  (pac_x + 40)) &&
               (pac_y <  (e1_y + ENEMY_SIZE)) && (e1_y <  (pac_y + 40));
  wire coll2 = (pac_x <  (e2_x + ENEMY_SIZE)) && (e2_x <  (pac_x + 40)) &&
               (pac_y <  (e2_y + ENEMY_SIZE)) && (e2_y <  (pac_y + 40));
  wire coll3 = (pac_x <  (e3_x + ENEMY_SIZE)) && (e3_x <  (pac_x + 40)) &&
               (pac_y <  (e3_y + ENEMY_SIZE)) && (e3_y <  (pac_y + 40));

  wire collision = coll0 || coll1 || coll2 || coll3;

  // �浹 ǥ�ÿ� LED2
  assign led2 = collision;

  reg game_reset_r;
  always @(posedge clk_pix or negedge rstn) begin
    if (!rstn)
      game_reset_r <= 1'b0;
    else
      game_reset_r <= collision;
  end
  assign game_reset = game_reset_r;


  //==================================================
  // 8) �ȼ� MUX: �Ѹ� �� ��(����) �� ���
  //==================================================
  // 8-1) �Ѹ� ��(������=20) ����
  wire signed [12:0] dx = $signed(pixel_x) - $signed(pac_x + 19);
  wire signed [12:0] dy = $signed(pixel_y) - $signed(pac_y + 19);
  wire [12:0] dist2 = dx*dx + dy*dy;
  wire in_pac_circle = (dist2 <= 20*20);
  wire in_pac_sprite = video_on &&
                       (pixel_x >= pac_x) && (pixel_x <  (pac_x + 40)) &&
                       (pixel_y >= pac_y) && (pixel_y <  (pac_y + 40));

  // 8-2) �� "����" ����ũ
  //    - �� ����: 40��40 �簢 (eN_x..eN_x+39, eN_y..eN_y+39)
  //    - �Ӹ�: (cx^2+cy^2 <= 20^2) AND (cy <= 0) �̸� �� ���κ�
  //    - �ٸ�: cy > 0 �� �κп��� ���� �ݿ�(r=8) 4��
  //      leg1 center = (eN_x+20-12, eN_y+20+8)
  //      leg2 center = (eN_x+20-4,  eN_y+20+8)
  //      leg3 center = (eN_x+20+4,  eN_y+20+8)
  //      leg4 center = (eN_x+20+12, eN_y+20+8)

  // ==== ��0 ���� ����ũ ====
  wire in_e0_area = video_on &&
                    (pixel_x >= e0_x) && (pixel_x <  (e0_x + ENEMY_SIZE)) &&
                    (pixel_y >= e0_y) && (pixel_y <  (e0_y + ENEMY_SIZE));
  // �Ӹ�: �߽� (e0_x+20, e0_y+20), ������ 20, �Ӹ� �κ�(dy0 <= 0)
  wire signed [12:0] dx0 = $signed(pixel_x) - $signed(e0_x + 20);
  wire signed [12:0] dy0 = $signed(pixel_y) - $signed(e0_y + 20);
  wire head0 = (dx0*dx0 + dy0*dy0 <= 20*20) && (dy0 <= 0);
  // �ٸ� �ݿ�(r=8), �߽� offset = (-12,+8), (-4,+8), (+4,+8), (+12,+8)
  wire signed [12:0] dx0_l1 = dx0 + 12, dy0_l1 = dy0 - 8;
  wire signed [12:0] dx0_l2 = dx0 + 4,  dy0_l2 = dy0 - 8;
  wire signed [12:0] dx0_l3 = dx0 - 4,  dy0_l3 = dy0 - 8;
  wire signed [12:0] dx0_l4 = dx0 - 12, dy0_l4 = dy0 - 8;
  wire leg0_1 = (dx0_l1*dx0_l1 + dy0_l1*dy0_l1 <= 8*8) && (dy0 >= 0);
  wire leg0_2 = (dx0_l2*dx0_l2 + dy0_l2*dy0_l2 <= 8*8) && (dy0 >= 0);
  wire leg0_3 = (dx0_l3*dx0_l3 + dy0_l3*dy0_l3 <= 8*8) && (dy0 >= 0);
  wire leg0_4 = (dx0_l4*dx0_l4 + dy0_l4*dy0_l4 <= 8*8) && (dy0 >= 0);
  wire in_e0_mask = in_e0_area && (head0 || leg0_1 || leg0_2 || leg0_3 || leg0_4);

  // ==== ��1 ���� ����ũ ====
  wire in_e1_area = video_on &&
                    (pixel_x >= e1_x) && (pixel_x <  (e1_x + ENEMY_SIZE)) &&
                    (pixel_y >= e1_y) && (pixel_y <  (e1_y + ENEMY_SIZE));
  wire signed [12:0] dx1 = $signed(pixel_x) - $signed(e1_x + 20);
  wire signed [12:0] dy1 = $signed(pixel_y) - $signed(e1_y + 20);
  wire head1 = (dx1*dx1 + dy1*dy1 <= 20*20) && (dy1 <= 0);
  wire signed [12:0] dx1_l1 = dx1 + 12, dy1_l1 = dy1 - 8;
  wire signed [12:0] dx1_l2 = dx1 + 4,  dy1_l2 = dy1 - 8;
  wire signed [12:0] dx1_l3 = dx1 - 4,  dy1_l3 = dy1 - 8;
  wire signed [12:0] dx1_l4 = dx1 - 12, dy1_l4 = dy1 - 8;
  wire leg1_1 = (dx1_l1*dx1_l1 + dy1_l1*dy1_l1 <= 8*8) && (dy1 >= 0);
  wire leg1_2 = (dx1_l2*dx1_l2 + dy1_l2*dy1_l2 <= 8*8) && (dy1 >= 0);
  wire leg1_3 = (dx1_l3*dx1_l3 + dy1_l3*dy1_l3 <= 8*8) && (dy1 >= 0);
  wire leg1_4 = (dx1_l4*dx1_l4 + dy1_l4*dy1_l4 <= 8*8) && (dy1 >= 0);
  wire in_e1_mask = in_e1_area && (head1 || leg1_1 || leg1_2 || leg1_3 || leg1_4);

  // ==== ��2 ���� ����ũ ====
  wire in_e2_area = video_on &&
                    (pixel_x >= e2_x) && (pixel_x <  (e2_x + ENEMY_SIZE)) &&
                    (pixel_y >= e2_y) && (pixel_y <  (e2_y + ENEMY_SIZE));
  wire signed [12:0] dx2 = $signed(pixel_x) - $signed(e2_x + 20);
  wire signed [12:0] dy2 = $signed(pixel_y) - $signed(e2_y + 20);
  wire head2 = (dx2*dx2 + dy2*dy2 <= 20*20) && (dy2 <= 0);
  wire signed [12:0] dx2_l1 = dx2 + 12, dy2_l1 = dy2 - 8;
  wire signed [12:0] dx2_l2 = dx2 + 4,  dy2_l2 = dy2 - 8;
  wire signed [12:0] dx2_l3 = dx2 - 4,  dy2_l3 = dy2 - 8;
  wire signed [12:0] dx2_l4 = dx2 - 12, dy2_l4 = dy2 - 8;
  wire leg2_1 = (dx2_l1*dx2_l1 + dy2_l1*dy2_l1 <= 8*8) && (dy2 >= 0);
  wire leg2_2 = (dx2_l2*dx2_l2 + dy2_l2*dy2_l2 <= 8*8) && (dy2 >= 0);
  wire leg2_3 = (dx2_l3*dx2_l3 + dy2_l3*dy2_l3 <= 8*8) && (dy2 >= 0);
  wire leg2_4 = (dx2_l4*dx2_l4 + dy2_l4*dy2_l4 <= 8*8) && (dy2 >= 0);
  wire in_e2_mask = in_e2_area && (head2 || leg2_1 || leg2_2 || leg2_3 || leg2_4);

  // ==== ��3 ���� ����ũ ====
  wire in_e3_area = video_on &&
                    (pixel_x >= e3_x) && (pixel_x <  (e3_x + ENEMY_SIZE)) &&
                    (pixel_y >= e3_y) && (pixel_y <  (e3_y + ENEMY_SIZE));
  wire signed [12:0] dx3 = $signed(pixel_x) - $signed(e3_x + 20);
  wire signed [12:0] dy3 = $signed(pixel_y) - $signed(e3_y + 20);
  wire head3 = (dx3*dx3 + dy3*dy3 <= 20*20) && (dy3 <= 0);
  wire signed [12:0] dx3_l1 = dx3 + 12, dy3_l1 = dy3 - 8;
  wire signed [12:0] dx3_l2 = dx3 + 4,  dy3_l2 = dy3 - 8;
  wire signed [12:0] dx3_l3 = dx3 - 4,  dy3_l3 = dy3 - 8;
  wire signed [12:0] dx3_l4 = dx3 - 12, dy3_l4 = dy3 - 8;
  wire leg3_1 = (dx3_l1*dx3_l1 + dy3_l1*dy3_l1 <= 8*8) && (dy3 >= 0);
  wire leg3_2 = (dx3_l2*dx3_l2 + dy3_l2*dy3_l2 <= 8*8) && (dy3 >= 0);
  wire leg3_3 = (dx3_l3*dx3_l3 + dy3_l3*dy3_l3 <= 8*8) && (dy3 >= 0);
  wire leg3_4 = (dx3_l4*dx3_l4 + dy3_l4*dy3_l4 <= 8*8) && (dy3 >= 0);
  wire in_e3_mask = in_e3_area && (head3 || leg3_1 || leg3_2 || leg3_3 || leg3_4);

  // �� ��ü ���� ����(����ũ)
  wire in_any_enemy = in_e0_mask || in_e1_mask || in_e2_mask || in_e3_mask;
  localparam [11:0] ENEMY_COLOR = 12'hF00;  // �� ��: ������


  //==================================================
  // 9) ���� �ȼ� ���� MUX (�Ѹ� �� ��(����) �� ���)
  //==================================================
  reg [11:0] pixel_color;
  always @(*) begin
    if (!video_on) begin
      pixel_color = 12'h000;        // ȭ�� ����: ������
    end else if (in_pac_sprite && in_pac_circle) begin
      pixel_color = 12'hFF0;        // �Ѹ�: �����
    end else if (in_any_enemy) begin
      pixel_color = ENEMY_COLOR;    // ��(����): ������
    end else begin
      pixel_color = tile_color;     // ��� Ÿ��
    end
  end

  assign vga_r = pixel_color[11:8];
  assign vga_g = pixel_color[ 7:4];
  assign vga_b = pixel_color[ 3:0];

endmodule
