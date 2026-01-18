`include "tb/top.h"

/*verilator lint_off DECLFILENAME*/
module top (input clk, input rst);
  parameter N     = `N;
  parameter TESTS = `TESTS;

  // stimulus & expected
  logic [N-1:0] g_in      [TESTS];
  logic [N-1:0] p_in      [TESTS];
  logic [N-1:0] expected_c_array [TESTS];

  // DUT I/O
  logic [N-1:0] c;
  logic         in_valid;
  logic         out_valid;

  // DUT inputs (registered drive)
  logic [N-1:0] dut_g, dut_p;

  // bookkeeping
  integer errors, tests_run;
  integer idx;
  integer out_idx;
  logic   done, printed;

  initial begin
    $readmemh({`TESTDIR, "g.hex"},   g_in);
    $readmemh({`TESTDIR, "p.hex"},   p_in);
    $readmemh({`TESTDIR, "c.hex"},   expected_c_array);

    $display("=====================================");
    $display("Testbench Configuration:");
    $display("  Nidth: %0d bits", N);
    $display("  Tests: %0d", TESTS);
    $display("  Stages: %0d", $clog2(N));
    $display("=====================================");
  end

  typedef struct packed {logic [N-1:0] c;} exp_t;
  exp_t exp_q[$];

  /* verilator lint_off WIDTHTRUNC */

  prefix_tree #(.N(N)) dut (
    .clk       (clk),
    .rst       (rst),
    .in_valid  (in_valid),
    .g         (dut_g),
    .p         (dut_p),
    .c         (c),
    .out_valid (out_valid)
  );

  always_ff @(posedge clk) begin
    if (rst) begin
      in_valid   <= 1'b0;
      dut_g      <= '0;
      dut_p      <= '0;

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
        dut_g     <= g_in[idx];
        dut_p     <= p_in[idx];
        exp_q.push_back('{c: expected_c_array[idx]});
        idx       <= idx + 1;
      end else begin
        in_valid  <= 1'b0;
      end

      if (out_valid) begin
        if (exp_q.size() == 0) begin
          $error("out_valid asserted but expectation queue empty at out_idx=%0d", out_idx);
        end else begin
          static exp_t exp = exp_q.pop_front();

          $display("\nResult %0d:", out_idx);
          $display("  Outputs : c=0x%h", c);
          $display("  Expected: c=0x%h", exp.c);

          if (c !== exp.c) begin
            $display("  Result: ERROR - Mismatch!");
            // Show bit-by-bit comparison for debugging
            for (int b = 0; b < N; b++) begin
              if (c[b] !== exp.c[b]) begin
                $display("    Bit %0d: got %b, expected %b", b, c[b], exp.c[b]);
              end
            end
            errors <= errors + 1;
          end else begin
            $display("  Result: PASS");
          end
          tests_run <= tests_run + 1;
          out_idx   <= out_idx + 1;
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
