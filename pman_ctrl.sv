//-----------------------------------------------------------------------------
// pacman_ctrl.v  (수정본)
//-----------------------------------------------------------------------------

module pacman_ctrl (
    input  wire        clk_pix,      // 148.5 MHz pixel clock
    input  wire        rstn,         // active-low reset
    input  wire        frame_tick,   // 한 프레임마다 1 클럭 펄스 (VSYNC 타이밍)
    input  wire [4:0]  btn_pulse,    // {UP, LEFT, MID, RIGHT, DOWN}
    input  wire        game_reset,   // 충돌 시 게임 리셋 신호

    output reg  [11:0] pac_x,        // 팩맨 X 좌표 (픽셀, 왼쪽 상단 기준)
    output reg  [11:0] pac_y         // 팩맨 Y 좌표 (픽셀, 왼쪽 상단 기준)
);

  // 이동 속도 (픽셀)
  localparam STEP     = 4;
  // 스프라이트 크기 (40×40)
  localparam SPRITE_W = 40;
  localparam SPRITE_H = 40;
  // 화면 해상도
  localparam SCR_W    = 1920;
  localparam SCR_H    = 1080;
  // 팩맨 초기 위치 = (가로 중앙, 세로 중앙)
  localparam INIT_X   = (SCR_W - SPRITE_W)/2; //  (1920-40)/2 = 940
  localparam INIT_Y   = (SCR_H - SPRITE_H)/2; //  (1080-40)/2 = 520

  always @(posedge clk_pix or negedge rstn) begin
    if (!rstn || game_reset) begin
      // 시스템 리셋 혹은 게임 리셋 시 → 팩맨 초기 위치
      pac_x <= INIT_X;
      pac_y <= INIT_Y;
    end else if (frame_tick) begin
      // 프레임 경과 시 한 번만 이동 처리
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
      // MID (정지) → 아무 동작 없음

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
    // 그 외(프레임이 아닐 때)는 pac_x, pac_y 유지
  end

endmodule
