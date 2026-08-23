class fifo_env extends uvm_env;

    `uvm_component_utils(fifo_env)

    fifo_write_agent write_agent;
    fifo_read_agent  read_agent;
    fifo_scoreboard  scoreboard;

    function new(string name = "fifo_env", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        write_agent = fifo_write_agent::type_id::create("write_agent", this);
        read_agent  = fifo_read_agent::type_id::create("read_agent", this);
        scoreboard  = fifo_scoreboard::type_id::create("scoreboard", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        write_agent.monitor.ap.connect(scoreboard.write_imp);
        read_agent.monitor.ap.connect(scoreboard.read_imp);
    endfunction

endclass
