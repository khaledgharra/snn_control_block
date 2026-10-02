// ============================================================================
// tb_demo.sv  —  prints what main_control_block does, step by step
// (tb_main_control_block.sv is the pass/fail test; this one is for looking.)
//
// Run:  iverilog -g2012 -o demo.vvp main_control_block.sv tb_demo.sv
//       vvp demo.vvp
//
// Change the codes in the "initial" block at the bottom to try your own.
// It also writes demo.vcd, which any waveform viewer can open.
// ============================================================================
`timescale 1ns/1ps

module tb_demo;
    logic        PE_Pulse = 1'b0;
    logic        rst_n    = 1'b1;
    logic [1:0]  Mode     = 2'b00;
    logic        S_in     = 1'b0;

    logic [31:0] WL_Sel;
    logic [63:0] BL_Sel;
    logic        WL_Enable, WL_Zero, BL_Enable, BL_Zero;

    main_control_block dut (.*);

    // Print one line every time a bit is clocked in.
    task automatic pulse(input logic b);
        S_in = b;
        #20 PE_Pulse = 1'b1;
        #20 PE_Pulse = 1'b0;
        #10;
        $display("  pulse  S_in=%b   | Mode=%b WL_En=%b BL_En=%b | WL_Sel=%h | BL_Sel=%h",
                 b, Mode, WL_Enable, BL_Enable, WL_Sel, BL_Sel);
    endtask

    // Program: 5-bit code, MSB first
    task automatic program_code(input logic [4:0] code);
        $display("\nPROGRAM code %0d (%b) - expect WL_Sel bit %0d = 0 after the 5th pulse", code, code, code);
        Mode = 2'b01; #10;
        for (int i = 4; i >= 0; i--) pulse(code[i]);
    endtask

    // Erase: 6-bit code, MSB first
    task automatic erase_code(input logic [5:0] code);
        $display("\nERASE code %0d (%b) - expect BL_Sel bit %0d = 0 after the 6th pulse", code, code, code);
        Mode = 2'b10; #10;
        for (int i = 5; i >= 0; i--) pulse(code[i]);
    endtask

    task automatic idle();
        Mode = 2'b00; #10;
        $display("\nIDLE                 | Mode=%b WL_En=%b BL_En=%b | WL_Sel=%h | BL_Sel=%h",
                 Mode, WL_Enable, BL_Enable, WL_Sel, BL_Sel);
    endtask

    initial begin
        $dumpfile("demo.vcd");
        $dumpvars(0, tb_demo);

        #5  rst_n = 1'b0;
        #45 rst_n = 1'b1;
        #10;
        $display("AFTER RESET          | Mode=%b WL_En=%b BL_En=%b | WL_Sel=%h | BL_Sel=%h",
                 Mode, WL_Enable, BL_Enable, WL_Sel, BL_Sel);

        // ---- change these to try your own codes ----
        program_code(5'd5);
        program_code(5'd31);
        idle();
        erase_code(6'd0);
        erase_code(6'd40);
        erase_code(6'd63);
        idle();

        $display("");
        $finish;
    end
endmodule
