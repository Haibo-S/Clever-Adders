module rca #(
    parameter int W = 2048,
    parameter M = 1,
    parameter int PIPE = 1  // 1 = pipelined (default), 0 = combinational
) (
    input  logic         clk,
    input  logic         rst,
    input  logic         in_valid,
    input  logic [W-1:0] a,
    input  logic [W-1:0] b,
    input  logic         c_in,
    output logic         out_valid,
    output logic [W-1:0] sum,
    output logic         c_out
);

logic out_valid_c, c_out_c;
logic [W-1:0] sum_c;

assign out_valid_c = in_valid;

assign {c_out_c, sum_c} = {1'b0, a} + {1'b0, b} + {{W{1'b0}}, c_in};

generate
    if (PIPE == 0) begin 
        always_comb begin
            c_out = c_out_c;
            out_valid = out_valid_c;
            sum = sum_c;
        end
    end else begin 
        always_ff @(posedge clk or posedge rst) begin
            if (rst) begin
                c_out <= 'b0;
                sum <= 'b0;
                out_valid <= 'b0;
            end else begin
                c_out <= c_out_c;
                out_valid <= out_valid_c;
                sum <= sum_c;
            end
        end
    end
endgenerate

endmodule
