// ============================================================================
// main_control_block.sv  —  SNN chip Main Control Block (state machine)
//
// Implements the Program and Erase parts of the "Main Control Block – State
// Machine" slide of "Control block.pptx": a serial-configuration controller
// that receives a code on S_in and drives the WL / BL tuning selects.
//
// Loop-back (LB_SPn input, LB_en output) is intentionally NOT implemented
// for now.
//
// Modes (Mode[1:0]):
//   00  Idle      no action, selections are kept
//   01  Program   5-bit code -> WL_Sel (one switch disabled),
//                 WL_Enable asserted
//   10  Erase     6-bit code -> BL_Sel (one switch disabled),
//                 BL_Enable asserted
//   11  (undefined on the slide) treated as Idle
//
// Serial protocol: on each rising edge of PE_Pulse one bit of S_in is
// shifted in, MSB first. The Program code is 5 bits (32 word lines); the
// Erase code is 6 bits because there are 64 bit-line switches (32 positive +
// 32 negative). After the last bit the code N is applied:
//   Program  : WL_Sel[N] = 0, all other WL_Sel = 1      (N = 0..31)
//   Erase    : BL_Sel[N] = 0, all other BL_Sel = 1      (N = 0..63)
// The selection is held until the next complete code.
//
// Design decisions where the slides leave it open (see README.md):
//   * PE_Pulse is the ONLY clock - the block diagram has no system clock
//     pad. So the "state" of the slide's state machine is Mode itself; there
//     is no state register that would need a clock edge to follow Mode.
//     WL_Enable / BL_Enable are decoded straight from Mode for that reason.
//   * rst_n (asynchronous, active-low) is added for the slide's
//     "Reset / Initialization" box; it is not drawn as a pad on the diagram.
//   * A new frame starts on the first PE_Pulse edge after Mode changes.
//     That edge already carries the first (MSB) bit.
//   * BL_Sel is 64 bits (block diagram: BL_Sel[0:63]) and the Erase code is
//     6 bits. The state-machine slide still shows a 5-bit code and
//     BL_Sel<31:0> for Erase; the 6-bit width was confirmed separately.
//   * WL_Zero / BL_Zero are tied to 0 ("as defined, usually 0").
//   * WL_Sel / BL_Sel reset to all-0 (every switch disabled = no action).
//   * The Bias shift register / BCode[0:39] of Ctrl2 is not part of the
//     state-machine slide and is not implemented here.
// ============================================================================

module main_control_block (
    input  logic        PE_Pulse,    // serial shift clock (PE_Pulse_c)
    input  logic        rst_n,       // asynchronous reset, active-low
    input  logic [1:0]  Mode,        // 00 idle, 01 program, 10 erase
    input  logic        S_in,        // serial data, MSB first

    output logic [31:0] WL_Sel,
    output logic        WL_Enable,
    output logic        WL_Zero,
    output logic [63:0] BL_Sel,
    output logic        BL_Enable,
    output logic        BL_Zero
);
    localparam logic [1:0] MODE_PROGRAM = 2'b01;
    localparam logic [1:0] MODE_ERASE   = 2'b10;

    logic [1:0] mode_q;        // Mode seen at the previous PE_Pulse edge
    logic [2:0] bit_cnt;       // bits already received in the current frame
    logic [4:0] wl_sr;         // program code is 5 bits (32 WL switches)
    logic [5:0] bl_sr;         // erase code is 6 bits (64 BL switches)

    // Code as it will be once the bit arriving on this edge is shifted in.
    wire [4:0] wl_code = {wl_sr[3:0], S_in};
    wire [5:0] bl_code = {bl_sr[4:0], S_in};

    wire frame_start = (Mode != mode_q);
    wire last_bit5   = !frame_start && (bit_cnt == 3'd4);   // 5-bit program code
    wire last_bit6   = !frame_start && (bit_cnt == 3'd5);   // 6-bit erase code

    always_ff @(posedge PE_Pulse or negedge rst_n) begin
        if (!rst_n) begin
            mode_q  <= 2'b00;
            bit_cnt <= 3'd0;
            wl_sr   <= 5'b0;
            bl_sr   <= 6'b0;
            WL_Sel  <= 32'h0;
            BL_Sel  <= 64'h0;
        end else begin
            mode_q <= Mode;

            case (Mode)
                MODE_PROGRAM: begin
                    wl_sr <= wl_code;
                    if (last_bit5) begin
                        WL_Sel  <= ~(32'd1 << wl_code);
                        bit_cnt <= 3'd0;
                    end else begin
                        bit_cnt <= frame_start ? 3'd1 : bit_cnt + 3'd1;
                    end
                end

                MODE_ERASE: begin
                    bl_sr <= bl_code;
                    if (last_bit6) begin
                        BL_Sel  <= ~(64'd1 << bl_code);
                        bit_cnt <= 3'd0;
                    end else begin
                        bit_cnt <= frame_start ? 3'd1 : bit_cnt + 3'd1;
                    end
                end

                default: begin                  // Idle (00) and 11: no action
                    bit_cnt <= 3'd0;
                end
            endcase
        end
    end

    // Enables follow Mode directly (no clock edge is available on mode
    // entry); in Idle both are 0.
    assign WL_Enable = (Mode == MODE_PROGRAM);
    assign BL_Enable = (Mode == MODE_ERASE);
    assign WL_Zero   = 1'b0;
    assign BL_Zero   = 1'b0;

endmodule
