
`timescale 1ns/1ps

`define TEST_SIZE 1000

module testbench();

    parameter  buf_size_p       = 2048; // byte
    parameter  data_width_p     = 32;   // bit
    localparam reg_addr_width_p = 16;   // address width(bit)

    localparam packet_size_width_lp = $clog2(buf_size_p) + 1;
    localparam addr_width_lp = $clog2(buf_size_p / (data_width_p / 8));
    parameter  packet_count_p = 5;

    logic                              clk_i;
    logic                              reset_i;
    logic                              clk250_i;
    logic                              reset_clk250_i;

    logic [1:0][reg_addr_width_p-1:0]  addr_i;
    logic [1:0]                        write_en_i;
    logic [1:0]                        read_en_i;
    logic [1:0][1:0]                   op_size_i;
    logic [1:0][data_width_p-1:0]      write_data_i;
    logic [1:0][data_width_p-1:0]      read_data_o;

    logic [1:0]                        rx_interrupt_pending_o;
    logic [1:0]                        tx_interrupt_pending_o;

    logic [1:0]                        rgmii_rx_clk_i;
    logic [1:0][3:0]                   rgmii_rxd_i;
    logic [1:0]                        rgmii_rx_ctl_i;
    logic [1:0]                        rgmii_tx_clk_o;
    logic [1:0][3:0]                   rgmii_txd_o;
    logic [1:0]                        rgmii_tx_ctl_o;

    import "DPI" function int get_time();
    integer tx_file, rx_file;
    integer tx_send_cnt, rx_recv_cnt;

    always #25 clk_i    = ~clk_i; // 20 MHZ
    always #2  clk250_i = ~clk250_i; // 250 MHZ


    task clk250_tick();
        @(posedge clk250_i);
        @(negedge clk250_i);
    endtask
    task clk_tick();
        @(posedge clk_i);
        @(negedge clk_i);
    endtask

    // clk250_i, reset_clk250_i init
    initial begin
        clk250_i = 1'b0;
        reset_clk250_i = 1'b1;

        clk250_tick();
        clk250_tick();
        reset_clk250_i = 1'b0;
    end

    // clk_i, reset_i init
    initial begin
        clk_i = 1'b0;
        reset_i = 1'b1;
        clk_tick();
        reset_i = 1'b0;
    end

    // Set timeout
    initial begin
