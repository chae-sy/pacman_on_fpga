# Pacman Game on Xilinx Artix-7

**Course:** Digital System (SKKU ICE3024, Spring 2025)  
**Instructor:** Prof. Wansoo Lim

This repository contains the RTL design and supporting IPs to simulate a Pacman game at 1920 x 1080 /60 Hz monitor on a Xilinx Artix-7 FPGA(Project device xc7a75tfgg484-1), using Vivado 2018.3.

## Module Hierarchy
top_1080p_vga
├─ u_clk (clk_wiz_0.xci)
├─ u_vga (vga_controller.sv)
├─ u_btn (push.sv)
├─ u_map_init (blk_mem_gen_1.xci) ← Initial maze layout (Dual-Port ROM)
├─ u_map (blk_mem_gen_0.xci) ← Dynamic maze state (Single-Port ROM)
├─ u_pac (pman_ctrl.sv) ← Pacman controller
├─ u_enemy (enemy_ctrl.v) ← Enemy controller
├─ u_map_e0 (blk_mem_gen_0.xci) ← Enemy path memory 0
├─ u_map_e1 (blk_mem_gen_0.xci) ← Enemy path memory 1
├─ u_map_e2 (blk_mem_gen_0.xci) ← Enemy path memory 2
├─ u_map_e3 (blk_mem_gen_0.xci) ← Enemy path memory 3



## Getting Started

1. **Create the Clocking Wizard (clk_wiz_0.xci)**  
   - In Vivado: **Window → IP Catalog**, search for “Clocking Wizard.”  
   - In the **Customize IP** dialog, go to the **Output Clocks** tab.  
   - Enable **clk_out1** and set its **Output Frequency** to **148.500 MHz** (for a 60 Hz VGA refresh).

2. **Configure the Maze ROMs**

   - **Initial Maze Layout** (`blk_mem_gen_1.xci`)  
     - IP: **Block Memory Generator**  
     - Type: **Dual-Port ROM**  
     - Port A & B:  
       - Width: 4 bits  
       - Depth: 1296  
       - Write Mode: *Write First*  
       - Enable pin: **Use ENA / ENB**  
     - **Other Options**: Load initialization file `load_map.coe`

   - **Dynamic Maze State** (`blk_mem_gen_0.xci`)  
     - IP: **Block Memory Generator**  
     - Type: **Single-Port ROM**  
     - Port A:  
       - Width: 4 bits  
       - Depth: 1296  
       - Write Mode: *Write First*  
       - Enable pin: **Use ENA**  
     - **Other Options**: Load initialization file `load_map.coe`

3. **Implement and Simulate**  
   - Open the Vivado project.  
   - Add all RTL sources and IPs as shown in the hierarchy.  
   - Run synthesis, implement, and generate bitstream.  
   - Program the Artix-7 board and enjoy the Pacman simulation at 1080p/60 Hz!

---

Feel free to raise an issue if you encounter any setup problems or have questions about the design.  
Enjoy the game! 🎮  
