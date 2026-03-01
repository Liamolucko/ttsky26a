/*
 * Copyright (c) 2024 Uri Shaked
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_liamolucko_vga(
  input  wire [7:0] ui_in,    // Dedicated inputs
  output wire [7:0] uo_out,   // Dedicated outputs
  input  wire [7:0] uio_in,   // IOs: Input path
  output wire [7:0] uio_out,  // IOs: Output path
  output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
  input  wire       ena,      // always 1 when the design is powered, so you can ignore it
  input  wire       clk,      // clock
  input  wire       rst_n     // reset_n - low to reset
);

  // VGA signals
  wire hsync;
  wire vsync;
  wire [1:0] R;
  wire [1:0] G;
  wire [1:0] B;
  wire video_active;
  wire [9:0] pix_x;
  wire [9:0] pix_y;

  // TinyVGA PMOD
  assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};

  // Unused outputs assigned to 0.
  assign uio_out = 0;
  assign uio_oe  = 0;

  // Suppress unused signals warning
  wire _unused_ok = &{ena, ui_in, uio_in};

  reg [9:0] counter;

  hvsync_generator hvsync_gen(
    .clk(clk),
    .reset(~rst_n),
    .hsync(hsync),
    .vsync(vsync),
    .display_on(video_active),
    .hpos(pix_x),
    .vpos(pix_y)
  );

  wire [9:0] moving_x = pix_x + counter;

  // 640 x 480
  wire signed [9:0] centred_x;
  wire signed [9:0] centred_y;
  wire [18:0] centre_dist_sq;
  wire [18:0] offset;
  assign centred_x = pix_x - 320;
  assign centred_y = pix_y - 240;
  assign centre_dist_sq = centred_x * centred_x + centred_y * centred_y;
  assign offset = centre_dist_sq + {counter, 8'b0};

  reg signed [6:0] x_coeff;
  reg signed [6:0] y_coeff;
  always_comb begin
    case (counter[8:6])
      3'b000: begin
        x_coeff = {1'b0, counter[5:0]};
        y_coeff = 63;
      end
      3'b001: begin
        x_coeff = 63;
        y_coeff = 63 - counter[5:0];
      end
      3'b010: begin
        x_coeff = 63;
        y_coeff = ~{1'b0, counter[5:0]};
      end
      3'b011: begin
        x_coeff = 62 - counter[5:0];
        y_coeff = -63;
      end
      3'b100: begin
        x_coeff = -{1'b0, counter[5:0]};
        y_coeff = -63;
      end
      3'b101: begin
        x_coeff = -63;
        y_coeff = counter[5:0] - 63;
      end
      3'b110: begin
        x_coeff = -63;
        y_coeff = counter[5:0];
      end
      3'b111: begin
        x_coeff = counter[5:0] - 62;
        y_coeff = 63;
      end
      default: begin
        x_coeff = 1;
        y_coeff = 1;
      end
    endcase
  end

  wire in_semicircle;
  assign in_semicircle = x_coeff * centred_x + y_coeff * centred_y > 0;

  assign R = video_active && (counter[8] ? in_semicircle || centred_y < 0 : in_semicircle && centred_y < 0) ? offset[12:11] : 2'b00;
  assign G = video_active ? offset[14:13] : 2'b00;
  assign B = video_active ? offset[16:15] : 2'b00;

  always @(posedge vsync, negedge rst_n) begin
    if (~rst_n) begin
      counter <= 0;
    end else begin
      counter <= counter + 1;
    end
  end

  // Suppress unused signals warning
  wire _unused_ok_ = &{moving_x, pix_y};

endmodule
