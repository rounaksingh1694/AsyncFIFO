class fifo_read_agent extends uvm_agent;

    `uvm_component_utils(fifo_read_agent)

    fifo_sequencer   sequencer;
    fifo_read_driver  driver;
    fifo_read_monitor monitor;

    function new(string name = "fifo_read_agent", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        monitor = fifo_read_monitor::type_id::create("monitor", this);
        if (is_active == UVM_ACTIVE) begin
            sequencer = fifo_sequencer::type_id::create("sequencer", this);
            driver    = fifo_read_driver::type_id::create("driver", this);
        end
    endfunction

    function void connect_phase(uvm_phase phase);
        if (is_active == UVM_ACTIVE)
            driver.seq_item_port.connect(sequencer.seq_item_export);
    endfunction

endclass
