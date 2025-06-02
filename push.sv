module button(
    input  clk,
    input  reset,
    input  sw_up,
    input  sw_left,
    input  sw_mid,
    input  sw_right,
    input  sw_down,
    output led1,
    output led2,
    output led3,
    output led4,
    output led5
);



reg led1_r, led2_r, led3_r, led4_r, led5_r;
always @(*) begin
    if (!reset) begin
        led1_r = 0;
        led2_r = 0;
        led3_r = 0;
        led4_r = 0;
        led5_r = 0;
    end else if (sw_down) begin
        led1_r = 1;
        led2_r = 0;
        led3_r = 0;
        led4_r = 0;
        led5_r = 0;
    end else if (sw_left) begin 
        led1_r = 0;
        led2_r = 1;
        led3_r = 0;
        led4_r = 0;
        led5_r = 0;
    end else if (sw_mid) begin
        led1_r = 0;
        led2_r = 0;
        led3_r = 1;
        led4_r = 0;
        led5_r = 0;
    end else if (sw_right) begin
        led1_r = 0;
        led2_r = 0;
        led3_r = 0;
        led4_r = 1;
        led5_r = 0;
    end else if (sw_up) begin
        led1_r = 0;
        led2_r = 0;
        led3_r = 0;
        led4_r = 0;
        led5_r = 1;
    end else begin
        led1_r = 0;
        led2_r = 0;
        led3_r = 0;
        led4_r = 0;
        led5_r = 0;
end
end

assign led1=led1_r;
assign led2=led2_r;
assign led3=led3_r;
assign led4=led4_r;
assign led5=led5_r;


endmodule


