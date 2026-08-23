class fifo_write_driver extends uvm_driver #(fifo_item);

    `uvm_component_utils(fifo_write_driver)

    virtual fifo_if vif;

    function new(string name = "fifo_write_driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual fifo_if)::get(this, "", "vif", vif))
            `uvm_fatal("NOVIF", "virtual interface not set for fifo_write_driver")
    endfunction

    task run_phase(uvm_phase phase);
        reset_dut();
        forever begin
            seq_item_port.get_next_item(req);
            drive_item(req);
            seq_item_port.item_done();
        end
    endtask

    task reset_dut();
        vif.rst        <= 1;
        vif.wcb.w_en   <= 0;
        vif.wcb.w_data <= 0;
        repeat (5) @(posedge vif.w_clk);
        vif.rst <= 0;
        @(posedge vif.w_clk);
    endtask

    task drive_item(fifo_item item);
        repeat (item.delay_cycles) @(vif.wcb);
        vif.wcb.w_data <= item.data;
        vif.wcb.w_en   <= 1;
        @(vif.wcb);
        vif.wcb.w_en   <= 0;
    endtask

endclass
