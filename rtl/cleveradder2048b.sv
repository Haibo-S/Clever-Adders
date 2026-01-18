module cleveradder2048b #(
    parameter W = 2048,
    parameter M = 64,
    parameter PIPE = 1
) (
    input  logic          clk,
    input  logic          rst,
    input  logic [W-1:0]  a,
    input  logic [W-1:0]  b,
    input  logic          c_in,
    input  logic          in_valid,
    output logic [W-1:0]  sum,
    output logic          c_out,
    output logic          out_valid
);

    localparam N = W / M;  // number of chunks

    localparam int N_SEGS = (N > 1) ? (N-1) : 1;

    /* verilator lint_off UNOPTFLAT */
    logic [M-1:0] a_chunk [N-1:0];
    logic [M-1:0] b_chunk [N-1:0];

    genvar gi;
    generate
        for (gi = 0; gi < N; gi++) begin : gen_chunk_view
            assign a_chunk[gi] = a[gi*M +: M];
            assign b_chunk[gi] = b[gi*M +: M];
        end
    endgenerate

    logic [M-1:0]     sum_G  [N_SEGS-1:0];
    logic [N_SEGS-1:0] g_seg;
    logic [N_SEGS-1:0] p_seg;

    generate
        if (N > 1) begin
            for (gi = 0; gi < N-1; gi++) begin : gen_gp
                logic        dummy_valid_g, dummy_valid_p;
                logic [M-1:0] unused_sum_p;

                rca #(.W(M), .M(1), .PIPE(0)) u_rca_G (
                    .clk       (clk),
                    .rst       (rst),
                    .in_valid  (in_valid),
                    .a         (a_chunk[gi]),
                    .b         (b_chunk[gi]),
                    .c_in      (1'b0),
                    .out_valid (dummy_valid_g),
                    .sum       (sum_G[gi]),
                    .c_out     (g_seg[gi])
                );

                rca #(.W(M), .M(1), .PIPE(0)) u_rca_P (
                    .clk       (clk),
                    .rst       (rst),
                    .in_valid  (in_valid),
                    .a         (a_chunk[gi]),
                    .b         (b_chunk[gi]),
                    .c_in      (1'b1),
                    .out_valid (dummy_valid_p),
                    .sum       (unused_sum_p),
                    .c_out     (p_seg[gi])
                );
            end
        end
    endgenerate

    logic [N_SEGS-1:0] g_seg_mod;
    logic [N_SEGS-1:0] c_seg;        
    logic              prefix_valid; 

    always_comb begin
        g_seg_mod = g_seg;
        if (N > 1)
            g_seg_mod[0] = g_seg[0] | (p_seg[0] & c_in);  
    end

    generate
        if (N > 1) begin : gen_prefix_tree
            prefix_tree #(
                .N (N_SEGS),
                .PIPE(1)        
            ) u_prefix (
                .clk      (clk),
                .rst      (rst),
                .g        (g_seg_mod),
                .p        (p_seg),
                .in_valid (in_valid),
                .c        (c_seg),
                .out_valid(prefix_valid)
            );
        end else begin : gen_no_prefix
            always_comb begin
                prefix_valid = in_valid;
            end
        end
    endgenerate

    // pipeline
    logic [M-1:0] sum_G_pipe [N_SEGS-1:0];
    logic [M-1:0] a_msb_pipe, b_msb_pipe;
    logic         c_in_pipe;

    integer si;
    always_ff @(posedge clk) begin
        if (rst) begin
            for (si = 0; si < N_SEGS; si++)
                sum_G_pipe[si] <= '0;
            a_msb_pipe <= '0;
            b_msb_pipe <= '0;
            c_in_pipe  <= 1'b0;
        end else begin
            for (si = 0; si < N_SEGS; si++)
                sum_G_pipe[si] <= sum_G[si];
            a_msb_pipe <= a_chunk[N-1];
            b_msb_pipe <= b_chunk[N-1];
            c_in_pipe  <= c_in;
        end
    end

    logic [N-1:0] carry_chunk;

    always_comb begin
        carry_chunk = '0;
        carry_chunk[0] = c_in_pipe;          

        if (N > 1) begin
            for (int i = 1; i < N; i++)
                carry_chunk[i] = c_seg[i-1];
        end
    end

    logic [M-1:0] sum_chunk [N-1:0];
    logic         c_out_comb;

    generate
        if (N > 1) begin
            for (gi = 0; gi < N-1; gi++) begin : gen_fin
                logic dummy_valid_f, dummy_cout_f;
                rca #(.W(M), .M(1), .PIPE(0)) u_rca_final (
                    .clk       (clk),
                    .rst       (rst),
                    .in_valid  (prefix_valid),
                    .a         (sum_G_pipe[gi]),
                    .b         ({M{1'b0}}),
                    .c_in      (carry_chunk[gi]),
                    .out_valid (dummy_valid_f),
                    .sum       (sum_chunk[gi]),
                    .c_out     (dummy_cout_f)
                );
            end
        end
    endgenerate

    generate
        if (N > 0) begin
            logic dummy_valid_ms;
            rca #(.W(M), .M(1), .PIPE(0)) u_rca_ms (
                .clk       (clk),
                .rst       (rst),
                .in_valid  (prefix_valid),
                .a         (a_msb_pipe),
                .b         (b_msb_pipe),
                .c_in      (carry_chunk[N-1]),
                .out_valid (dummy_valid_ms),
                .sum       (sum_chunk[N-1]),
                .c_out     (c_out_comb)
            );
        end
    endgenerate

    logic [W-1:0] sum_comb;
    always_comb begin
        for (int i = 0; i < N; i++)
            sum_comb[i*M +: M] = sum_chunk[i];
    end

    logic [W-1:0] sum_reg;
    logic         c_out_reg, valid_reg;

    wire valid_comb = prefix_valid;

    generate
        if (PIPE == 0) begin
            always_comb begin
                sum       = sum_comb;
                c_out     = c_out_comb;
                out_valid = valid_comb;
            end
        end else begin
            always_ff @(posedge clk) begin
                if (rst) begin
                    sum_reg   <= '0;
                    c_out_reg <= 1'b0;
                    valid_reg <= 1'b0;
                end else begin
                    sum_reg   <= sum_comb;
                    c_out_reg <= c_out_comb;
                    valid_reg <= valid_comb;
                end
            end

            always_comb begin
                sum       = sum_reg;
                c_out     = c_out_reg;
                out_valid = valid_reg;
            end
        end
    endgenerate

endmodule
