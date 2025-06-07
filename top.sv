//-----------------------------------------------------------------------------
// top_1080p_vga.v
//   - �Ѹ�(pacman_ctrl), ��(enemy_ctrl_flat), Ÿ�ϸ� + ���� ���� ���� ����
//   - �浹(�Ѹ�+��) �� ��� �ʱ�ȭ
//   - ��(WALL)�� ������ ƨ�� ����
//   - ����: 15��15 ũ��, �Ѹ��� �������� �����
//   - coin_map �������Ϳ� ���� all-in-one always ������� Multiple Driver ���� �ذ�
//-----------------------------------------------------------------------------

module top_1080p_vga (
    input  wire        sys_clk_100m,   // 100 MHz board clock
    input  wire        rstn,           // active-low reset
    
    // VGA ���
    output wire [3:0]  vga_r,
    output wire [3:0]  vga_g,
    output wire [3:0]  vga_b,
    output wire        vga_hs,
    output wire        vga_vs,

    // ����ġ �Է� (�Ѹ� �̵���)
    input  sw_up,
    input  sw_left,
    input  sw_mid,
    input  sw_right,
    input  sw_down,

    // ����׿� LED
    //   led1: frame_tick ��� Ȯ�� (�� 60Hz)
    //   led2: �Ѹ�+�� �浹 �� ����Ʈ
    output led1,
    output led2
);

  //==================================================
  // 1) Clock & VGA Ÿ�̹�
  //==================================================
  wire clk_pix, clk_locked;
  clk_wiz_0 u_clk (
    .clk_in1  (sys_clk_100m),
    .reset   (~rstn),
    .clk_pix  (clk_pix),
    .locked   (clk_locked)
  );
  wire active = rstn & clk_locked;

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
  // 2) ��ư �������̽� & frame_tick ����
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
    .led1     (), // ���� LED ��� �� ��
    .led2     (),
    .led3     (),
    .led4     (),
    .led5     ()
  );
  assign btn_pulse = {sw_up, sw_left, sw_mid, sw_right, sw_down};

  // VSYNC ��� �������� 1Ŭ�� �޽� �� frame_tick (�� 60Hz)
  reg vsync_d;
  always @(posedge clk_pix) vsync_d <= vga_vs;
  wire frame_tick = (~vsync_d & vga_vs) & active;

  // frame_tick ����׿� LED1 (�� 60Hz)
  reg frame_led;
  always @(posedge clk_pix or negedge rstn) begin
    if (!rstn)
      frame_led <= 1'b0;
    else if (frame_tick)
      frame_led <= ~frame_led;
  end
  assign led1 = frame_led;


  //==================================================
  // 3) ��� Ÿ�ϸ� (48��27 Ÿ��, �� Ÿ�� 40��40 �ȼ�)
  //==================================================
  localparam MAP_W  = 48, MAP_H = 27;
  localparam H_VIS  = 1920, V_VIS = 1080;
  localparam TILE_W = H_VIS / MAP_W;   // 40
  localparam TILE_H = V_VIS / MAP_H;   // 40

  // ���� pixel ��ġ �� Ÿ�� ��ǥ
  wire [5:0] tile_x = pixel_x / TILE_W;  // 0..47
  wire [4:0] tile_y = pixel_y / TILE_H;  // 0..26
  wire [10:0] tile_addr = tile_y * MAP_W + tile_x; // 0..1295

