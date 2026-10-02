// ============================================================================
// tb_main_control_block.sv  —  self-checking testbench for main_control_block
// Run:  iverilog -g2012 -o tb.vvp main_control_block.sv tb_main_control_block.sv
//       vvp tb.vvp
// ============================================================================
`timescale 1ns/1ps

module tb_main_control_block;
    logic        PE_Pulse = 1'b0;
    logic        rst_n    = 1'b1;
    logic [1:0]  Mode     = 2'b00;
    logic        LB_SPn   = 1'b0;
    logic        S_in     = 1'b0;

    logic [31:0] WL_Sel, BL_Sel, LB_en;
    logic        WL_Enable, WL_Zero, BL_Enable, BL_Zero;

    main_control_block dut (.*);

    int errors = 0;
    int checks = 0;

    task automatic check(input string what, input logic [31:0] got, input logic [31:0] exp);
        checks++;
        if (got !== exp) begin
            errors++;
            $display("FAIL  %-38s got=%h exp=%h  (t=%0t)", what, got, exp, $time);
        end
    endtask

    // One PE_Pulse rising edge with S_in = b
    task automatic pulse(input logic b);
        S_in = b;
        #20 PE_Pulse = 1'b1;
        #20 PE_Pulse = 1'b0;
        #10;
    endtask

    // Send a 5-bit code, MSB first
    task automatic send_code(input logic [4:0] code);
        for (int i = 4; i >= 0; i--) pulse(code[i]);
    endtask

    task automatic lb_pulse();
        #20 LB_SPn = 1'b1;
        #20 LB_SPn = 1'b0;
        #10;
    endtask

    function automatic logic [31:0] one_cold(input logic [4:0] n);
        return ~(32'd1 << n);
    endfunction

    function automatic logic [31:0] lb_mask(input logic [4:0] n);
        logic [31:0] m;
        for (int i = 0; i < 32; i++) m[i] = (i > n);
        return m;
    endfunction

    logic [31:0] wl_hold, bl_hold, lb_hold;

    initial begin
        // ---- Reset / Initialization ----
        #5  rst_n = 1'b0;
        #45 rst_n = 1'b1;
        #10;
        check("reset: LB_en",     LB_en, 32'hFFFF_0000);
        check("reset: WL_Sel",    WL_Sel, 32'h0);
        check("reset: BL_Sel",    BL_Sel, 32'h0);
        check("reset: WL_Enable", WL_Enable, 0);
        check("reset: BL_Enable", BL_Enable, 0);
        check("reset: WL_Zero",   WL_Zero, 0);
        check("reset: BL_Zero",   BL_Zero, 0);

        // ---- Idle: PE pulses without arming do nothing ----
        send_code(5'd9);
        check("idle: LB_en unchanged",  LB_en, 32'hFFFF_0000);
        check("idle: WL_Sel unchanged", WL_Sel, 32'h0);
        check("idle: BL_Sel unchanged", BL_Sel, 32'h0);

        // ---- Program mode: every code, back to back ----
        Mode = 2'b01; #10;
        check("program: WL_Enable", WL_Enable, 1);
        check("program: BL_Enable", BL_Enable, 0);
        for (int n = 0; n < 32; n++) begin
            send_code(n[4:0]);
            check($sformatf("program: WL_Sel code %0d", n), WL_Sel, one_cold(n[4:0]));
        end
        check("program: BL_Sel unchanged", BL_Sel, 32'h0);
        check("program: LB_en unchanged",  LB_en, 32'hFFFF_0000);

        // Selection only changes after a COMPLETE 5-bit code
        wl_hold = WL_Sel;
        pulse(1); pulse(0); pulse(1); pulse(1);
        check("program: held during partial code", WL_Sel, wl_hold);
        pulse(0);                                   // completes 10110 = 22
        check("program: applied on 5th bit", WL_Sel, one_cold(5'd22));

        // ---- Back to Idle: selections static, enables off ----
        wl_hold = WL_Sel;
        Mode = 2'b00; #10;
        check("idle: WL_Enable off", WL_Enable, 0);
        check("idle: WL_Sel kept",   WL_Sel, wl_hold);

        // ---- Erase mode ----
        Mode = 2'b10; #10;
        check("erase: BL_Enable", BL_Enable, 1);
        check("erase: WL_Enable", WL_Enable, 0);
        for (int n = 0; n < 32; n++) begin
            send_code(n[4:0]);
            check($sformatf("erase: BL_Sel code %0d", n), BL_Sel, one_cold(n[4:0]));
        end
        check("erase: WL_Sel unchanged", WL_Sel, wl_hold);
        check("erase: LB_en unchanged",  LB_en, 32'hFFFF_0000);

        // Program -> Erase directly re-aligns the frame on the mode change
        Mode = 2'b01; #10;
        pulse(1); pulse(1);                         // partial program code
        Mode = 2'b10; #10;
        send_code(5'd6);
        check("erase: realigned after mode change", BL_Sel, one_cold(5'd6));
        bl_hold = BL_Sel;

        // ---- Loop-back mode ----
        Mode = 2'b00; #10;
        for (int n = 0; n < 32; n++) begin
            lb_pulse();
            send_code(n[4:0]);
            check($sformatf("loopback: LB_en code %0d", n), LB_en, lb_mask(n[4:0]));
        end
        check("loopback: WL_Enable off",    WL_Enable, 0);
        check("loopback: BL_Enable off",    BL_Enable, 0);
        check("loopback: WL_Sel unchanged", WL_Sel, wl_hold);
        check("loopback: BL_Sel unchanged", BL_Sel, bl_hold);

        // Mask is kept until the next LB_SPn pulse
        lb_hold = LB_en;
        send_code(5'd3);
        check("loopback: ignored when not armed", LB_en, lb_hold);

        // A new LB_SPn pulse in the middle of a frame restarts the frame
        lb_pulse();
        pulse(1); pulse(1);
        lb_pulse();
        send_code(5'd4);
        check("loopback: re-arm restarts frame", LB_en, lb_mask(5'd4));

        // LB_SPn while in program mode must not arm the loop-back receiver
        lb_hold = LB_en;
        Mode = 2'b01; #10;
        lb_pulse();
        send_code(5'd12);
        check("program: code after LB_SPn", WL_Sel, one_cold(5'd12));
        Mode = 2'b00; #10;
        send_code(5'd1);
        check("loopback: not armed from program mode", LB_en, lb_hold);

        // ---- Mode 11 (undefined): no action ----
        wl_hold = WL_Sel;
        Mode = 2'b11; #10;
        send_code(5'd20);
        check("mode11: WL_Enable off",    WL_Enable, 0);
        check("mode11: BL_Enable off",    BL_Enable, 0);
        check("mode11: WL_Sel unchanged", WL_Sel, wl_hold);
        check("mode11: BL_Sel unchanged", BL_Sel, bl_hold);
        check("mode11: LB_en unchanged",  LB_en, lb_hold);

        // ---- Reset again from a configured state ----
        Mode = 2'b00;
        rst_n = 1'b0; #20 rst_n = 1'b1; #10;
        check("re-reset: LB_en",  LB_en, 32'hFFFF_0000);
        check("re-reset: WL_Sel", WL_Sel, 32'h0);
        check("re-reset: BL_Sel", BL_Sel, 32'h0);

        if (errors == 0) $display("=== ALL %0d CHECKS PASSED ===", checks);
        else             $display("=== %0d of %0d CHECKS FAILED ===", errors, checks);
        $finish;
    end
endmodule
