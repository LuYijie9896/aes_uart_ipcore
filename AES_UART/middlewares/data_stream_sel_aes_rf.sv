module data_stream_sel_aes_rf (
    input  logic en, 
    input  logic [1:0]wm,
    taxi_axis_if.snk s_axis,
    taxi_axis_if.src m0_axis, // to invcipher
    taxi_axis_if.src m1_axis, // to others
);
    always_comb begin
        if (wm == 2'b10 || (wm == 2'b00 && en == 1'b1)) begin
            // --- Route to Channel 0 ---
            m0_axis.tdata  = s_axis.tdata;
            m0_axis.tvalid = s_axis.tvalid;
            m0_axis.tlast  = s_axis.tlast;
            s_axis.tready  = m0_axis.tready;
            
            // --- Channel 1 Silent ---
            m1_axis.tvalid = 1'b0;
            m1_axis.tdata  = '0;
            m1_axis.tlast  = 1'b0;
        end else begin
            // --- Route to Channel 1 ---
            m1_axis.tdata  = s_axis.tdata;
            m1_axis.tvalid = s_axis.tvalid;
            m1_axis.tlast  = s_axis.tlast;
            s_axis.tready  = m1_axis.tready;
            
            // --- Channel 0 Silent ---
            m0_axis.tvalid = 1'b0;
            m0_axis.tdata  = '0;
            m0_axis.tlast  = 1'b0;
        end
    end
endmodule