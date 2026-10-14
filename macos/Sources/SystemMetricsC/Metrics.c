#include "SystemMetricsC.h"
#include <mach/mach.h>
#include <sys/sysctl.h>
#include <ifaddrs.h>
#include <net/if.h>
#include <net/if_dl.h>
#include <string.h>
LuaMetrics lua_metrics(void) {
 LuaMetrics out = {0}; static uint64_t oldTotal=0, oldIdle=0;
 host_cpu_load_info_data_t cpu; mach_msg_type_number_t count=HOST_CPU_LOAD_INFO_COUNT;
 mach_port_t host=mach_host_self();
 if(host_statistics(host,HOST_CPU_LOAD_INFO,(host_info_t)&cpu,&count)==KERN_SUCCESS){
  uint64_t total=0;for(int i=0;i<CPU_STATE_MAX;i++)total+=cpu.cpu_ticks[i];
  uint64_t idle=cpu.cpu_ticks[CPU_STATE_IDLE];
  if(oldTotal && total>oldTotal && idle>=oldIdle)out.cpu=100.0*(1.0-(double)(idle-oldIdle)/(double)(total-oldTotal));
  oldTotal=total;oldIdle=idle;out.valid=1;
 }
 size_t size=sizeof(out.memoryTotal);sysctlbyname("hw.memsize",&out.memoryTotal,&size,NULL,0);
 vm_statistics64_data_t vm;count=HOST_VM_INFO64_COUNT;
 if(host_statistics64(host,HOST_VM_INFO64,(host_info64_t)&vm,&count)==KERN_SUCCESS){
  vm_size_t page;host_page_size(host,&page);
  uint64_t used=(uint64_t)(vm.active_count+vm.wire_count+vm.compressor_page_count)*page;
  out.memoryUsed=used>out.memoryTotal?out.memoryTotal:used;
 }
 mach_port_deallocate(mach_task_self(),host);
 struct ifaddrs *head=NULL;
 if(getifaddrs(&head)==0){for(struct ifaddrs *p=head;p;p=p->ifa_next){
  if(!p->ifa_addr||p->ifa_addr->sa_family!=AF_LINK||!p->ifa_data||(p->ifa_flags&IFF_LOOPBACK)||!(p->ifa_flags&IFF_UP))continue;
  // Count physical Ethernet/Wi-Fi only; utun/bridges otherwise duplicate VPN traffic.
  if(strncmp(p->ifa_name,"en",2))continue;
  struct if_data *data=(struct if_data *)p->ifa_data;out.received+=data->ifi_ibytes;out.sent+=data->ifi_obytes;
 }freeifaddrs(head);}
 return out;
}
