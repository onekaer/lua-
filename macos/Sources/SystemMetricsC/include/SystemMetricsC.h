#include <stdint.h>
typedef struct { double cpu; uint64_t memoryUsed, memoryTotal, received, sent; int valid; } LuaMetrics;
LuaMetrics lua_metrics(void);
