module regs_aes_bridge (
    input logic clk,    
    input logic rst,  

    input logic [1:0]wm,
    input logic ee,
    input logic de,
    input logic idle,

    taxi_axis_if.snk s_axis_r_8,        // from tdr
    taxi_axis_if.snk s_axis_r_128,      // from epr
    taxi_axis_if.src m_axis_8,          // to sel
    taxi_axis_if.src m_axis_128,        // to cipher

    taxi_axis_if.src m_axis_r_8,        // to rdr
    taxi_axis_if.src m_axis_r_128,      // to dpr
    taxi_axis_if.snk s_axis_8,          // from sel
    taxi_axis_if.snk s_axis_128         // from invcipher
);

// internal signal
logic [3:0]     m01_byte_cnt    ;
logic           m01_sending     ;
logic [127:0]   m01_data_buf    ;
logic [3:0]     m01_length      ;  // Length prefix: stores actual data byte count
logic [4:0]     m10_byte_cnt    ; 
logic           m10_busy        ;
logic [127:0]   m10_data_buf    ;
logic [3:0]     m10_length      ;  // Extracted length from decrypted data

// wm=01: Automatically receive unencrypted data, add length prefix, and encrypt.
// Protocol: [Length (1B)] [Data (N bytes)] [Zero Padding (15-N bytes)]
// Length byte is stored at m01_data_buf[7:0], data starts at m01_data_buf[15:8]
always_ff @(posedge clk) begin
    if (rst) begin
        m01_byte_cnt <= '0;
        m01_sending  <= 1'b0;
        m01_data_buf <= '0;
        m01_length   <= '0;
    end else if (wm == 2'b01) begin
        // If the data collection is complete and needs to be sent
        if (m01_sending) begin
            if (m_axis_128.tready && m_axis_128.tvalid) begin
                m01_sending  <= 1'b0;
                m01_byte_cnt <= '0;
                m01_data_buf <= '0;
                m01_length   <= '0;
            end
        end else begin
            // Trigger encryption when: idle with data OR received 15 data bytes (max payload)
            if (idle && m01_byte_cnt != 0) begin
                // Store the length in byte 0 before sending
                m01_data_buf[7:0] <= {4'd0, m01_byte_cnt};
                m01_sending <= 1'b1;
            end 
            else if (s_axis_8.tvalid && s_axis_8.tready) begin
                // Store data starting from byte 1 (byte 0 reserved for length)
                m01_data_buf[(m01_byte_cnt + 1) * 8 +: 8] <= s_axis_8.tdata;
                m01_length <= m01_byte_cnt + 1'b1;
                
                // Max 15 data bytes (byte 0 is length, bytes 1-15 are data)
                if (m01_byte_cnt == 4'd14) begin
                    m01_data_buf[7:0] <= 8'd15;  // Length = 15
                    m01_sending <= 1'b1;
                    m01_byte_cnt <= '0;
                end else begin
                    m01_byte_cnt <= m01_byte_cnt + 1'b1;
                end
            end
        end
    end else begin
        m01_byte_cnt <= '0;
        m01_sending  <= 1'b0;
        m01_length   <= '0;
    end
end


// wm=10: Automatically receive encrypted data, decrypt, extract length, send only valid bytes.
// Protocol: Decrypted data is [Length (1B)] [Data (N bytes)] [Padding]
// Only send N bytes starting from byte 1 (skip length byte at position 0)
always_ff @(posedge clk) begin
    if (rst) begin
        m10_busy     <= 1'b0;
        m10_byte_cnt <= '0;
        m10_data_buf <= '0;
        m10_length   <= '0;
    end else if (wm == 2'b10) begin
        if (!m10_busy) begin
            // Receive 128-bit decrypted data
            if (s_axis_128.tvalid && s_axis_128.tready) begin
                m10_data_buf <= s_axis_128.tdata;
                m10_length   <= s_axis_128.tdata[3:0];  // Extract length from byte 0
                // Only enter busy state if there's data to send (length > 0)
                m10_busy     <= (s_axis_128.tdata[3:0] != 4'd0);
                m10_byte_cnt <= '0;
            end
        end else begin
            // Send only valid data bytes (skip byte 0 which is length)
            if (m_axis_8.tvalid && m_axis_8.tready) begin
                // Finished when sent m10_length bytes (byte_cnt goes from 0 to length-1)
                if (m10_byte_cnt >= {1'b0, m10_length - 4'd1}) begin
                    m10_busy <= 1'b0;
                    m10_byte_cnt <= '0;
                end else begin
                    m10_byte_cnt <= m10_byte_cnt + 1'b1;
                end
            end
        end
    end else begin
        m10_busy   <= 1'b0;
        m10_byte_cnt <= '0;
        m10_length <= '0;
    end
end


//--------------------------------------------------------------------------------//
// Output Combinational Logic (MUX)
//--------------------------------------------------------------------------------//

// 1. m_axis_8 (Source 8-bit to select)

always_comb begin
    // defult
    m_axis_8.tvalid = 1'b0;
    m_axis_8.tdata  = '0;
    m_axis_8.tlast  = 1'b0; 
    m_axis_8.tkeep = '1; 

    if (wm == 2'b10) begin
        m_axis_8.tvalid = m10_busy; 
        // Skip byte 0 (length), send data starting from byte 1
        m_axis_8.tdata  = m10_data_buf[(m10_byte_cnt + 1) * 8 +: 8];
        // tlast when this is the last valid byte (byte_cnt == length - 1)
        m_axis_8.tlast  = (m10_busy && m10_length != 0 && (m10_byte_cnt >= {1'b0, m10_length - 4'd1})); 
    end 
    else if (wm == 2'b11) begin
        m_axis_8.tvalid = s_axis_r_8.tvalid;
        m_axis_8.tdata  = s_axis_r_8.tdata;
        m_axis_8.tlast  = s_axis_r_8.tlast;
        m_axis_8.tkeep  = s_axis_r_8.tkeep;
    end
    else if (wm == 2'b00) begin
        if (!ee) begin
            m_axis_8.tvalid = s_axis_r_8.tvalid;
            m_axis_8.tdata  = s_axis_r_8.tdata;
            m_axis_8.tlast  = s_axis_r_8.tlast;
            m_axis_8.tkeep  = s_axis_r_8.tkeep;
        end
    end
end


// 2. m_axis_128 (Source 128-bit to aes cipher)

always_comb begin
    m_axis_128.tvalid = 1'b0;
    m_axis_128.tdata  = '0;
    m_axis_128.tlast  = 1'b0;
    m_axis_128.tkeep  = '1;

    if (wm == 2'b01) begin
        m_axis_128.tvalid = m01_sending;
        m_axis_128.tdata  = m01_data_buf; 
        m_axis_128.tlast  = 1'b1; 
    end
    else if (wm == 2'b00 && ee) begin
        m_axis_128.tvalid = s_axis_r_128.tvalid;
        m_axis_128.tdata  = s_axis_r_128.tdata;
        m_axis_128.tlast  = s_axis_r_128.tlast;
        m_axis_128.tkeep  = s_axis_r_128.tkeep;
    end
end


// 3. m_axis_r_8 (Source 8-bit to RDR)

always_comb begin
    m_axis_r_8.tvalid = 1'b0;
    m_axis_r_8.tdata  = '0;
    m_axis_r_8.tlast  = 1'b0;
    m_axis_r_8.tkeep  = '1;

    if (wm == 2'b11) begin
        m_axis_r_8.tvalid = s_axis_8.tvalid;
        m_axis_r_8.tdata  = s_axis_8.tdata;
        m_axis_r_8.tlast  = s_axis_8.tlast;
        m_axis_r_8.tkeep  = s_axis_8.tkeep;
    end
    else if (wm == 2'b00) begin
        if (!de) begin
            m_axis_r_8.tvalid = s_axis_8.tvalid;
            m_axis_r_8.tdata  = s_axis_8.tdata;
            m_axis_r_8.tlast  = s_axis_8.tlast;
            m_axis_r_8.tkeep  = s_axis_8.tkeep;
        end
    end
end


// 4. m_axis_r_128 (Source 128-bit to DPR)

always_comb begin
    m_axis_r_128.tvalid = 1'b0;
    m_axis_r_128.tdata  = '0;
    m_axis_r_128.tlast  = 1'b0;
    m_axis_r_128.tkeep  = '1;

    if (wm == 2'b00 && de) begin
        m_axis_r_128.tvalid = s_axis_128.tvalid;
        m_axis_r_128.tdata  = s_axis_128.tdata;
        m_axis_r_128.tlast  = s_axis_128.tlast;
        m_axis_r_128.tkeep  = s_axis_128.tkeep;
    end
end

//--------------------------------------------------------------------------------//
// Input Ready Logic (Backpressure)
//--------------------------------------------------------------------------------//

// 1. s_axis_r_8 (Sink 8-bit from TDR)
always_comb begin
    if (wm == 2'b00 && !ee) s_axis_r_8.tready = m_axis_8.tready;
    else if (wm == 2'b11)    s_axis_r_8.tready = m_axis_8.tready;
    else                     s_axis_r_8.tready = 1'b0; // Blocked in other modes
end

// 2. s_axis_r_128 (Sink 128-bit from EPR)
always_comb begin
    if (wm == 2'b00 && ee) s_axis_r_128.tready = m_axis_128.tready;
    else                    s_axis_r_128.tready = 1'b0;
end

// 3. s_axis_8 (Sink 8-bit from select)
always_comb begin
    if (wm == 2'b01) begin
        s_axis_8.tready = !m01_sending; 
    end
    else if (wm == 2'b00 && !de) begin
        s_axis_8.tready = m_axis_r_8.tready;
    end
    else if (wm == 2'b11) begin
        s_axis_8.tready = m_axis_r_8.tready;
    end
    else begin
        s_axis_8.tready = 1'b0;
    end
end

// 4. s_axis_128 (Sink 128-bit from InvCipher)
always_comb begin
    if (wm == 2'b10) begin
        s_axis_128.tready = !m10_busy;
    end
    else if (wm == 2'b00 && de) begin
        s_axis_128.tready = m_axis_r_128.tready;
    end
    else begin
        s_axis_128.tready = 1'b0;
    end
end

endmodule