`timescale 1ns / 1ps

//==========================================================================
// SECTION 1: INTERFACE
// Carries all DUT signals plus 4 clocking blocks:
//   wcb/rcb  -> used by the DRIVERS to drive stimulus
//   wmcb/rmcb -> used by the MONITORS to sample (separate blocks because
//                xsim doesn't allow a clocking block's output-direction
//                signal to also be read by a different process/monitor)
//==========================================================================

interface fifo_if #(parameter DATA_WIDTH = 8, parameter PTR_WIDTH = 4) (
    input bit w_clk,
    input bit r_clk
    );

    logic rst;

    logic w_en;
    logic [DATA_WIDTH-1:0] w_data;
    logic full;

    logic r_en;
    logic [DATA_WIDTH-1:0] r_data;
    logic empty;

    // Debug-only signals, connected to the DUT's internal pointers via a
    // plain assign inside tb_top (module-to-submodule hierarchical access,
    // which is legal - unlike referencing tb_top.dut.* directly from a
    // class inside fifo_pkg, which xsim correctly rejects since a package
    // cannot hierarchically reference into a specific module instance).
    // Used by directed tests (e.g. fifo_reset_midtraffic_test) that need
    // to confirm internal DUT state rather than only what's visible on
    // the external interface.
    logic [PTR_WIDTH-1:0] dbg_wptr_bin;
    logic [PTR_WIDTH-1:0] dbg_rptr_bin;

    clocking wcb @(posedge w_clk);
        output w_en;
        output w_data;
        input  full;
    endclocking

    clocking rcb @(posedge r_clk);
        output r_en;
        input  r_data;
        input  empty;
    endclocking

    clocking wmcb @(posedge w_clk);
        input w_en;
        input w_data;
        input full;
    endclocking

    clocking rmcb @(posedge r_clk);
        input r_en;
        input r_data;
        input empty;
    endclocking

endinterface


//==========================================================================
// SECTION 2: UVM PACKAGE (all classes live here)
//==========================================================================

package fifo_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    //----------------------------------------------------------------------
    // 2.1  TRANSACTION ITEM
    // One randomized write or read transaction: a data byte plus how many
    // idle cycles the driver waits before issuing it.
    //----------------------------------------------------------------------
    class fifo_item extends uvm_sequence_item;

        parameter int DATA_WIDTH = 8;

        rand bit [DATA_WIDTH-1:0] data;
        rand int unsigned delay_cycles;

        constraint c_delay {
            delay_cycles inside {[0:3]};
        }

        `uvm_object_utils_begin(fifo_item)
            `uvm_field_int(data, UVM_ALL_ON)
            `uvm_field_int(delay_cycles, UVM_ALL_ON)
        `uvm_object_utils_end

        function new(string name = "fifo_item");
            super.new(name);
        endfunction

        // compact one-line summary, used instead of the verbose default
        // sprint() table printer for readability in the Tcl console
        function string summary();
            return $sformatf("data=0x%0h delay_cycles=%0d", data, delay_cycles);
        endfunction

    endclass


    //----------------------------------------------------------------------
    // 2.2  SEQUENCER
    // Same sequencer type reused for both the write side and read side.
    //----------------------------------------------------------------------
    typedef uvm_sequencer #(fifo_item) fifo_sequencer;


    //----------------------------------------------------------------------
    // 2.3  DRIVERS
    //----------------------------------------------------------------------
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
            // DUT's internal w_rst_sync (2-flop synchronizer output) lags
            // this raw vif.rst deassertion by up to 2 w_clk cycles. Waiting
            // only 1 cycle here let the driver start issuing writes while
            // the DUT was still internally in reset, which the write
            // monitor (gated on vif.rst, not w_rst_sync) wrongly counted
            // as a landed transaction. 4 cycles gives safe margin.
            repeat (4) @(posedge vif.w_clk);
        endtask

        task drive_item(fifo_item item);
            repeat (item.delay_cycles) @(vif.wcb);
            vif.wcb.w_data <= item.data;
            vif.wcb.w_en   <= 1;
            @(vif.wcb);
            vif.wcb.w_en   <= 0;
        endtask

    endclass


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
            // same reasoning as the write driver: r_rst_sync (2-flop
            // synchronizer output) lags vif.rst deassertion by up to 2
            // r_clk cycles. Bumped from 2 to 4 cycles for safety margin.
            repeat (4) @(posedge vif.r_clk);
        endtask

        task drive_item(fifo_item item);
            repeat (item.delay_cycles) @(vif.rcb);
            vif.rcb.r_en <= 1;
            @(vif.rcb);
            vif.rcb.r_en <= 0;
        endtask

    endclass


    //----------------------------------------------------------------------
    // 2.4  SEQUENCES
    // Random balanced traffic (fifo_write_sequence / fifo_read_sequence),
    // plus the directed edge-case sequences (full / empty).
    //----------------------------------------------------------------------
    class fifo_write_sequence extends uvm_sequence #(fifo_item);

        `uvm_object_utils(fifo_write_sequence)

        rand int unsigned num_items;

        constraint c_num_items {
            num_items inside {[10:20]};
        }

        function new(string name = "fifo_write_sequence");
            super.new(name);
        endfunction

        task body();
            fifo_item item;
            repeat (num_items) begin
                item = fifo_item::type_id::create("item");
                start_item(item);
                if (!item.randomize())
                    `uvm_error("RANDFAIL", "fifo_item randomization failed")
                finish_item(item);
            end
        endtask

    endclass


    class fifo_read_sequence extends uvm_sequence #(fifo_item);

        `uvm_object_utils(fifo_read_sequence)

        rand int unsigned num_items;

        constraint c_num_items {
            num_items inside {[10:20]};
        }

        function new(string name = "fifo_read_sequence");
            super.new(name);
        endfunction

        task body();
            fifo_item item;
            repeat (num_items) begin
                item = fifo_item::type_id::create("item");
                start_item(item);
                if (!item.randomize())
                    `uvm_error("RANDFAIL", "fifo_item randomization failed")
                finish_item(item);
            end
        endtask

    endclass


    // DIRECTED: forces the write side to overflow past FIFO depth (8).
    class fifo_write_full_sequence extends uvm_sequence #(fifo_item);

        `uvm_object_utils(fifo_write_full_sequence)

        int unsigned num_items = 12; // > depth (8), so it keeps writing after full

        function new(string name = "fifo_write_full_sequence");
            super.new(name);
        endfunction

        task body();
            fifo_item item;
            repeat (num_items) begin
                item = fifo_item::type_id::create("item");
                start_item(item);
                if (!item.randomize() with { delay_cycles == 0; })
                    `uvm_error("RANDFAIL", "fifo_item randomization failed")
                finish_item(item);
            end
        endtask

    endclass


    // DIRECTED: attempts reads while the FIFO is empty (no writes ever occur).
    class fifo_read_empty_sequence extends uvm_sequence #(fifo_item);

        `uvm_object_utils(fifo_read_empty_sequence)

        int unsigned num_items = 5;

        function new(string name = "fifo_read_empty_sequence");
            super.new(name);
        endfunction

        task body();
            fifo_item item;
            repeat (num_items) begin
                item = fifo_item::type_id::create("item");
                start_item(item);
                if (!item.randomize() with { delay_cycles == 0; })
                    `uvm_error("RANDFAIL", "fifo_item randomization failed")
                finish_item(item);
            end
        endtask

    endclass


    //----------------------------------------------------------------------
    // 2.5  MONITORS
    // Both mirror the DUT's own gating logic (w_en && !full / r_en && !empty)
    // so only transactions that actually landed get reported to the scoreboard.
    //----------------------------------------------------------------------
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
                if (!vif.rst && vif.wmcb.w_en && !vif.wmcb.full) begin
                    item = fifo_item::type_id::create("item");
                    item.data = vif.wmcb.w_data;
                    ap.write(item);
                end
            end
        endtask

    endclass


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


    //----------------------------------------------------------------------
    // 2.6  AGENTS
    //----------------------------------------------------------------------
    class fifo_write_agent extends uvm_agent;

        `uvm_component_utils(fifo_write_agent)

        fifo_sequencer     sequencer;
        fifo_write_driver  driver;
        fifo_write_monitor monitor;

        function new(string name = "fifo_write_agent", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            monitor = fifo_write_monitor::type_id::create("monitor", this);
            if (is_active == UVM_ACTIVE) begin
                sequencer = fifo_sequencer::type_id::create("sequencer", this);
                driver    = fifo_write_driver::type_id::create("driver", this);
            end
        endfunction

        function void connect_phase(uvm_phase phase);
            if (is_active == UVM_ACTIVE)
                driver.seq_item_port.connect(sequencer.seq_item_export);
        endfunction

    endclass


    class fifo_read_agent extends uvm_agent;

        `uvm_component_utils(fifo_read_agent)

        fifo_sequencer    sequencer;
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



    `uvm_analysis_imp_decl(_write)
    `uvm_analysis_imp_decl(_read)

    class fifo_scoreboard extends uvm_scoreboard;

        `uvm_component_utils(fifo_scoreboard)

        uvm_analysis_imp_write #(fifo_item, fifo_scoreboard) write_imp;
        uvm_analysis_imp_read  #(fifo_item, fifo_scoreboard) read_imp;

        fifo_item expected_q[$];

        int unsigned match_count;
        int unsigned mismatch_count;

        function new(string name = "fifo_scoreboard", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            write_imp = new("write_imp", this);
            read_imp  = new("read_imp", this);
        endfunction

        function void write_write(fifo_item item);
            expected_q.push_back(item);
        endfunction

        // Discards any pending expected entries without counting them as
        // mismatches. Used after a reset event: writes that landed before
        // the reset but were never read are genuinely lost by the DUT
        // (same as real hardware), so continuing to hold them as
        // "expected" would cause false-positive mismatches against
        // whatever new data appears after the reset.
        function void clear_expected();
            `uvm_info("SCOREBOARD",
                $sformatf("Clearing %0d pending expected item(s) - discarded by reset", expected_q.size()),
                UVM_LOW)
            expected_q.delete();
        endfunction

        function void write_read(fifo_item item);
            fifo_item exp_item;

            if (expected_q.size() == 0) begin
                `uvm_error("SCOREBOARD",
                    $sformatf("READ %s -> Mismatch! Expected: <empty queue>",
                        item.summary()))
                mismatch_count++;
                return;
            end

            exp_item = expected_q.pop_front();

            if (exp_item.data !== item.data) begin
                `uvm_error("SCOREBOARD",
                    $sformatf("READ %s -> Mismatch! Expected: 0x%0h, Got: 0x%0h",
                        item.summary(), exp_item.data, item.data))
                mismatch_count++;
            end else begin
                `uvm_info("SCOREBOARD",
                    $sformatf("READ %s -> Correct data: 0x%0h", item.summary(), item.data),
                    UVM_LOW)
                match_count++;
            end
        endfunction

        function void report_phase(uvm_phase phase);
            string verdict;

            if (mismatch_count > 0)
                verdict = "FAILED - DATA MISMATCH DETECTED";
            else if (expected_q.size() > 0)
                verdict = $sformatf("FINISHED - %0d WRITTEN ITEM(S) NEVER READ BACK",
                    expected_q.size());
            else
                verdict = "PASSED - ALL TRANSACTIONS MATCHED";

            `uvm_info("SBREPORT", $sformatf(
                "\n==================================================\n%s\n==================================================\n  Matches         : %0d\n  Mismatches      : %0d\n  Unread (pending): %0d\n--------------------------------------------------\n  RESULT: %s\n==================================================",
                "              SCOREBOARD SUMMARY",
                match_count, mismatch_count, expected_q.size(), verdict),
                UVM_LOW)
        endfunction

    endclass


    //----------------------------------------------------------------------
    // 2.8  ENVIRONMENT
    //----------------------------------------------------------------------
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


    //----------------------------------------------------------------------
    // 2.9  TESTS
    //   fifo_test            -> original random balanced traffic (10-20 items)
    //   fifo_full_test       -> directed: forces FIFO full, checks vif.full
    //   fifo_empty_test      -> directed: no writes, checks vif.empty stays set
    //   fifo_wraparound_test -> random traffic but 40 items (5x depth) so the
    //                           pointer wraps multiple times
    //----------------------------------------------------------------------
    class fifo_test extends uvm_test;

        `uvm_component_utils(fifo_test)

        fifo_env env;

        function new(string name = "fifo_test", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            // silence recurring UVM library boilerplate INFO messages that
            // add noise but no useful information to every run
            uvm_top.set_report_id_action("UVM/COMP/NAMECHECK", UVM_NO_ACTION);
            env = fifo_env::type_id::create("env", this);
        endfunction

        task run_phase(uvm_phase phase);
            fifo_write_sequence wseq;
            fifo_read_sequence  rseq;

            phase.raise_objection(this);

            wseq = fifo_write_sequence::type_id::create("wseq");
            rseq = fifo_read_sequence::type_id::create("rseq");

            if (!wseq.randomize())
                `uvm_error("RANDFAIL", "fifo_write_sequence randomization failed")

            // Match the read count to whatever the write count randomized
            // to, rather than letting rseq pick its own independent count.
            // Drivers fire-and-forget (don't wait on full/empty), so this
            // isn't strictly required for deadlock-safety here - but
            // keeping counts matched avoids the read sequence issuing a
            // batch of reads against a FIFO that was never given that many
            // items in the first place, which just wastes cycles on
            // reads that will find it empty. wseq.num_items is already
            // guaranteed inside [10:20] by its own constraint, so
            // assigning it directly here can't conflict with rseq's
            // matching [10:20] constraint.
            rseq.num_items = wseq.num_items;

            fork
                wseq.start(env.write_agent.sequencer);
                rseq.start(env.read_agent.sequencer);
            join

            repeat (5) @(posedge env.read_agent.driver.vif.r_clk);

            phase.drop_objection(this);
        endtask

    endclass


    class fifo_full_test extends uvm_test;

        `uvm_component_utils(fifo_full_test)

        fifo_env env;

        function new(string name = "fifo_full_test", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            uvm_top.set_report_id_action("UVM/COMP/NAMECHECK", UVM_NO_ACTION);
            env = fifo_env::type_id::create("env", this);
        endfunction

        task run_phase(uvm_phase phase);
            fifo_write_full_sequence wseq;

            phase.raise_objection(this);

            wseq = fifo_write_full_sequence::type_id::create("wseq");
            wseq.start(env.write_agent.sequencer);

            repeat (5) @(posedge env.write_agent.driver.vif.w_clk);

            if (!env.write_agent.driver.vif.full)
                `uvm_error("FULL_NOT_SET",
                    "Expected FIFO full after writing past depth, but full=0")
            else
                `uvm_info("FULL_CHECK",
                    "PASS: FIFO correctly asserted full after filling to depth",
                    UVM_LOW)

            phase.drop_objection(this);
        endtask

    endclass


    class fifo_empty_test extends uvm_test;

        `uvm_component_utils(fifo_empty_test)

        fifo_env env;

        function new(string name = "fifo_empty_test", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            uvm_top.set_report_id_action("UVM/COMP/NAMECHECK", UVM_NO_ACTION);
            env = fifo_env::type_id::create("env", this);
        endfunction

        task run_phase(uvm_phase phase);
            fifo_read_empty_sequence rseq;

            phase.raise_objection(this);

            rseq = fifo_read_empty_sequence::type_id::create("rseq");
            rseq.start(env.read_agent.sequencer);

            repeat (5) @(posedge env.read_agent.driver.vif.r_clk);

            if (!env.read_agent.driver.vif.empty)
                `uvm_error("EMPTY_NOT_SET",
                    "Expected FIFO empty since no writes occurred, but empty=0")
            else
                `uvm_info("EMPTY_CHECK",
                    "PASS: FIFO correctly stayed empty with no writes issued",
                    UVM_LOW)

            phase.drop_objection(this);
        endtask

    endclass


    class fifo_wraparound_test extends uvm_test;

        `uvm_component_utils(fifo_wraparound_test)

        fifo_env env;
        // Drivers fire every attempt regardless of full/empty (dropped
        // silently by the DUT if it's not ready) rather than retrying -
        // simpler and deadlock-safe, but means only a fraction of
        // attempts actually land when the write/read clocks are mismatched
        // (4:1 here). Earlier testing showed roughly 14/40 landed, so
        // num_items is bumped well past what's needed to guarantee at
        // least several genuine pointer wraps (depth is 8) land in the
        // scoreboard, not just get attempted.
        int unsigned num_items = 150;

        function new(string name = "fifo_wraparound_test", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            uvm_top.set_report_id_action("UVM/COMP/NAMECHECK", UVM_NO_ACTION);
            env = fifo_env::type_id::create("env", this);
        endfunction

        task run_phase(uvm_phase phase);
            fifo_write_sequence wseq;
            fifo_read_sequence  rseq;

            phase.raise_objection(this);

            wseq = fifo_write_sequence::type_id::create("wseq");
            rseq = fifo_read_sequence::type_id::create("rseq");

            // Directly assign num_items rather than randomize() with an
            // equality constraint. fifo_write_sequence/fifo_read_sequence
            // already carry their own c_num_items constraint restricting
            // the value to [10:20] - an inline "with { num_items == 40 }"
            // ADDS to that constraint rather than replacing it, so 40
            // conflicts with [10:20] and randomize() fails every time,
            // silently leaving num_items at 0 (no items ever driven).
            // A direct assignment sidesteps the conflict entirely, and
            // is fine here since we want an exact, non-random count.
            wseq.num_items = num_items;
            rseq.num_items = num_items;

            fork
                wseq.start(env.write_agent.sequencer);
                rseq.start(env.read_agent.sequencer);
            join

            repeat (5) @(posedge env.read_agent.driver.vif.r_clk);

            phase.drop_objection(this);
        endtask

    endclass


    //------------------------------------------------------------------
    // fifo_reset_midtraffic_test
    // Writes several items (blocking, fully sequential - no fork/disable),
    // then asserts reset, checks the DUT genuinely flushed, clears the
    // scoreboard's now-stale expected entries, and confirms the FIFO
    // resumes correct operation with fresh traffic afterward.
    //
    // NOTE on an earlier version of this test: it used fork...join_none
    // to run traffic in the background, then `disable` to kill that
    // process right before asserting reset. That caused a real
    // deadlock - disabling a sequence mid-handshake with its driver can
    // leave the driver's get_next_item() permanently stuck waiting for
    // an item that will never arrive, a known UVM gotcha. This version
    // avoids fork/disable entirely: the pre-reset writes are simply
    // blocking calls that complete before reset is asserted, sacrificing
    // strict "reset injected mid-instruction" timing for a guaranteed
    // deadlock-free structure. It still validates the thing that
    // actually matters: several items written and unread, then reset,
    // then confirming the DUT correctly discarded them and recovered.
    //
    // Reads the DUT's internal pointer registers via
    // vif.dbg_wptr_bin/dbg_rptr_bin - wired up in tb_top from the DUT's
    // internal signals, since a class inside a package cannot
    // hierarchically reference a module instance directly (xsim
    // correctly rejects that - packages are elaboration-context-free).
    //------------------------------------------------------------------
    class fifo_reset_midtraffic_test extends uvm_test;

        `uvm_component_utils(fifo_reset_midtraffic_test)

        fifo_env env;

        function new(string name = "fifo_reset_midtraffic_test", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            uvm_top.set_report_id_action("UVM/COMP/NAMECHECK", UVM_NO_ACTION);
            env = fifo_env::type_id::create("env", this);
        endfunction

        task run_phase(uvm_phase phase);
            fifo_write_full_sequence pre_reset_wseq;
            fifo_write_sequence      post_wseq;
            fifo_read_sequence       post_rseq;

            phase.raise_objection(this);

            // --- Phase 1: write several items, leave them unread ---
            // blocking call - completes fully before we move on, no
            // concurrency, no risk of leaving the driver mid-handshake
            pre_reset_wseq = fifo_write_full_sequence::type_id::create("pre_reset_wseq");
            pre_reset_wseq.num_items = 6;
            pre_reset_wseq.start(env.write_agent.sequencer);

            `uvm_info("RESET_MIDTRAFFIC",
                "Wrote 6 items, none read back - now asserting reset...", UVM_LOW)

            // force reset directly - bypasses the drivers' own one-time
            // startup reset task, models an external reset event hitting
            // the DUT with unread data still sitting in the FIFO
            env.write_agent.driver.vif.rst <= 1;
            repeat (5) @(posedge env.write_agent.driver.vif.w_clk);
            env.write_agent.driver.vif.rst <= 0;

            // same settle margin as the drivers' own startup reset
            repeat (4) @(posedge env.write_agent.driver.vif.w_clk);
            repeat (4) @(posedge env.read_agent.driver.vif.r_clk);

            // --- Phase 2: confirm the DUT genuinely flushed ---
            if (env.write_agent.driver.vif.dbg_wptr_bin !== 0)
                `uvm_error("RESET_MIDTRAFFIC",
                    $sformatf("wptr_bin did not return to 0 after reset - got %0d",
                        env.write_agent.driver.vif.dbg_wptr_bin))
            else if (env.write_agent.driver.vif.dbg_rptr_bin !== 0)
                `uvm_error("RESET_MIDTRAFFIC",
                    $sformatf("rptr_bin did not return to 0 after reset - got %0d",
                        env.write_agent.driver.vif.dbg_rptr_bin))
            else if (env.write_agent.driver.vif.full !== 0)
                `uvm_error("RESET_MIDTRAFFIC", "full is still asserted after reset - expected 0")
            else if (env.write_agent.driver.vif.empty !== 1)
                `uvm_error("RESET_MIDTRAFFIC", "empty is not asserted after reset - expected 1")
            else
                `uvm_info("RESET_MIDTRAFFIC",
                    "PASS: FIFO correctly flushed unread data after reset (wptr=0, rptr=0, full=0, empty=1)",
                    UVM_LOW)

            // the 6 items written before reset are genuinely gone - clear
            // them from the scoreboard so they don't get compared
            // against unrelated post-reset data
            env.scoreboard.clear_expected();

            // --- Phase 3: confirm the FIFO actually works again ---
            post_wseq = fifo_write_sequence::type_id::create("post_wseq");
            post_rseq = fifo_read_sequence::type_id::create("post_rseq");
            post_wseq.num_items = 15;
            post_rseq.num_items = 15;

            fork
                post_wseq.start(env.write_agent.sequencer);
                post_rseq.start(env.read_agent.sequencer);
            join

            repeat (5) @(posedge env.read_agent.driver.vif.r_clk);

            phase.drop_objection(this);
        endtask

    endclass

endpackage


//==========================================================================
// SECTION 3: TESTBENCH TOP
// Generates both clocks, instantiates the interface and DUT, and kicks off
// UVM. No test is hardcoded here - select which one runs via
// +UVM_TESTNAME=<test_name> on the simulation command line (defaults to
// fifo_test if you don't pass one).
//==========================================================================

import uvm_pkg::*;
`include "uvm_macros.svh"
import fifo_pkg::*;

module tb_top;

    // Clock periods in ns, overridable at elaboration time without
    // touching this file - see the -generic instructions below.
    // Defaults reproduce the original fixed ratio this project has been
    // tested with so far: write clock 4x faster than read clock.
    parameter real W_CLK_PERIOD = 10.0; // 100 MHz write clock (default)
    parameter real R_CLK_PERIOD = 40.0; // 25 MHz  read  clock (default)

    // DUT parameters. IMPORTANT: unlike W_CLK_PERIOD/R_CLK_PERIOD above,
    // DUT_PTR_WIDTH cannot be safely changed via -generic at elaboration
    // time. Every `virtual fifo_if` handle throughout the testbench
    // (drivers, monitors, coverage) is typed by fifo_if's DECLARED
    // DEFAULT parameter value at compile time, not by whatever value
    // gets passed to the actual instantiated interface here. Overriding
    // only the instance via -generic makes the instance's type diverge
    // from every virtual interface handle's type elsewhere, causing an
    // "incompatible complex type assignment" elaboration error.
    //
    // The correct way to change PTR_WIDTH is to edit BOTH of these
    // together, as source defaults, matching:
    //   1. fifo_if's own declared default (see the interface declaration
    //      near the top of this file: `parameter PTR_WIDTH = ...`)
    //   2. DUT_PTR_WIDTH below
    // Then recompile normally (no -generic needed for this parameter).
    // Currently both are set to 3 (depth 4) for the minimum-depth test -
    // revert both back to the project's default of 4 (depth 8) before
    // running the rest of the regression.
    //
    // DUT_DATA_WIDTH has the same constraint in principle, but hasn't
    // been exercised here since fifo_item's `data` field is a fixed
    // 8 bits wide regardless (a compile-time class parameter, not wired
    // through from the interface) - widening DUT_DATA_WIDTH would only
    // confirm the wider bus connects, not exercise genuinely wider
    // randomized data, so it wasn't pursued given the added complexity.
    parameter int DUT_DATA_WIDTH = 8;
    parameter int DUT_PTR_WIDTH  = 4; // matches fifo_if's default above - see note

    bit w_clk;
    bit r_clk;

    always #(W_CLK_PERIOD/2.0) w_clk = ~w_clk;
    always #(R_CLK_PERIOD/2.0) r_clk = ~r_clk;

    fifo_if #(.DATA_WIDTH(DUT_DATA_WIDTH), .PTR_WIDTH(DUT_PTR_WIDTH)) vif (
        .w_clk(w_clk),
        .r_clk(r_clk)
    );

    top_module #(
        .DATA_WIDTH(DUT_DATA_WIDTH),
        .PTR_WIDTH(DUT_PTR_WIDTH)
    ) dut (
        .rst(vif.rst),

        .w_clk(vif.w_clk),
        .w_en(vif.w_en),
        .w_data(vif.w_data),
        .full(vif.full),

        .r_clk(vif.r_clk),
        .r_en(vif.r_en),
        .r_data(vif.r_data),
        .empty(vif.empty)
    );

    // Wires the DUT's internal pointer registers out to the interface's
    // debug signals. Legal here (module referencing its own submodule
    // instance) even though the same reference from inside fifo_pkg was
    // rejected by xsim - packages can't hierarchically reference a
    // specific module instance, but a module referencing its own child
    // instance is completely normal.
    assign vif.dbg_wptr_bin = dut.wptr_bin;
    assign vif.dbg_rptr_bin = dut.rptr_bin;

    initial begin
        uvm_config_db#(virtual fifo_if)::set(null, "*", "vif", vif);
        run_test();
    end

endmodule