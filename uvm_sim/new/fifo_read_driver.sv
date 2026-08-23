class fifo_read_driver extends uvm_driver #(fifo_item);

    `uvm_component_utils(fifo_read_driver)

    virtual fifo_if vif;

    function new(string name = "fifo_read_driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual fifo_if)::get(this, "", "vif", vif))
            `uvm_fatal("NOVIF", "virtual interface not set for fifo_read_driver")
    endfunction

    task run_phase(uvm_phase phase);
        wait_for_reset();
        forever begin
            seq_item_port.get_next_item(req);
            drive_item(req);
            seq_item_port.item_done();
        end
    endtask

    task wait_for_reset();
        @(negedge vif.rst);
        repeat (2) @(posedge vif.r_clk);
    endtask

    task drive_item(fifo_item item);
        repeat (item.delay_cycles) @(vif.rcb);
        vif.rcb.r_en <= 1;
        @(vif.rcb);
        vif.rcb.r_en <= 0;
    endtask

endclass
