module data_stream_sel_aes_tf (
    input  logic en,
    input  logic [1:0]wm,
    my_axis_if.slave  s0_axis, // to cipher
    my_axis_if.slave  s1_axis, // to others
    my_axis_if.master m_axis
);
    always_comb begin
        if (wm == 2'b01 || (wm == 2'b00 && en == 1'b1)) begin
            // --- Channel 0  ---
            m_axis.tdata   = s0_axis.tdata;
            m_axis.tvalid  = s0_axis.tvalid;
            m_axis.tlast   = s0_axis.tlast;
            s0_axis.tready = m_axis.tready;
            
            // --- Channel 1 Blocked ---
            s1_axis.tready = 1'b0;
        end else begin
            // --- Channel 1  ---
            m_axis.tdata   = s1_axis.tdata;
            m_axis.tvalid  = s1_axis.tvalid;
            m_axis.tlast   = s1_axis.tlast;
            s1_axis.tready = m_axis.tready;
            
            // --- Channel 0 Blocked ---
            s0_axis.tready = 1'b0;
        end
    end
endmodule