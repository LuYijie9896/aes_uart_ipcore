/* 
 * AXI-Stream 2-to-1 Multiplexer
 * sel=0: Route s0_axis to m_axis
 * sel=1: Route s1_axis to m_axis
 */
module axis_mux_2to1 (
    input  logic sel,
    taxi_axis_if.snk s0_axis,
    taxi_axis_if.snk s1_axis,
    taxi_axis_if.src m_axis
);
    always_comb begin
        if (sel == 1'b0) begin
            // --- Channel 0 Selected ---
            m_axis.tdata   = s0_axis.tdata;
            m_axis.tvalid  = s0_axis.tvalid;
            m_axis.tlast   = s0_axis.tlast;
            s0_axis.tready = m_axis.tready;
            
            // --- Channel 1 Blocked ---
            s1_axis.tready = 1'b0;
        end else begin
            // --- Channel 1 Selected ---
            m_axis.tdata   = s1_axis.tdata;
            m_axis.tvalid  = s1_axis.tvalid;
            m_axis.tlast   = s1_axis.tlast;
            s1_axis.tready = m_axis.tready;
            
            // --- Channel 0 Blocked ---
            s0_axis.tready = 1'b0;
        end
    end
endmodule

/* 
 * AXI-Stream 1-to-2 Demultiplexer
 * sel=0: Route s_axis to m0_axis
 * sel=1: Route s_axis to m1_axis
 */
module axis_demux_1to2 (
    input  logic sel, 
    taxi_axis_if.snk s_axis,
    taxi_axis_if.src m0_axis,
    taxi_axis_if.src m1_axis
);
    always_comb begin
        if (sel == 1'b0) begin
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