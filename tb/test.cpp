#include <iostream>

#include "verilated.h"

#include "Vtop.h"
//#include "Vtop__Dpi.h"

#include "tb_base.h"

int main(int argc, char ** argv){
    Tb_Base<Vtop> * top = new Tb_Base<Vtop>(argc, argv);

    while(!top->isDone() && top->getTime() < 300000){
        top->toggleClock();
    }

    delete top;
}
