class fifo_write_monitor extends uvm_monitor;

    `uvm_component_utils(fifo_write_monitor)

    virtual fifo_if vif;
    uvm_analysis_port #(fifo_item) ap;

    function new(string name = "fifo_write_monitor", uvm_component parent = null);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual fifo_if)::get(this, "", "vif", vif))
            `uvm_fatal("NOVIF", "virtual interface not set for fifo_write_monitor")
    endfunction

    task run_phase(uvm_phase phase);
        fifo_item item;
        forever begin
            @(vif.wmcb);
            // a write only actually lands if w_en was high AND the FIFO
            // was not full on this same edge - matches top_module's own
            // internal gating (w_en && !full)
            if (!vif.rst && vif.wmcb.w_en && !vif.wmcb.full) begin
                item = fifo_item::type_id::create("item");
                item.data = vif.wmcb.w_data;
                ap.write(item);
            end
        end
    endtask

endclass
