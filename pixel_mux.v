//-----------------------------------------------------------------------------
// pixel_mux.v
//   Tile-map background 위에 Pac-Man 스프라이트 오버레이
//-----------------------------------------------------------------------------
module pixel_mux #(
  parameter SPRITE_SIZE = 8
)(
  input  wire        video_on,       // from VGA controller
  input  wire [11:0] pixel_x,        // 0…1919 (or wider)
  input  wire [11:0] pixel_y,        // 0…1079
  input  wire [11:0] tile_color,     // 12-bit RGB background
  input  wire        mouth_state,    // sprite open/closed toggle
  input  wire [7:0]  open_row,       // sprite ROM output for this scan row
  input  wire [7:0]  closed_row,     // same for closed-mouth
  input  wire [11:0] pac_x,          // sprite origin X
  input  wire [11:0] pac_y,          // sprite origin Y
  output reg  [11:0] pixel_color_out // final 12-bit RGB
);

  // Are we inside the 8×8 Pac-Man sprite box?
  wire in_sprite = (pixel_x >= pac_x) && (pixel_x < pac_x + SPRITE_SIZE)
                && (pixel_y >= pac_y) && (pixel_y < pac_y + SPRITE_SIZE);

  // Convert absolute pixel coords to sprite-local 3-bit coords
  wire [2:0] sx = pixel_x - pac_x;
  wire [2:0] sy = pixel_y - pac_y;

  // Select bit: if mouth_state=1 use open_row, else closed_row
  wire sprite_bit = mouth_state
                   ? open_row [sx]
                   : closed_row[sx];

  always @(*) begin
    if (!video_on) begin
      // black other than video
      pixel_color_out = 12'h000;
    end else if (in_sprite && sprite_bit) begin
      // if sprite_bit = 1, pacman color
      pixel_color_out = 12'hFF0; // 예: 노란색
    end else begin
      // elsewhere -> background color
      pixel_color_out = tile_color;
    end
  end

endmodule
