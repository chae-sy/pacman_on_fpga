# 100MHz 클럭
set_property PACKAGE_PIN R4      [get_ports sys_clk_100m]
set_property IOSTANDARD LVCMOS33 [get_ports sys_clk_100m]
create_clock -name sys_clk_100m -period 10.0 [get_ports sys_clk_100m]

# 리셋 스위치 (SW23)
set_property PACKAGE_PIN U7      [get_ports rstn]
set_property IOSTANDARD LVCMOS33 [get_ports rstn]
set_property PULLUP TRUE         [get_ports rstn]


# VGA Red
set_property PACKAGE_PIN H17     [get_ports vga_r[0]] ;# R1
set_property PACKAGE_PIN G17     [get_ports vga_r[1]] ;# R2
set_property PACKAGE_PIN H18     [get_ports vga_r[2]] ;# R3
set_property PACKAGE_PIN G18     [get_ports vga_r[3]] ;# R4
# VGA Green
set_property PACKAGE_PIN J19     [get_ports vga_g[0]] ;# G1
set_property PACKAGE_PIN H19     [get_ports vga_g[1]] ;# G2
set_property PACKAGE_PIN H20     [get_ports vga_g[2]] ;# G3
set_property PACKAGE_PIN G20     [get_ports vga_g[3]] ;# G4
# VGA Blue
set_property PACKAGE_PIN J20     [get_ports vga_b[0]] ;# B1
set_property PACKAGE_PIN J21     [get_ports vga_b[1]] ;# B2
set_property PACKAGE_PIN H22     [get_ports vga_b[2]] ;# B3
set_property PACKAGE_PIN J22     [get_ports vga_b[3]] ;# B4
# VGA Sync
set_property PACKAGE_PIN K22     [get_ports vga_hs]
set_property PACKAGE_PIN K21     [get_ports vga_vs]

# IOSTANDARD 설정 (모두 3.3V LVCMOS33)
set_property IOSTANDARD LVCMOS33 [get_ports {vga_r[*] vga_g[*] vga_b[*] vga_hs vga_vs}]


set_property -dict {PACKAGE_PIN N22 IOSTANDARD LVCMOS33} [get_ports sw_up]
set_property -dict {PACKAGE_PIN M22 IOSTANDARD LVCMOS33} [get_ports sw_left]
set_property -dict {PACKAGE_PIN M21 IOSTANDARD LVCMOS33} [get_ports sw_mid]
set_property -dict {PACKAGE_PIN M20 IOSTANDARD LVCMOS33} [get_ports sw_down]
set_property -dict {PACKAGE_PIN N20 IOSTANDARD LVCMOS33} [get_ports sw_right]

set_property -dict {PACKAGE_PIN Y18  IOSTANDARD LVCMOS33} [get_ports led1]
set_property -dict {PACKAGE_PIN AA18  IOSTANDARD LVCMOS33} [get_ports led2]
set_property -dict {PACKAGE_PIN AB18  IOSTANDARD LVCMOS33} [get_ports b_led1]
set_property -dict {PACKAGE_PIN W19  IOSTANDARD LVCMOS33} [get_ports b_led2]
set_property -dict {PACKAGE_PIN Y19  IOSTANDARD LVCMOS33} [get_ports b_led3]
set_property -dict {PACKAGE_PIN AA19  IOSTANDARD LVCMOS33} [get_ports b_led4]
set_property -dict {PACKAGE_PIN W20  IOSTANDARD LVCMOS33} [get_ports b_led5]





