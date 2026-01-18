module prefix_tree #(
    parameter N = 32,
    parameter PIPE = 1  // 1 = pipeline output, 0 = combinational
) (
    input  logic          clk,
    input  logic          rst,
    input  logic [N-1:0]  g,
    input  logic [N-1:0]  p,
    input  logic          in_valid,
    output logic [N-1:0]  c,
    output logic          out_valid
);
    localparam STAGES = $clog2(N);

    logic [N-1:0] g_int, p_int;
    logic [N-1:0] c_comb;

    integer i, j;

    always_comb begin
        g_int = g;
        p_int = p;
        
        g_int[0] = g_int[0] | (p_int[0] & 1'b0);

        for (i = 0; i < STAGES; i = i + 1) begin
            for (j = N-1; j >= (1 << i); j = j - 1) begin
                g_int[j] = g_int[j] | (p_int[j] & g_int[j - (1 << i)]);
                p_int[j] = p_int[j] & p_int[j - (1 << i)];
            end
        end

        c_comb = g_int;
    end

    generate
        if (PIPE == 0) begin 
            always_comb begin
                c         = c_comb;
                out_valid = in_valid;
            end
        end else begin 
            always_ff @(posedge clk) begin
                if (rst) begin
                    c         <= '0;
                    out_valid <= 1'b0;
                end else begin
                    c         <= c_comb;
                    out_valid <= in_valid;
                end
            end
        end
    endgenerate


endmodule
