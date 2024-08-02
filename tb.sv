// ===================================================
// This TB is generated by ChatGPT to test APB slave
//====================================================
`timescale 1ns / 100ps

module tb_apb_slave;

// Parameters
parameter DW = 32;
parameter AW = 5;

// Derived Parameters
localparam SW = (DW/8);

// Signals
logic pclk;
logic presetn;
logic [AW-1:0] i_paddr;
logic i_pwrite;
logic i_psel;
logic i_penable;
logic [DW-1:0] i_pwdata;
logic [SW-1:0] i_pstrb;
logic [DW-1:0] o_prdata;
logic o_pslverr;
logic o_pready;
logic o_hw_ctl;
logic i_hw_sts;

// Device Under Test
apb_slave #(
    .DW(DW),
    .AW(AW)
) dut (
    .pclk(pclk),
    .presetn(presetn),
    .i_paddr(i_paddr),
    .i_pwrite(i_pwrite),
    .i_psel(i_psel),
    .i_penable(i_penable),
    .i_pwdata(i_pwdata),
    .i_pstrb(i_pstrb),
    .o_prdata(o_prdata),
    .o_pslverr(o_pslverr),
    .o_pready(o_pready),
    .o_hw_ctl(o_hw_ctl),
    .i_hw_sts(i_hw_sts)
);

// Clock generation
initial begin
    pclk = 0;
    forever #5 pclk = ~pclk; // 100MHz clock
end

// Reset generation
initial begin
    presetn = 0;
    #20;
    presetn = 1;
end

// VCD dump
initial begin
    $dumpfile("tb_apb_slave.vcd");
    $dumpvars(0, tb_apb_slave);
end

// Test sequence
initial begin
    // Initialize signals
    i_paddr = 0;
    i_pwrite = 0;
    i_psel = 0;
    i_penable = 0;
    i_pwdata = 0;
    i_pstrb = 4'b1111; // Full 32-bit write strobe
    i_hw_sts = 1'b0;

    // Wait for reset deassertion
    wait (presetn == 1'b1);

    // Write to register 0
    apb_write(5'h00, 32'h12345678);

    // Read from register 0
    apb_read(5'h00);

    // Write to register 1 (write-only)
    apb_write(5'h04, 32'h87654321);

    // Attempt to read from register 1 (should generate pslverr)
    apb_read(5'h04);

    // Write to register 2
    apb_write(5'h08, 32'hDEADFEED);

    // Read from register 2
    apb_read(5'h08);

    // Attempt to write to register 3 (read-only, should generate pslverr)
    apb_write(5'h0C, 32'hCAFEBABE);

    // Read from register 3
    apb_read(5'h0C);

    // Read from register 4 (status register driven by i_hw_sts)
    i_hw_sts = 1'b1;
    apb_read(5'h10);

    // Consecutive transactions to trigger pslverr
    apb_write(5'h0C, 32'hBADBAD01); // Write to read-only register
    apb_write(5'h0C, 32'hBADBAD02); // Write to read-only register
    apb_write(5'h0C, 32'hBADBAD03); // Write to read-only register

    // Alternate transactions (err, no err, err, ...)
    apb_write(5'h0C, 32'hBADBAD04); // Write to read-only register
    apb_write(5'h08, 32'hCAFED00D); // Valid write
    apb_read(5'h04);                // Read from write-only register
    apb_write(5'h10, 32'hDEADBEAF); // Write to read-only status register
    apb_read(5'h00);                // Valid read

    // Test complete
    $finish;
end

task apb_write(input [AW-1:0] addr, input [DW-1:0] data);
    begin
        @(posedge pclk);
        i_paddr <= addr;
        i_pwdata <= data;
        i_pwrite <= 1;
        i_psel <= 1;
        i_penable <= 0;
        @(posedge pclk);
        i_penable <= 1;
        wait (o_pready);
        @(posedge pclk);
        if (o_pslverr) begin
            $display("Write Error at address: %h", addr);
        end
        i_paddr <= 0;
        i_pwdata <= 0;
        i_pwrite <= 0;
        i_psel <= 0;
        i_penable <= 0;
    end
endtask

task apb_read(input [AW-1:0] addr);
    begin
        @(posedge pclk);
        i_paddr <= addr;
        i_pwrite <= 0;
        i_psel <= 1;
        i_penable <= 0;
        @(posedge pclk);
        i_penable <= 1;
        wait (o_pready);
        @(posedge pclk);
        if (o_pslverr) begin
            $display("Read Error at address: %h", addr);
        end else begin
            $display("Read Data from address %h: %h", addr, o_prdata);
        end
        i_paddr <= 0;
        i_psel <= 0;
        i_penable <= 0;
    end
endtask

endmodule
