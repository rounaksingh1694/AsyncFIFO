class fifo_read_monitor extends uvm_monitor;

    `uvm_component_utils(fifo_read_monitor)

    virtual fifo_if vif;
    uvm_analysis_port #(fifo_item) ap;

    function new(string name = "fifo_read_monitor", uvm_component parent = null);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual fifo_if)::get(this, "", "vif", vif))
            `uvm_fatal("NOVIF", "virtual interface not set for fifo_read_monitor")
    endfunction

    task run_phase(uvm_phase phase);
        bit pending;
        fifo_item item;
        forever begin
            @(vif.rmcb);
            if (pending) begin
                item = fifo_item::type_id::create("item");
                item.data = vif.rmcb.r_data;
                ap.write(item);
            end
            pending = (!vif.rst && vif.rmcb.r_en && !vif.rmcb.empty);
        end
    endtask

endclass
