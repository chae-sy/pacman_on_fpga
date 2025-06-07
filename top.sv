//-----------------------------------------------------------------------------
// top_1080p_vga.v
//   - 팩맨(pacman_ctrl), 적(enemy_ctrl_flat), 타일맵 + 코인 관리 통합 예제
//   - 충돌(팩맨+적) 시 모두 초기화
//   - 벽(WALL)에 닿으면 튕겨 나옴
//   - 코인: 15×15 크기, 팩맨이 지나가면 사라짐
//   - coin_map 레지스터에 대한 all-in-one always 블록으로 Multiple Driver 문제 해결
//-----------------------------------------------------------------------------

module top_1080p_vga (
    input  wire        sys_clk_100m,   // 100 MHz board clock
    input  wire        rstn,           // active-low reset
    
    // VGA 출력
    output wire [3:0]  vga_r,
    output wire [3:0]  vga_g,
    output wire [3:0]  vga_b,
    output wire        vga_hs,
    output wire        vga_vs,

    // 스위치 입력 (팩맨 이동용)
    input  sw_up,
    input  sw_left,
    input  sw_mid,
    input  sw_right,
    input  sw_down,

    // 디버그용 LED
    //   led1: frame_tick 토글 확인 (약 60Hz)
    //   led2: 팩맨+적 충돌 시 라이트
    output led1,
    output led2
);

  //==================================================
  // 1) Clock & VGA 타이밍
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
  // 2) 버튼 인터페이스 & frame_tick 생성
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
    .led1     (), // 내부 LED 사용 안 함
    .led2     (),
    .led3     (),
    .led4     (),
    .led5     ()
  );
  assign btn_pulse = {sw_up, sw_left, sw_mid, sw_right, sw_down};

  // VSYNC 상승 에지에서 1클럭 펄스 → frame_tick (약 60Hz)
  reg vsync_d;
  always @(posedge clk_pix) vsync_d <= vga_vs;
  wire frame_tick = (~vsync_d & vga_vs) & active;

  // frame_tick 디버그용 LED1 (약 60Hz)
  reg frame_led;
  always @(posedge clk_pix or negedge rstn) begin
    if (!rstn)
      frame_led <= 1'b0;
    else if (frame_tick)
      frame_led <= ~frame_led;
  end
  assign led1 = frame_led;


  //==================================================
  // 3) 배경 타일맵 (48×27 타일, 각 타일 40×40 픽셀)
  //==================================================
  localparam MAP_W  = 48, MAP_H = 27;
  localparam H_VIS  = 1920, V_VIS = 1080;
  localparam TILE_W = H_VIS / MAP_W;   // 40
  localparam TILE_H = V_VIS / MAP_H;   // 40

  // 현재 pixel 위치 → 타일 좌표
  wire [5:0] tile_x = pixel_x / TILE_W;  // 0..47
  wire [4:0] tile_y = pixel_y / TILE_H;  // 0..26
  wire [10:0] tile_addr = tile_y * MAP_W + tile_x; // 0..1295

