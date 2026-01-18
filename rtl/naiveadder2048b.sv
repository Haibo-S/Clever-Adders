module naiveadder2048b #(
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

localparam int N = (W + M - 1) / M;

logic [W-1:0] core_sum;
logic         core_c_out;
logic         core_valid;

rca #(
    .W(W),
    .M(M)
) u_csa_core_full (
    .clk       (clk),
    .rst       (rst),
    .in_valid  (in_valid),
    .a         (a),
    .b         (b),
    .c_in      (c_in),
    .out_valid (core_valid),
    .sum       (core_sum),
    .c_out     (core_c_out)
);

logic [N-1:0]        c_in1;
logic [N-1:0]        c_out1;
logic [N-1:0]        out_valid1;
logic [N-1:0][M-1:0] sum1;

assign c_in1 = {{(N-1){1'b0}}, c_in};

generate
    for (genvar i = 0; i < N; i = i + 1) begin 
        localparam int L      = i * M;
        localparam int BLK_W  = (L + M <= W) ? M : (W - L);

        logic [M-1:0] a_seg;
        logic [M-1:0] b_seg;

        if (L + M <= W) begin 
            assign a_seg = a[(i+1)*M - 1 : i*M];
            assign b_seg = b[(i+1)*M - 1 : i*M];
        end else begin 
            assign a_seg = { {(M-BLK_W){1'b0}}, a[L +: BLK_W] };
            assign b_seg = { {(M-BLK_W){1'b0}}, b[L +: BLK_W] };
        end

        rca #(
            .M(N),
            .W(M)
        ) u_csa1 (
            .clk       (clk),
            .rst       (rst),
            .in_valid  (in_valid),
            .a         (a_seg),
            .b         (b_seg),
            .c_in      (c_in1[i]),
            .out_valid (out_valid1[i]),
            .sum       (sum1[i]),
            .c_out     (c_out1[i])
        );
    end
endgenerate

generate
    if (N > 2) begin 
        logic [N-1:0]        c_2;
        assign c_2[0] = c_out1[0];

        logic [N-2:0][M-1:0] sum_2;
        logic [N-2:0]        out_valid_2;

        logic [N-1:0]        out_valid_c;

        for (genvar i = 1; i < N; i = i + 1) begin 
            if (i != 1) begin
                logic [i-2:0][M-1:0] pipe_stages_sum;
                logic [i-2:0]        pipe_stages_valid;
                logic [i-1:0]        pipe_stages_cout;

                if (i == 2) begin
                    always_ff @(posedge clk) begin
                        if (rst) begin
                            pipe_stages_sum   <= '0;
                            pipe_stages_valid <= '0;
                            pipe_stages_cout  <= '0;
                        end else begin
                            pipe_stages_sum   <= sum1[i];
                            pipe_stages_valid <= out_valid1[i];
                            pipe_stages_cout  <= {pipe_stages_cout[0], c_out1[i-1]};
                        end
                    end
                end else begin
                    always_ff @(posedge clk) begin
                        if (rst) begin
                            pipe_stages_sum   <= '0;
                            pipe_stages_valid <= '0;
                            pipe_stages_cout  <= '0;
                        end else begin
                            pipe_stages_sum   <= {pipe_stages_sum[i-3:0], sum1[i]};
                            pipe_stages_valid <= {pipe_stages_valid[i-3:0], out_valid1[i]};
                            pipe_stages_cout  <= {pipe_stages_cout[i-2:0],  c_out1[i-1]};
                        end
                    end
                end

                rca #(
                    .M(N),
                    .W(M)
                ) u_csa2 (
                    .clk       (clk),
                    .rst       (rst),
                    .in_valid  (pipe_stages_valid[i-2]),
                    .a         ({{(M-1){1'b0}}, pipe_stages_cout[i-2]}),
                    .b         (pipe_stages_sum[i-2]),
                    .c_in      (c_2[i-1]),
                    .out_valid (out_valid_2[i-1]),
                    .sum       (sum_2[i-1]),
                    .c_out     (c_2[i])
                );
            end else begin
                rca #(
                    .M(N),
                    .W(M)
                ) u_csa2 (
                    .clk       (clk),
                    .rst       (rst),
                    .in_valid  (out_valid1[i]),
                    .a         ('0),
                    .b         (sum1[i]),
                    .c_in      (c_2[i-1]),
                    .out_valid (out_valid_2[i-1]),
                    .sum       (sum_2[i-1]),
                    .c_out     (c_2[i])
                );
            end
        end

        for (genvar j = N-1; j > 0; j = j - 1) begin 
            localparam int L      = j * M;
            localparam int BLK_W  = (L + M <= W) ? M : (W - L);

            if (j != N-1) begin
                logic [N-j-1-1:0][M-1:0] pipe_stages_sum2;
                logic [N-j-1-1:0]        pipe_stages_valid2;

                if (j == N-2) begin
                    always_ff @(posedge clk) begin
                        if (rst) begin
                            pipe_stages_sum2   <= '0;
                            pipe_stages_valid2 <= '0;
                        end else begin
                            pipe_stages_sum2   <= sum_2[j-1];
                            pipe_stages_valid2 <= out_valid_2[j-1];
                        end
                    end
                end else begin
                    always_ff @(posedge clk) begin
                        if (rst) begin
                            pipe_stages_sum2   <= '0;
                            pipe_stages_valid2 <= '0;
                        end else begin
                            pipe_stages_sum2   <= {pipe_stages_sum2[N-j-1-1-1:0], sum_2[j-1]};
                            pipe_stages_valid2 <= {pipe_stages_valid2[N-j-1-1-1:0], out_valid_2[j-1]};
                        end
                    end
                end

                if (L + M <= W) begin
                    assign sum[M*(j+1)-1 : M*j] = pipe_stages_sum2[N-j-1-1];
                end else begin
                    assign sum[L +: BLK_W]      = pipe_stages_sum2[N-j-1-1][BLK_W-1:0];
                end

                assign out_valid_c[j] = pipe_stages_valid2[N-j-1-1];
            end else begin
                if (L + M <= W) begin
                    assign sum[M*(j+1)-1 : M*j] = sum_2[j-1];
                end else begin
                    assign sum[L +: BLK_W]      = sum_2[j-1][BLK_W-1:0];
                end

                assign out_valid_c[j] = out_valid_2[j-1];
            end
        end

        logic [N-2:0][M-1:0] pipe_first_sum;
        logic [N-2:0]        pipe_first_valid;
        logic [N-2:0]        pipe_top_right_cout;

        always_ff @(posedge clk) begin
            if (rst) begin
                pipe_first_valid    <= '0;
                pipe_first_sum      <= '0;
                pipe_top_right_cout <= '0;
            end else begin
                pipe_first_valid    <= {pipe_first_valid[N-3:0],    out_valid1[0]};
                pipe_first_sum      <= {pipe_first_sum[N-3:0],      sum1[0]};
                pipe_top_right_cout <= {pipe_top_right_cout[N-3:0], c_out1[N-1]};
            end
        end

        assign sum[M-1:0]    = pipe_first_sum[N-2];
        assign out_valid_c[0] = pipe_first_valid[N-2];

        assign out_valid = &out_valid_c;

    end else if (N == 2) begin 
       
        logic [W-1:0] sum_reg;
        logic         valid_reg;

        always_ff @(posedge clk) begin
            if (rst) begin
                sum_reg   <= '0;
                valid_reg <= 1'b0;
            end else begin
                sum_reg   <= core_sum;
                valid_reg <= core_valid;
            end
        end

        assign sum       = sum_reg;
        assign out_valid = valid_reg;

    end else begin 
       
        logic dummy_c_out;

        rca #(
            .M(N),
            .W(M)
        ) u_csa_single (
            .clk       (clk),
            .rst       (rst),
            .in_valid  (in_valid),
            .a         (a),
            .b         (b),
            .c_in      (c_in),
            .out_valid (out_valid),
            .sum       (sum),
            .c_out     (dummy_c_out)
        );
    end
endgenerate

generate
    if (N <= 1) begin 
        assign c_out = core_c_out;
    end else begin 
        logic [N-2:0] cout_pipe;

        always_ff @(posedge clk) begin
            if (rst) begin
                cout_pipe <= '0;
            end else begin
                cout_pipe[0] <= core_c_out;
                for (int k = 1; k < N-1; k = k + 1) begin
                    cout_pipe[k] <= cout_pipe[k-1];
                end
            end
        end

        assign c_out = cout_pipe[N-2];
    end
endgenerate

endmodule
