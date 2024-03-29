// RISC-V SiMPLE SV -- testbench
// BSD 3-Clause License
// (c) 2019, Marek Materzok, University of Wrocław

#include "Vtoplevel.h"
#include "verilated.h"
#include <iostream>
#include <iomanip>
#include <memory>
#include <string>
#include <sstream>

std::string text_file, data_file;

extern "C" const char* text_mem_file()
{
    return text_file.c_str();
}

extern "C" const char* data_mem_file()
{
    return data_file.c_str();
}

int main(int argc, const char **argv, const char **env)
{
    Verilated::commandArgs(argc, argv);

    bool verbose = false;
    const char *str;
    str = Verilated::commandArgsPlusMatch("text_file=");
    if (str && str[0]) text_file = str + 11;
    str = Verilated::commandArgsPlusMatch("data_file=");
    if (str && str[0]) data_file = str + 11;
    str = Verilated::commandArgsPlusMatch("verbose");
    if (str && str[0]) verbose = true;

    std::unique_ptr<Vtoplevel> top(new Vtoplevel);

    std::stringstream buffer;

    top->reset = 0;
    for (int time = 0; time < 100000; time++) {
        if (time > 9)
            top->reset = 0;
        else if (time > 4)
            top->reset = 1;
        top->clock = time & 1;
        top->eval();

        if (verbose && top->clock && time > 8) {
            std::cout << std::hex << std::setfill('0')
                      << "pc=" << std::setw(8) << top->pc << " "
                      << "inst=" << std::setw(8) << top->inst << " "
                      << (top->inst_wait_req ? "W" : "w") << " "
                      << (top->inst_valid ? "V" : "v") << " "
                      << (top->inst_read_enable ? "E" : "e") << " "
                      << "addr=" << std::setw(8) << top->bus_address << " "
                      << "in=" << std::setw(8) << top->bus_read_data << " "
                      << (top->bus_wait_req ? "W" : "w") << " "
                      << (top->bus_valid ? "V" : "v") << " "
                      << (top->bus_read_enable ? "E" : "e") << " "
                      << "out=" << std::setw(8) << top->bus_write_data << " "
                      << (top->bus_write_enable ? "E" : "e") << " " 
                      << "fmt=" << (int)top->bus_byte_enable << "\n";
            std::cout << std::hex << std::setfill('0')
                      << "cache_address=" << std::setw(8) << top->cache_adress_to_mem << " "
                      << "cache_data=" << std::setw(16) << top->data_to_cache << " "
                      << (top->waitrequest_to_cache ? "W" : "w") << " "
                      << (top->data_to_cache_valid ? "V" : "v") << " "
                      << (top->cache_reads ? "E" : "e") << "\n";
        }
        if (top->bus_write_enable && top->bus_address == 0xfffffff0) {
            if (top->bus_write_data) {
                std::cout << "PASS " << time << std::endl;
                return 0;
            } else {
                std::cout << "FAIL " << time << std::endl;
                return -1;
            }
        }
    }

    std::cout << "TIMEOUT" << std::endl;

    return -1;
}

