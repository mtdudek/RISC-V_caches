# RISC-V_caches

Rdzenie procesora RISC-V pochodzą z reposytorium https://github.com/tilk/riscv-simple-sv z gałęzi ram_with_latency,
zamieniłem tylko plik singlecycle/toplevel.sv aby dodać cache instrukcji.

RISC-V cores are from this repository https://github.com/tilk/riscv-simple-sv from branch ram_with_latency,
I only changed singlecycle/toplevel.sv to include instruction cache. 

# TO-DO:

1. dodatnie cache danych/ add data cache
2. dodatnie interfejsu synchronizacji cache-y/ add cache synchronization interface
3. dodatnie bufora usuniętych lini/ add eviction buffer
4. dodać prefetcher/ add prefetcher
5. LLC