`include "tb/top.h"

`ifndef TOPNAME
  `define TOPNAME rca_pipe
`endif

/*verilator lint_off DECLFILENAME*/
module top (input clk, input rst);
  parameter W     = `W;
  parameter M     = `M;
  parameter TESTS = `TESTS;

  localparam N = W / M;  // number of chunks

  // stimulus & expected
  logic [W-1:0] a      [TESTS];
  logic [W-1:0] b      [TESTS];
  logic         c_in   [TESTS];
  logic [W-1:0] expected_s_array   [TESTS];
  logic         expected_c_out_array[TESTS];

  // DUT I/O
  logic [W-1:0] s;
  logic         c_out;
  logic         in_valid;
  logic         out_valid;

  // DUT inputs (registered drive)
  logic [W-1:0] dut_a, dut_b;
  logic         dut_c_in;

  // bookkeeping
  integer errors, tests_run;
  integer idx;
  integer out_idx;
  logic   done, printed;

  initial begin
    $readmemh({`TESTDIR, "a.hex"},     a);
    $readmemh({`TESTDIR, "b.hex"},     b);
    $readmemh({`TESTDIR, "c_in.hex"},  c_in);
    $readmemh({`TESTDIR, "s.hex"},     expected_s_array);
    $readmemh({`TESTDIR, "c_out.hex"}, expected_c_out_array);

    $display("=====================================");
    $display("Testbench Configuration:");
    $display("  Width: %0d bits", W);
    $display("  Chunks: %0d (M=%0d)", N, M);
    $display("  Tests: %0d", TESTS);
    $display("=====================================");
  end

  typedef struct packed {logic [W-1:0] s; logic c;} exp_t;
  exp_t exp_q[$];

  /* verilator lint_off WIDTHTRUNC */

  `TOPNAME #(.W(W), .M(M)) dut (
    .clk    (clk),
    .rst    (rst),
    .in_valid (in_valid),
    .a      (dut_a),
    .b      (dut_b),
    .c_in   (dut_c_in),
    .sum    (s),
    .c_out  (c_out),
    .out_valid(out_valid)
  );

  always_ff @(posedge clk) begin
    if (rst) begin
      in_valid   <= 1'b0;
      dut_a      <= '0;
      dut_b      <= '0;
      dut_c_in   <= 1'b0;

      idx        <= 0;
      out_idx    <= 0;
      errors     <= 0;
      tests_run  <= 0;
      done       <= 0;
      printed    <= 0;
      exp_q.delete();
    end else begin
      if (idx < TESTS) begin
        in_valid  <= 1'b1;
        dut_a     <= a[idx];
        dut_b     <= b[idx];
        dut_c_in  <= c_in[idx];
        exp_q.push_back('{s: expected_s_array[idx], c: expected_c_out_array[idx]});
        idx       <= idx + 1;
      end else begin
        in_valid  <= 1'b0;
      end

      if (out_valid) begin
        if (exp_q.size() == 0) begin
          // $error("out_valid asserted but expectation queue empty at out_idx=%0d", out_idx);
        end else begin
          static exp_t exp = exp_q.pop_front();

          $display("\n=====================================");
          $display("Result %0d:", out_idx);
          $display("  Input: a=0x%h, b=0x%h, c_in=%b", dut_a, dut_b, dut_c_in);

          // Dump prefix tree internals (cleveradder2048b only)
          `ifdef DUMP_PREFIX
          if (`TOPNAME == cleveradder2048b) begin
            $display("  --- Level 1 (RCA outputs) ---");
            for (int i = 0; i < N-1; i++) begin
              $display("    Chunk[%0d]: sum_0=0x%h (c0=%b), sum_1=0x%h (c1=%b)",
                       i, dut.sum_0[i], dut.carry_0[i], dut.sum_1[i], dut.carry_1[i]);
            end

            $display("  --- Level 2 (Prefix Tree) ---");
            $display("    g_vec = 0b%b", dut.g_vec);
            $display("    p_vec = 0b%b", dut.p_vec);
            $display("    c_vec = 0b%b", dut.c_vec);

            $display("  --- Level 3 (Final sums) ---");
            for (int i = 0; i < N; i++) begin
              $display("    Chunk[%0d]: sum=0x%h (c=%b)",
                       i, dut.final_sum[i], dut.final_carry[i]);
            end
          end
          `endif

          $display("  Outputs : s=0x%08h, c_out=%b", s, c_out);
          $display("  Expected: s=0x%08h, c_out=%b", exp.s, exp.c);

          if (s !== exp.s || c_out !== exp.c) begin
            $display("  Result: ERROR - Mismatch!");

            // Show per-chunk comparison
            for (int i = 0; i < N; i++) begin
              logic [M-1:0] got_chunk;
              logic [M-1:0] exp_chunk;
              got_chunk = s[i*M +: M];
              exp_chunk = exp.s[i*M +: M];
              if (got_chunk !== exp_chunk) begin
                $display("    Chunk[%0d]: got=0x%h, expected=0x%h", i, got_chunk, exp_chunk);
              end
            end

            errors <= errors + 1;
          end else begin
            $display("  Result: PASS");
          end
          tests_run <= tests_run + 1;
          out_idx   <= out_idx + 1;
          $display("=====================================");
        end
      end

      if (!done && (idx == TESTS) && (exp_q.size() == 0)) begin
        done <= 1'b1;
      end

      if (done && !printed) begin
        printed <= 1'b1;
        $display("\n=====================================");
        $display("TEST SUMMARY:");
        $display("  Total tests run: %0d", tests_run);
        $display("  Passed: %0d", tests_run - errors);
        $display("  Failed: %0d", errors);
        $display("  GRADE: %0d", (errors == 0) ? 1 : 0);
        if (errors == 0) $display("  Result: ALL TESTS PASSED!");
        else             $display("  Result: %0d FAILURES DETECTED!", errors);
        $display("=====================================");
      end
    end
  end
  /* verilator lint_on WIDTHTRUNC */
endmodule
/*verilator lint_on DECLFILENAME*/
