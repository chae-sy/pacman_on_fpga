//-----------------------------------------------------------------------------
// enemy_ctrl_flat.v (수정판)
//   - 4마리 적을 40×40 크기로 랜덤 이동시키는 모듈 (Flat Bus 방식)
//   - rstn=0 또는 game_reset=1 시: 네 모서리로 초기화
//   - frame_tick마다 STEP만큼 랜덤 방향·랜덤 거리로 이동
//   - 각 적마다 별도의 tile_addr/tile_code를 받아 "벽 충돌" 여부를 검사
//-----------------------------------------------------------------------------

module enemy_ctrl_flat (
    input  wire        clk_pix,         // 148.5 MHz pixel clock
    input  wire        rstn,            // active-low reset (비동기)
    input  wire        frame_tick,      // 한 프레임당(=VSYNC 상승) 1펄스
    input  wire        game_reset,      // 충돌 시(팩맨+적) 1이 되는 신호

    // --- 적 0 관련 타일 충돌 입력 ---
    input  wire [10:0] tile0_addr,      // 적0가 현재 위치한 타일 주소 (0..48×27-1)
    input  wire [3:0]  tile0_code,      // 해당 타일의 코드 (1=WALL, 2=COIN, 0=BG)
    output reg  [11:0] enemy0_x,        // 적0 X 좌표 (픽셀)
    output reg  [11:0] enemy0_y,        // 적0 Y 좌표 (픽셀)

    // --- 적 1 관련 타일 충돌 입력 ---
    input  wire [10:0] tile1_addr,
    input  wire [3:0]  tile1_code,
    output reg  [11:0] enemy1_x,
    output reg  [11:0] enemy1_y,

    // --- 적 2 관련 타일 충돌 입력 ---
    input  wire [10:0] tile2_addr,
    input  wire [3:0]  tile2_code,
    output reg  [11:0] enemy2_x,
    output reg  [11:0] enemy2_y,

    // --- 적 3 관련 타일 충돌 입력 ---
    input  wire [10:0] tile3_addr,
    input  wire [3:0]  tile3_code,
    output reg  [11:0] enemy3_x,
    output reg  [11:0] enemy3_y
);

  //==================================================
  // 파라미터 및 내부 레지스터 선언
  //==================================================
  localparam SCR_W      = 1920;
  localparam SCR_H      = 1080;
  localparam MAP_W      = 48;
  localparam MAP_H      = 27;
  localparam TILE_W     = SCR_W / MAP_W;   // = 40
  localparam TILE_H     = SCR_H / MAP_H;   // = 40
  localparam ENEMY_SIZE = 40;              // 적 크기 = 40×40
  localparam STEP       = 2;               // 한 frame_tick당 이동 픽셀 수

  // LFSR (16비트) → 랜덤 시퀀스 생성
  reg [15:0] lfsr;
  wire       lfsr_fb = lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10];

  // 각 적마다 "이동 방향" (2비트: 00=Up, 01=Down, 10=Left, 11=Right)
  reg [1:0] dir0, dir1, dir2, dir3;

  // 각 적마다 "남은 이동 거리" (6비트: 0~63 프레임)
  reg [5:0] dist0, dist1, dist2, dist3;


  //==================================================
  // 하나의 always 블록 안에서만 레지스터 드라이브
  //   - rstn=0 또는 game_reset=1 시: 적을 네 모서리로 초기화
  //   - frame_tick=1이면 이동, 아니면 그대로 유지
  //   - 이동 중 벽 충돌 시 distN=0 → 다음 프레임에 방향 전환
  //==================================================
  always @(posedge clk_pix or negedge rstn) begin
    if (!rstn) begin
      // ----------------------------------
      // (1) 시스템 리셋(rstn=0) 시 초기화
      // ----------------------------------
      lfsr     <= 16'hABCD; 

      // 적 4마리를 네 모서리로 배치
      enemy0_x <= 12'd0;                   enemy0_y <= 12'd0;                    // 왼쪽 위
      enemy1_x <= (SCR_W - ENEMY_SIZE);    enemy1_y <= 12'd0;                    // 오른쪽 위
      enemy2_x <= 12'd0;                   enemy2_y <= (SCR_H - ENEMY_SIZE);     // 왼쪽 아래
      enemy3_x <= (SCR_W - ENEMY_SIZE);    enemy3_y <= (SCR_H - ENEMY_SIZE);     // 오른쪽 아래

      // 이동 방향/거리 초기화 (첫 frame_tick에서 랜덤 뽑음)
      dir0  <= 2'b00;  dist0 <= 6'd0;
      dir1  <= 2'b00;  dist1 <= 6'd0;
      dir2  <= 2'b00;  dist2 <= 6'd0;
      dir3  <= 2'b00;  dist3 <= 6'd0;

    end else if (game_reset) begin
      // ----------------------------------
      // (2) 팩맨과 충돌 시(game_reset=1) 초기화
      // ----------------------------------
      // 적 4마리를 다시 네 모서리로 배치 (LFSR는 유지)
      enemy0_x <= 12'd0;                   enemy0_y <= 12'd0;
      enemy1_x <= (SCR_W - ENEMY_SIZE);    enemy1_y <= 12'd0;
      enemy2_x <= 12'd0;                   enemy2_y <= (SCR_H - ENEMY_SIZE);
      enemy3_x <= (SCR_W - ENEMY_SIZE);    enemy3_y <= (SCR_H - ENEMY_SIZE);

      dir0  <= 2'b00;  dist0 <= 6'd0;
      dir1  <= 2'b00;  dist1 <= 6'd0;
      dir2  <= 2'b00;  dist2 <= 6'd0;
      dir3  <= 2'b00;  dist3 <= 6'd0;

    end else begin
      // -----------------------------------
      // (3) "그 외"인 경우: frame_tick 처리
      // -----------------------------------
      // (3-1) 매 클럭마다 LFSR 시프트
      lfsr <= { lfsr[14:0], lfsr_fb };

      if (frame_tick) begin
        // =========================================
        //   (3-2) 적0 이동 + 벽 충돌 검사
        // =========================================
        if (dist0 == 6'd0) begin
          // 새 랜덤 방향/거리 뽑기
          dir0  <= lfsr[15:14];
          dist0 <= lfsr[13:8];

          // STEP만큼 이동 시도
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

          // 벽 충돌 검사 → tile0_code가 1(WALL)이면 dist0→0 (다음 프레임에 방향 재추첨)
          if (tile0_code == 4'd1) begin
            dist0 <= 6'd0;
          end else begin
            // 충돌이 없으면 뽑힌 거리에서 1 감소
            dist0 <= (lfsr[13:8] > 0) ? (lfsr[13:8] - 6'd1) : 6'd0;
          end

        end else begin
          // dist0 != 0 → 이전 dir0 방향으로 STEP만큼 이동
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
          // 이동 후 남은 거리 1 감소
          dist0 <= dist0 - 6'd1;

          // 이동 후에도 벽에 걸리면 dist0=0으로 만들어 다음 프레임에 재추첨
          if (tile0_code == 4'd1) begin
            dist0 <= 6'd0;
          end
        end


        // =========================================
        //   (3-3) 적1 이동 + 벽 충돌 검사
        // =========================================
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

          if (tile1_code == 4'd1) begin
            dist1 <= 6'd0;
          end else begin
            dist1 <= (lfsr[13:8] > 0) ? (lfsr[13:8] - 6'd1) : 6'd0;
          end

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
          if (tile1_code == 4'd1) begin
            dist1 <= 6'd0;
          end
        end


        // =========================================
        //   (3-4) 적2 이동 + 벽 충돌 검사
        // =========================================
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

          if (tile2_code == 4'd1) begin
            dist2 <= 6'd0;
          end else begin
            dist2 <= (lfsr[13:8] > 0) ? (lfsr[13:8] - 6'd1) : 6'd0;
          end

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
          if (tile2_code == 4'd1) begin
            dist2 <= 6'd0;
          end
        end


        // =========================================
        //   (3-5) 적3 이동 + 벽 충돌 검사
        // =========================================
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

          if (tile3_code == 4'd1) begin
            dist3 <= 6'd0;
          end else begin
            dist3 <= (lfsr[13:8] > 0) ? (lfsr[13:8] - 6'd1) : 6'd0;
          end

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
          if (tile3_code == 4'd1) begin
            dist3 <= 6'd0;
          end
        end

      end else begin
        // frame_tick = 0인 경우: 적 좌표와 dir/dist 모두 그대로 유지
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