//ȭ�� �׸��� �� 
  wire [3:0] tile_code;  
  blk_mem_gen_0 u_map (
    .clka  (clk_pix),
    .ena   (video_on),
    .addra (tile_addr),
    .douta (tile_code)
  );

  localparam [11:0]
    WALL_COLOR = 12'hADE,   // ��(�Ķ�))
    COIN_COLOR = 12'hFF0,   // ����(���)
    BG_COLOR   = 12'h000;   // ���(����)

  // "��� Ÿ�� �÷�" (���� ������ ���� �׸� �����̹Ƿ�, tile_color�� WALL�̳� BG�� ���)
  wire [11:0] tile_color = (tile_code == 4'd1) ? WALL_COLOR : BG_COLOR;


  //==================================================
  // 4) coin_map �ʱ�ȭ + �Ѹ��� �������� ���� �Ҹ� (���� always ���)
  //==================================================
  //  - �ʱ�ȭ ��: ROM(tile_code==2�� Ÿ�ϸ�) �� coin_map=1
  //  - �� ����: �Ѹ��� �ش� Ÿ�� �������� coin_map[tile] �� 0
  localparam COIN_CNT = MAP_W * MAP_H; // 48*27 = 1296
  reg [COIN_CNT-1:0] coin_map;         // �� ��Ʈ�� "���� ����" (1=���� ����, 0=����)
  reg init_coins_done;                 // �ʱ�ȭ �Ϸ� �÷���
  reg [10:0] init_addr;                // �ʱ�ȭ ���� Ÿ�� ��ȣ (0..1295)

wire [3:0] init_code;
  // ��Ʈ B: �ʱ�ȭ�� (dual-port ROM)
  blk_mem_gen_1 u_map_init (
    .clka  (clk_pix),
    .ena   (1'b1),
    .addra (init_addr),
    .douta (init_code)
  );

  // �Ѹ��� ��ġ�� "Ÿ�� �ּ�" (�Ѹ� �߽� ����)
  //  �� pac_x, pac_y�� pacman_ctrl���� ������ (�Ʒ� ����)
  wire [11:0] pac_x, pac_y;
  wire [5:0] pac_tile_x = (pac_x + 20) / TILE_W; // 0..47
  wire [4:0] pac_tile_y = (pac_y + 20) / TILE_H; // 0..26
  wire [10:0] pac_tile_addr = pac_tile_y * MAP_W + pac_tile_x;
  // Pacman control
  reg [10:0] pac_tile_addr_reg;
    // 4) coin_map �ʱ�ȭ + �Ѹ��� �������� ���� �Ҹ�
  always @(posedge clk_pix or negedge rstn) begin
    if (!rstn) begin
      init_addr       <= 0;
      init_coins_done <= 0;
      coin_map        <= {COIN_CNT{1'b0}};
      pac_tile_addr_reg <= 0;
    end else if (!init_coins_done && frame_tick) begin
      // �ʱ�ȭ �ܰ�: frame_tick���� �� Ÿ�Ͼ�
      coin_map[init_addr] <= (init_code == 4'd2);
      if (init_addr == COIN_CNT-1)
        init_coins_done <= 1;
      else
        init_addr <= init_addr + 1;
      // �Ѹ� �ּ� �������ʹ� ���� ���� �� ��
    end else begin
      // �ʱ�ȭ �Ϸ� ��
      // 1) �Ѹ� ��ġ tile_addr �������Ϳ� ����
      pac_tile_addr_reg <= pac_tile_addr;

      // 2) �ش� ��ġ�� ������ ������ �����
      if (coin_map[pac_tile_addr_reg])
        coin_map[pac_tile_addr_reg] <= 1'b0;
    end
  end

  

  

  wire [3:0] dummy_tile_code = tile_code;
  pacman_ctrl u_pac (
    .clk_pix    (clk_pix),
    .rstn       (active),
    .frame_tick (frame_tick),
    .btn_pulse  (btn_pulse),
    .tile_addr  (pac_tile_addr_reg),
    .tile_code  (dummy_tile_code),
    .pac_x      (pac_x),
    .pac_y      (pac_y)
  );


  //==================================================
  // 6) �� 4���� ���� (enemy_ctrl_flat)
  //   - �� ������ tileN_addr, tileN_code�� ���� ����
  //==================================================
  // ���� �߾� �ȼ� ��ġ �� Ÿ�� �ּ� ���
  // (eN_x, eN_y�� enemy_ctrl_flat �ν��Ͻ����� ��µ�)
  wire [11:0] e0_x, e0_y, e1_x, e1_y, e2_x, e2_y, e3_x, e3_y;

  wire [5:0] e0_tile_x = (e0_x + 20) / TILE_W;
  wire [4:0] e0_tile_y = (e0_y + 20) / TILE_H;
  wire [10:0] e0_tile_addr = e0_tile_y * MAP_W + e0_tile_x;

  wire [5:0] e1_tile_x = (e1_x + 20) / TILE_W;
  wire [4:0] e1_tile_y = (e1_y + 20) / TILE_H;
  wire [10:0] e1_tile_addr = e1_tile_y * MAP_W + e1_tile_x;

  wire [5:0] e2_tile_x = (e2_x + 20) / TILE_W;
  wire [4:0] e2_tile_y = (e2_y + 20) / TILE_H;
  wire [10:0] e2_tile_addr = e2_tile_y * MAP_W + e2_tile_x;

  wire [5:0] e3_tile_x = (e3_x + 20) / TILE_W;
  wire [4:0] e3_tile_y = (e3_y + 20) / TILE_H;
  wire [10:0] e3_tile_addr = e3_tile_y * MAP_W + e3_tile_x;

  // blk_mem_gen_0�� 4ȸ �ν��Ͻ�ȭ�Ͽ� ���� �ٸ� ��Ʈ�� �о��
  wire [3:0] e0_tile_code, e1_tile_code, e2_tile_code, e3_tile_code;

  blk_mem_gen_0 u_map_e0 (
    .clka  (clk_pix),
    .ena   (active),
    .addra (e0_tile_addr),
    .douta (e0_tile_code)
  );
  blk_mem_gen_0 u_map_e1 (
    .clka  (clk_pix),
    .ena   (active),
    .addra (e1_tile_addr),
    .douta (e1_tile_code)
  );
  blk_mem_gen_0 u_map_e2 (
    .clka  (clk_pix),
    .ena   (active),
    .addra (e2_tile_addr),
    .douta (e2_tile_code)
  );
  blk_mem_gen_0 u_map_e3 (
    .clka  (clk_pix),
    .ena   (active),
    .addra (e3_tile_addr),
    .douta (e3_tile_code)
  );

  enemy_ctrl_flat u_enemy (
    .clk_pix     (clk_pix),
    .rstn        (active),
    .frame_tick  (frame_tick),
    .game_reset  (game_reset),

    .tile0_addr  (e0_tile_addr),
    .tile0_code  (e0_tile_code),
    .enemy0_x    (e0_x),
    .enemy0_y    (e0_y),

    .tile1_addr  (e1_tile_addr),
    .tile1_code  (e1_tile_code),
    .enemy1_x    (e1_x),
    .enemy1_y    (e1_y),

    .tile2_addr  (e2_tile_addr),
    .tile2_code  (e2_tile_code),
    .enemy2_x    (e2_x),
    .enemy2_y    (e2_y),

    .tile3_addr  (e3_tile_addr),
    .tile3_code  (e3_tile_code),
    .enemy3_x    (e3_x),
    .enemy3_y    (e3_y)
  );


  //==================================================
  // 7) �浹 ���� �� game_reset ����
  //==================================================
  localparam ENEMY_SIZE = 40;
  localparam PAC_SIZE   = 40;

  wire coll0 = (pac_x <  (e0_x + ENEMY_SIZE)) && (e0_x <  (pac_x + PAC_SIZE)) &&
               (pac_y <  (e0_y + ENEMY_SIZE)) && (e0_y <  (pac_y + PAC_SIZE));
  wire coll1 = (pac_x <  (e1_x + ENEMY_SIZE)) && (e1_x <  (pac_x + PAC_SIZE)) &&
               (pac_y <  (e1_y + ENEMY_SIZE)) && (e1_y <  (pac_y + PAC_SIZE));
  wire coll2 = (pac_x <  (e2_x + ENEMY_SIZE)) && (e2_x <  (pac_x + PAC_SIZE)) &&
               (pac_y <  (e2_y + ENEMY_SIZE)) && (e2_y <  (pac_y + PAC_SIZE));
  wire coll3 = (pac_x <  (e3_x + ENEMY_SIZE)) && (e3_x <  (pac_x + PAC_SIZE)) &&
               (pac_y <  (e3_y + ENEMY_SIZE)) && (e3_y <  (pac_y + PAC_SIZE));

  wire collision = coll0 || coll1 || coll2 || coll3;

  reg game_reset_r;
  always @(posedge clk_pix or negedge rstn) begin
    if (!rstn)
      game_reset_r <= 1'b0;
    else
      game_reset_r <= collision;
  end
  assign game_reset = game_reset_r;

  // LED2: �浹 ���� ǥ��
  assign led2 = collision;


  //==================================================
  // 8) �ȼ� MUX: �Ѹ� �� ��(���� ���) �� ���� �� ���
  //==================================================
  // �Ѹ� ��(������=20) ����ũ
  wire signed [12:0] dx_p = $signed(pixel_x) - $signed(pac_x + 20);
  wire signed [12:0] dy_p = $signed(pixel_y) - $signed(pac_y + 20);
  wire [12:0] dist2_p = dx_p*dx_p + dy_p*dy_p;
  wire in_pac_circle = (dist2_p <= 20*20);
  wire in_pac_sprite = video_on &&
                       (pixel_x >= pac_x) && (pixel_x <  (pac_x + PAC_SIZE)) &&
                       (pixel_y >= pac_y) && (pixel_y <  (pac_y + PAC_SIZE));

  // �� ����(Octopus) ����ũ (���� ������ ����)
  wire in_e0_area = video_on &&
                    (pixel_x >= e0_x) && (pixel_x <  (e0_x + ENEMY_SIZE)) &&
                    (pixel_y >= e0_y) && (pixel_y <  (e0_y + ENEMY_SIZE));
  wire signed [12:0] dx0 = $signed(pixel_x) - $signed(e0_x + 20);
  wire signed [12:0] dy0 = $signed(pixel_y) - $signed(e0_y + 20);
  wire head0 = (dx0*dx0 + dy0*dy0 <= 20*20) && (dy0 <= 0);
  wire signed [12:0] dx0_l1 = dx0 + 12, dy0_l1 = dy0 - 8;
  wire signed [12:0] dx0_l2 = dx0 + 4,  dy0_l2 = dy0 - 8;
  wire signed [12:0] dx0_l3 = dx0 - 4,  dy0_l3 = dy0 - 8;
  wire signed [12:0] dx0_l4 = dx0 - 12, dy0_l4 = dy0 - 8;
  wire leg0_1 = (dx0_l1*dx0_l1 + dy0_l1*dy0_l1 <= 8*8) && (dy0 >= 0);
  wire leg0_2 = (dx0_l2*dx0_l2 + dy0_l2*dy0_l2 <= 8*8) && (dy0 >= 0);
  wire leg0_3 = (dx0_l3*dx0_l3 + dy0_l3*dy0_l3 <= 8*8) && (dy0 >= 0);
  wire leg0_4 = (dx0_l4*dx0_l4 + dy0_l4*dy0_l4 <= 8*8) && (dy0 >= 0);
  wire in_e0_mask = in_e0_area && (head0 || leg0_1 || leg0_2 || leg0_3 || leg0_4);

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

  wire in_any_enemy = in_e0_mask || in_e1_mask || in_e2_mask || in_e3_mask;


  //==================================================
  // 9) "���� �׸���" ����ũ
  //   - 15��15 ũ��, ������ ���� �ִ� Ÿ�Ͽ�����
  //==================================================
  wire [5:0] coin_tile_x = pixel_x / TILE_W; // 0..47
  wire [4:0] coin_tile_y = pixel_y / TILE_H; // 0..26
  wire [10:0] coin_tile_addr = coin_tile_y * MAP_W + coin_tile_x;

  // ���� �߽��� Ÿ�� �߾����� �ΰ�, �����¿� ��7 �ȼ� ������ ���� �簢
  wire [11:0] coin_left   = coin_tile_x * TILE_W + ((TILE_W - 15) >> 1);
  wire [11:0] coin_top    = coin_tile_y * TILE_H + ((TILE_H - 15) >> 1);
  wire [11:0] coin_right  = coin_left + 15;
  wire [11:0] coin_bottom = coin_top  + 15;

  wire in_coin_area = video_on &&
                      (pixel_x >= coin_left)  && (pixel_x < coin_right) &&
                      (pixel_y >= coin_top)   && (pixel_y < coin_bottom) &&
                      coin_map[coin_tile_addr]; 
  // coin_map ��Ʈ�� 1�� ��쿡�� ���� �׸���

  localparam [11:0] COIN_DRAW_COLOR = 12'hFF0; // �����

  //==================================================
  // 10) ���� �ȼ� MUX: �Ѹ� �� ��(����) �� ���� �� ���
  //==================================================
  reg [11:0] pixel_color;
  always @(*) begin
    if (!video_on) begin
      pixel_color = 12'h000;           // ȭ�� ����: ����
    end else if (in_pac_sprite && in_pac_circle) begin
      pixel_color = 12'hFF0;           // �Ѹ�: �����
    end else if (in_any_enemy) begin
      pixel_color = 12'hF00;           // ��(����): ����
    end else if (in_coin_area) begin
      pixel_color = COIN_DRAW_COLOR;   // ����: �����
    end else begin
      pixel_color = tile_color;        // ��� Ÿ��
    end
  end

  assign vga_r = pixel_color[11:8];
  assign vga_g = pixel_color[ 7:4];
  assign vga_b = pixel_color[ 3:0];

endmodule