//화면 그리기 용 
  wire [3:0] tile_code;  
  blk_mem_gen_0 u_map (
    .clka  (clk_pix),
    .ena   (video_on),
    .addra (tile_addr),
    .douta (tile_code)
  );

  localparam [11:0]
    WALL_COLOR = 12'hADE,   // 벽(파랑))
    COIN_COLOR = 12'hFF0,   // 코인(노랑)
    BG_COLOR   = 12'h000;   // 배경(검정)

  // "배경 타일 컬러" (실제 코인은 따로 그릴 예정이므로, tile_color는 WALL이나 BG만 사용)
  wire [11:0] tile_color = (tile_code == 4'd1) ? WALL_COLOR : BG_COLOR;


  //==================================================
  // 4) coin_map 초기화 + 팩맨이 지나가면 코인 소멸 (단일 always 블록)
  //==================================================
  //  - 초기화 시: ROM(tile_code==2인 타일만) → coin_map=1
  //  - 그 이후: 팩맨이 해당 타일 지나가면 coin_map[tile] ≤ 0
  localparam COIN_CNT = MAP_W * MAP_H; // 48*27 = 1296
  reg [COIN_CNT-1:0] coin_map;         // 각 비트가 "코인 유무" (1=남아 있음, 0=없음)
  reg init_coins_done;                 // 초기화 완료 플래그
  reg [10:0] init_addr;                // 초기화 중인 타일 번호 (0..1295)

wire [3:0] init_code;
  // 포트 B: 초기화용 (dual-port ROM)
  blk_mem_gen_1 u_map_init (
    .clka  (clk_pix),
    .ena   (1'b1),
    .addra (init_addr),
    .douta (init_code)
  );

  // 팩맨이 위치한 "타일 주소" (팩맨 중심 기준)
  //  → pac_x, pac_y는 pacman_ctrl에서 생성됨 (아래 참조)
  wire [11:0] pac_x, pac_y;
  wire [5:0] pac_tile_x = (pac_x + 20) / TILE_W; // 0..47
  wire [4:0] pac_tile_y = (pac_y + 20) / TILE_H; // 0..26
  wire [10:0] pac_tile_addr = pac_tile_y * MAP_W + pac_tile_x;
  // Pacman control
  reg [10:0] pac_tile_addr_reg;
    // 4) coin_map 초기화 + 팩맨이 지나가면 코인 소멸
  always @(posedge clk_pix or negedge rstn) begin
    if (!rstn) begin
      init_addr       <= 0;
      init_coins_done <= 0;
      coin_map        <= {COIN_CNT{1'b0}};
      pac_tile_addr_reg <= 0;
    end else if (!init_coins_done && frame_tick) begin
      // 초기화 단계: frame_tick마다 한 타일씩
      coin_map[init_addr] <= (init_code == 4'd2);
      if (init_addr == COIN_CNT-1)
        init_coins_done <= 1;
      else
        init_addr <= init_addr + 1;
      // 팩맨 주소 레지스터는 아직 갱신 안 함
    end else begin
      // 초기화 완료 후
      // 1) 팩맨 위치 tile_addr 레지스터에 저장
      pac_tile_addr_reg <= pac_tile_addr;

      // 2) 해당 위치에 코인이 있으면 지우기
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
  // 6) 적 4마리 제어 (enemy_ctrl_flat)
  //   - 각 적마다 tileN_addr, tileN_code를 따로 연결
  //==================================================
  // 적의 중앙 픽셀 위치 → 타일 주소 계산
  // (eN_x, eN_y는 enemy_ctrl_flat 인스턴스에서 출력됨)
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

  // blk_mem_gen_0을 4회 인스턴스화하여 각기 다른 포트로 읽어옴
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
  // 7) 충돌 판정 → game_reset 생성
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

  // LED2: 충돌 여부 표시
  assign led2 = collision;


  //==================================================
  // 8) 픽셀 MUX: 팩맨 → 적(문어 모양) → 코인 → 배경
  //==================================================
  // 팩맨 원(반지름=20) 마스크
  wire signed [12:0] dx_p = $signed(pixel_x) - $signed(pac_x + 20);
  wire signed [12:0] dy_p = $signed(pixel_y) - $signed(pac_y + 20);
  wire [12:0] dist2_p = dx_p*dx_p + dy_p*dy_p;
  wire in_pac_circle = (dist2_p <= 20*20);
  wire in_pac_sprite = video_on &&
                       (pixel_x >= pac_x) && (pixel_x <  (pac_x + PAC_SIZE)) &&
                       (pixel_y >= pac_y) && (pixel_y <  (pac_y + PAC_SIZE));

  // 적 문어(Octopus) 마스크 (기존 구현과 동일)
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
  // 9) "코인 그리기" 마스크
  //   - 15×15 크기, 코인이 남아 있는 타일에서만
  //==================================================
  wire [5:0] coin_tile_x = pixel_x / TILE_W; // 0..47
  wire [4:0] coin_tile_y = pixel_y / TILE_H; // 0..26
  wire [10:0] coin_tile_addr = coin_tile_y * MAP_W + coin_tile_x;

  // 코인 중심을 타일 중앙으로 두고, 상하좌우 ±7 픽셀 범위가 코인 사각
  wire [11:0] coin_left   = coin_tile_x * TILE_W + ((TILE_W - 15) >> 1);
  wire [11:0] coin_top    = coin_tile_y * TILE_H + ((TILE_H - 15) >> 1);
  wire [11:0] coin_right  = coin_left + 15;
  wire [11:0] coin_bottom = coin_top  + 15;

  wire in_coin_area = video_on &&
                      (pixel_x >= coin_left)  && (pixel_x < coin_right) &&
                      (pixel_y >= coin_top)   && (pixel_y < coin_bottom) &&
                      coin_map[coin_tile_addr]; 
  // coin_map 비트가 1인 경우에만 코인 그리기

  localparam [11:0] COIN_DRAW_COLOR = 12'hFF0; // 노란색

  //==================================================
  // 10) 최종 픽셀 MUX: 팩맨 → 적(문어) → 코인 → 배경
  //==================================================
  reg [11:0] pixel_color;
  always @(*) begin
    if (!video_on) begin
      pixel_color = 12'h000;           // 화면 꺼짐: 검정
    end else if (in_pac_sprite && in_pac_circle) begin
      pixel_color = 12'hFF0;           // 팩맨: 노란색
    end else if (in_any_enemy) begin
      pixel_color = 12'hF00;           // 적(문어): 빨강
    end else if (in_coin_area) begin
      pixel_color = COIN_DRAW_COLOR;   // 코인: 노란색
    end else begin
      pixel_color = tile_color;        // 배경 타일
    end
  end

  assign vga_r = pixel_color[11:8];
  assign vga_g = pixel_color[ 7:4];
  assign vga_b = pixel_color[ 3:0];

endmodule