/*        #1000000
        $fclose(tx_file);
        $fclose(rx_file);
        $display("Timeout");
        $finish;*/
    end

    task automatic write_addr (
            input logic [reg_addr_width_p-1:0] address
           ,input logic [data_width_p-1:0] data
           ,input logic [1:0]  op_size
           ,input logic id_i);
      case(op_size)
        2'b01: // 2
          assert(address[0] == 1'b0) else begin $error("Misalgined write"); $finish; end
        2'b10: // 4
          assert(address[1:0] == 2'b0) else begin $error("Misalgined write"); $finish; end
        2'b11: // 8
          assert(address[2:0] == 3'b0) else begin $error("Misalgined write"); $finish; end
      endcase
      op_size_i[id_i] = op_size;
      addr_i[id_i] = address;
      write_data_i[id_i] = data;
      write_en_i[id_i] = 1'b1;
      clk_tick();
      write_en_i[id_i] = 1'b0;
    endtask

    task automatic read_addr (
            input  logic [reg_addr_width_p-1:0] address_i
           ,output logic [data_width_p-1:0] data_o
           ,input  logic [1:0]  op_size
           ,input  logic id_i);
        op_size_i[id_i] = op_size;
        addr_i[id_i] = address_i;
        read_en_i[id_i] = 1'b1;
        clk_tick();
        data_o = read_data_o[id_i];
        read_en_i[id_i] = 1'b0;
    endtask


    task automatic send_random_packet(input [reg_addr_width_p-1:0] size);
        logic [reg_addr_width_p-1:0] count, cur;
        logic [data_width_p-1:0] data_lo, value;
        logic [buf_size_p*8-1:0] packet;
        integer i, wait_cnt;
        assert((size % (data_width_p / 8)) == 0);
        count = size / (data_width_p / 8);
        $display("Sending packet with size 0x%x:", size);
        for(i = 0;i < count;i = i + 1) begin
            value = {$urandom, $urandom};
            packet[(i * data_width_p)+:data_width_p] = value;
        end
        // wait for TX 0 to be ready
        wait_cnt = 0;
        forever begin
            read_addr('h101C, data_lo, 2'b10, 0);
            if(data_lo == 'd1)
                break;
            if(wait_cnt > 100000) begin
                $display("TX Timeout");
                $fclose(tx_file);
                $fclose(rx_file);
                $finish;
            end
            wait_cnt = wait_cnt + 1;
        end
        // write content
        for(i = 0;i < count;i = i + 1) begin
            value = packet[i * data_width_p+:data_width_p];
            write_addr('h0800 + (i * data_width_p / 8), (data_width_p)'(value),
                    $clog2(data_width_p / 8) , 0);
            $fwrite(tx_file, "%x\n", value);
        end

        // write size
        write_addr('h1028, size, 2'b10, 0);
        // send
        write_addr('h1018, 'd0, 2'b10, 0);
        $fwrite(tx_file, "End\n");
    endtask

    task automatic receive_packet();
        logic [data_width_p-1:0] data_lo, size;
        logic [reg_addr_width_p-1:0] upper, lower, cur;

        int ret;
        integer i, wait_cnt = 0;
        // wait, read packets
        forever begin
            read_addr('h1010, data_lo, 2'b10, 1);
            if(data_lo == 'b1)
                break;
            if(wait_cnt > 100000) begin
                $display("RX Timeout");
                $fclose(tx_file);
                $fclose(rx_file);
                $finish;
            end
            wait_cnt = wait_cnt + 1;
        end
        read_addr('h1004, data_lo, 2'b10, 1);
        size = data_lo;
        $display("Received packet size:\n0x%x\n", size);

        upper = size / (data_width_p / 8);
        lower = size % (data_width_p / 8);
        for(i = 0;i < upper;i = i + 1) begin
            read_addr('h0000 + i * (data_width_p / 8), data_lo, $clog2(data_width_p / 8), 1);
            $fwrite(rx_file, "%x\n", data_lo);
        end
        cur = upper * (data_width_p / 8);
        if(lower) begin
          for(i = $clog2(data_width_p / 8) - 1;i >= 0;i = i - 1) begin
            if(lower >= (1 << i)) begin
              read_addr('h0000 + cur, data_lo, i, 1);
              case(i)
                2'b10: begin
                  $fwrite(rx_file, "%x\n", data_lo[0+:32]);
                end
                2'b01: begin
                  $fwrite(rx_file, "%x\n", data_lo[0+:16]);
                end
                2'b00: begin
                  $fwrite(rx_file, "%x\n", data_lo[0+:8]);
                end
              endcase
              lower = lower - (1 << i);
              cur = cur + (1 << i);
            end
          end
        end
        assert(lower == 0);
        // clear RX pending
        write_addr('h1010, 'd1, 2'b10, 1);
        $fwrite(rx_file, "End\n");

    endtask
    task automatic sender(int cnt);
        int size, delay;
        for(tx_send_cnt = 0;tx_send_cnt < cnt;tx_send_cnt = tx_send_cnt + 1) begin
            // make sure the RX packet buffer does not overflow
            wait(tx_send_cnt <= rx_recv_cnt + 4);
            delay = $urandom() % 128;
            for(int i = 0;i < delay;i = i + 1) begin
                clk_tick();
            end
            size = $urandom() % 1400 + 64;
            size = size / (data_width_p / 8) * (data_width_p / 8);
            $display("Sending %d packet", tx_send_cnt);
            send_random_packet(size);
        end
    endtask
    task automatic receiver(int cnt);
        int delay;
        for(rx_recv_cnt = 0;rx_recv_cnt < cnt;rx_recv_cnt = rx_recv_cnt + 1) begin
            delay = $urandom() % 128;
            for(int i = 0;i < delay;i = i + 1) begin
                clk_tick();
            end
            $display("Receiving %d packet", rx_recv_cnt);
            receive_packet();
        end
    endtask
    task automatic testbench1();
        integer seed;
        seed = 0;
        if(seed == 0) begin
          seed = get_time();
          $srandom(seed);
          $display("Seed: %d", seed);
        end
        // enable TX 0 INT
        write_addr('h1034, 'd1, 2'b10, 0);
        // enable RX 1 INT
        write_addr('h1014, 'd1, 2'b10, 1);
        fork
            sender(`TEST_SIZE);
            receiver(`TEST_SIZE);
        join

        $display("End of testbench1");
    endtask



    initial begin
        $dumpfile("dump.vcd");
        $dumpvars;
        tx_file = $fopen("tx.txt", "w");
        rx_file = $fopen("rx.txt", "w");

        read_en_i  = 2'b00;
        write_en_i = 2'b00;

        // wait for the resets to complete
        wait(reset_i == 1'b0);
        wait(reset_clk250_i == 1'b0);
        clk_tick();
        clk_tick();
        clk_tick();

        testbench1();
        $fclose(tx_file);
        $fclose(rx_file);
        $finish;
    end


generate

    for(genvar k = 0;k < 2;k = k + 1) begin: ethernet_controller_core
        ethernet_controller #(
            .buf_size_p(buf_size_p)
           ,.data_width_p(data_width_p)
        ) eth (
            .clk_i(clk_i)
           ,.reset_i(reset_i)
           ,.clk250_i(clk250_i)
           ,.reset_clk250_i(reset_clk250_i)
           ,.reset_clk125_o(/* UNUSED */)

           ,.addr_i(addr_i[k])
           ,.write_en_i(write_en_i[k])
           ,.read_en_i(read_en_i[k])
           ,.op_size_i(op_size_i[k])
           ,.write_data_i(write_data_i[k])
           ,.read_data_o(read_data_o[k])

           ,.rx_interrupt_pending_o(rx_interrupt_pending_o[k])
           ,.tx_interrupt_pending_o(tx_interrupt_pending_o[k])

           ,.rgmii_rx_clk_i(rgmii_rx_clk_i[k])
           ,.rgmii_rxd_i(rgmii_rxd_i[k])
           ,.rgmii_rx_ctl_i(rgmii_rx_ctl_i[k])
           ,.rgmii_tx_clk_o(rgmii_tx_clk_o[k])
           ,.rgmii_txd_o(rgmii_txd_o[k])
           ,.rgmii_tx_ctl_o(rgmii_tx_ctl_o[k])
        );
    end
endgenerate

    assign rgmii_rx_clk_i[1] = rgmii_tx_clk_o[0];
    assign rgmii_rxd_i[1]    = rgmii_txd_o[0];
    assign rgmii_rx_ctl_i[1] = rgmii_tx_ctl_o[0];

    assign rgmii_rx_clk_i[0] = rgmii_tx_clk_o[1];
    assign rgmii_rxd_i[0]    = rgmii_txd_o[1];
    assign rgmii_rx_ctl_i[0] = rgmii_tx_ctl_o[1];


endmodule
