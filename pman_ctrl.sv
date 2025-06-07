//-----------------------------------------------------------------------------
// pacman_ctrl.v
//   - 팩맨을 40×40 크기로 율동적으로 이동시키는 모듈
//   - rstn=0 시 중앙(940,520)으로 초기화
//   - frame_tick마다 btn_pulse 방향대로 STEP만큼 이동
//   - 벽(WALL)에 부딪히면 이동을 멈추고, btn_pulse를 무시(= 튕겨 나옴)
//-----------------------------------------------------------------------------

module pacman_ctrl (
    input  wire        clk_pix,       // 148.5 MHz pixel clock
    input  wire        rstn,          // active-low reset (비동기)
    input  wire        frame_tick,    // 한 프레임당(=VSYNC 상승) 1펄스
    input  wire [4:0]  btn_pulse,     // {UP, LEFT, MID, RIGHT, DOWN}

    // 벽 충돌 검사용: 현재 팩맨이 이동할 때 읽을 타일 주소 + 코드
    input  wire [10:0] tile_addr,     // (0..48×27-1)
    input  wire [3:0]  tile_code,     // 0=BG, 1=WALL, 2=COIN

    output reg  [11:0] pac_x,         // 팩맨 X (픽셀)
    output reg  [11:0] pac_y          // 팩맨 Y (픽셀)
);

  //==================================================
  // 1) 파라미터 선언
  //==================================================
  localparam SCR_W      = 1920;
  localparam SCR_H      = 1080;
  localparam PAC_SIZE   = 40;    // 팩맨 크기 = 40×40
  localparam STEP       = 4;     // 한 프레임당 이동 픽셀 수

  //==================================================
  // 2) 리셋 시 중앙 배치
  //    → (1920 - 40)/2 = 940, (1080 - 40)/2 = 520
  //==================================================
  always @(posedge clk_pix or negedge rstn) begin
    if (!rstn) begin
      pac_x <= (SCR_W - PAC_SIZE) >> 1;  // 940
      pac_y <= (SCR_H - PAC_SIZE) >> 1;  // 520
    end else if (frame_tick) begin
      //==================================================
      // 3) frame_tick마다 btn_pulse 충돌 검사 후 이동
      //    - UP (btn_pulse[0])
      //    - LEFT (btn_pulse[1])
      //    - MID (btn_pulse[2]) → 정지
      //    - RIGHT (btn_pulse[3])
      //    - DOWN (btn_pulse[4])
      //    - 이동 직후 "충돌 검사 → tile_code==1이면 이전 위치로 되돌림"
      //==================================================

      // (3-1) UP
      if (btn_pulse[0]) begin
        // 일단 앞으로 이동 시도
        if (pac_y >= STEP) 
          pac_y <= pac_y - STEP;
        else 
          pac_y <= 12'd0;

        // 이동 후 "타일 충돌 검사"
        if (tile_code == 4'd1) begin
          // WALL에 닿았다면, 이동 직전(원위치)으로 복구
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

      // (3-3) MID → 정지 (아무 동작 없음)

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

      // 아무 키도 안 눌렀으면 정지

    end
  end

endmodule
