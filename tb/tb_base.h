#pragma once

#include "verilated.h"

#ifdef VCD
#include "verilated_vcd_c.h"
#endif

#include "svdpi.h"

#include <unistd.h>
#include <stdlib.h>

template <class Module>
class Tb_Base {
    int time;
    int timeIncPerTick;
    Module * top;
    VerilatedContext * ctx;
    VerilatedVcdC * trace;

public:

    Tb_Base(int argc, char **argv){
        this->ctx = new VerilatedContext;
        this->ctx->commandArgs(argc, argv);
        this->top = new Module(ctx);
        this->top->rst = 1;
        this->top->clk = 0;

        this->time = 0;
        this->timeIncPerTick = std::pow(10, ctx->timeunit() - ctx->timeprecision());

#ifdef VCD
        Verilated::traceEverOn(true);
        this->trace = new VerilatedVcdC;
        this->top->trace(trace,99);
        this->trace->open(VCD_FILE);
#endif
    }

    virtual ~Tb_Base(){
#ifdef VCD
        this->trace->close();
#endif
        delete top;
        delete ctx;
    }

    //assumes clock is toggled every 0.5 time units
    virtual void toggleClock(){
        top->rst = time < 2;
        top->clk ^= 1;
        top->eval();

#ifdef VCD
        trace->dump(time);
#endif
        time++;

        //for timing support if needed
        top->contextp()->timeInc(timeIncPerTick/2);
    }

    virtual bool isDone(){
        return this->ctx->gotFinish();
    }

    int getTime() {
        return time;
    }

    Module * getTop(void) {
        return this->top;
    }

    VerilatedContext * getCtx(void) {
        return this->ctx;
    }
};