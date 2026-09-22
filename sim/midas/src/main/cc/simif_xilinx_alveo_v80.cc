#include <cassert>
#include <cinttypes>
#include <cstdio>
#include <cstdlib>
#include <cstring>

#include <fcntl.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <time.h>
#include <unistd.h>

#include "bridges/cpu_managed_stream.h"
#include "core/simif.h"

#define PCI_DEV_FMT "%04x:%02x:%02x.%d"

// QDMA MM descriptors carry raw AXI addresses onto CPM_PCIE_NOC.
// The NoC routes by address to M00_AXI (PCIE_M_AXI) which connects to
// F1Shim io_pcis. The RTL strips this base and passes lower 32 bits.
static constexpr uint64_t PCIS_NOC_BASE = 0x20300000000ULL;

class simif_xilinx_alveo_v80_t final : public simif_t,
                                       public CPUManagedStreamIO {
public:
  simif_xilinx_alveo_v80_t(const TargetConfig &config,
                           const std::vector<std::string> &args);
  ~simif_xilinx_alveo_v80_t();

  void write(size_t addr, uint32_t data) override;
  uint32_t read(size_t addr) override;

  uint32_t is_write_ready();
  void check_rc(int rc, char *infostr);
  void fpga_shutdown();
  void fpga_setup(uint16_t domain_id,
                  uint8_t bus_id,
                  uint8_t device_id,
                  uint8_t pf_id,
                  uint8_t bar_id,
                  uint16_t pci_vendor_id,
                  uint16_t pci_device_id);

  CPUManagedStreamIO &get_cpu_managed_stream_io() override { return *this; }

private:
  uint32_t mmio_read(size_t addr) override { return read(addr); }
  size_t
  cpu_managed_axi4_write(size_t addr, const char *data, size_t size) override;
  size_t cpu_managed_axi4_read(size_t addr, char *data, size_t size) override;
  uint64_t get_beat_bytes() const override {
    return config.cpu_managed->beat_bytes();
  }

  void *bar_get_mem_at_offset(uint64_t offset);
  int fpga_pci_poke(uint64_t offset, uint32_t value);
  int fpga_pci_peek(uint64_t offset, uint32_t *value);

  int qdma_fd;
  void *bar1_base;
  uint32_t bar1_size = 0x2000000; // 32 MB BAR1 (AXI Bridge Master -> io_master)

  // MMIO trace instrumentation
  bool trace_mmio = false;
  uint64_t mmio_seq = 0;
  uint64_t mmio_rd_count = 0;
  uint64_t mmio_wr_count = 0;
  struct timespec ts_start;
  struct timespec ts_last_report;
  double elapsed_sec() const {
    struct timespec now;
    clock_gettime(CLOCK_MONOTONIC, &now);
    return (now.tv_sec - ts_start.tv_sec) +
           (now.tv_nsec - ts_start.tv_nsec) * 1e-9;
  }
  void maybe_report() {
    struct timespec now;
    clock_gettime(CLOCK_MONOTONIC, &now);
    double since = (now.tv_sec - ts_last_report.tv_sec) +
                   (now.tv_nsec - ts_last_report.tv_nsec) * 1e-9;
    if (since >= 2.0) {
      fprintf(stderr,
              "[V80-TRACE] %.3fs | %lu txns total (%lu rd, %lu wr)\n",
              elapsed_sec(), mmio_seq, mmio_rd_count, mmio_wr_count);
      ts_last_report = now;
    }
  }
};

static int fpga_pci_check_file_id(char *path, uint16_t id) {
  if (path) {
    fprintf(stdout, "Opening %s\n", path);
  } else {
    assert(path);
  }
  int ret = 0;
  FILE *fp = fopen(path, "r");
  assert(fp);
  uint32_t tmp_id;
  ret = fscanf(fp, "%x", &tmp_id);
  assert(ret >= 0);
  assert(tmp_id == id);
  fclose(fp);
  return 0;
}

simif_xilinx_alveo_v80_t::simif_xilinx_alveo_v80_t(
    const TargetConfig &config, const std::vector<std::string> &args)
    : simif_t(config), qdma_fd(-1), bar1_base(nullptr) {

  std::optional<uint16_t> domain_id;
  std::optional<uint8_t> bus_id;
  std::optional<uint8_t> device_id;
  std::optional<uint8_t> pf_id;
  std::optional<uint8_t> bar_id;
  std::optional<uint16_t> pci_vendor_id;
  std::optional<uint16_t> pci_device_id;

  for (auto &arg : args) {
    if (arg.find("+domain=") == 0) {
      printf("+domain found: %s\n", arg.c_str() + 8);
      domain_id = strtoul(arg.c_str() + 8, NULL, 16);
      continue;
    }
    if (arg.find("+bus=") == 0) {
      printf("+bus found: %s\n", arg.c_str() + 5);
      bus_id = strtoul(arg.c_str() + 5, NULL, 16);
      continue;
    }
    if (arg.find("+device=") == 0) {
      printf("+device found: %s\n", arg.c_str() + 8);
      device_id = strtoul(arg.c_str() + 8, NULL, 16);
      continue;
    }
    if (arg.find("+function=") == 0) {
      printf("+function found: %s\n", arg.c_str() + 10);
      pf_id = strtoul(arg.c_str() + 10, NULL, 16);
      continue;
    }
    if (arg.find("+bar=") == 0) {
      printf("+bar found: %s\n", arg.c_str() + 5);
      bar_id = strtoul(arg.c_str() + 5, NULL, 16);
      continue;
    }
    if (arg.find("+pci-vendor=") == 0) {
      pci_vendor_id = strtoul(arg.c_str() + 12, NULL, 16);
      continue;
    }
    if (arg.find("+pci-device=") == 0) {
      pci_device_id = strtoul(arg.c_str() + 12, NULL, 16);
      continue;
    }
    if (arg.find("+v80-trace-mmio") == 0) {
      trace_mmio = true;
      continue;
    }
  }

  clock_gettime(CLOCK_MONOTONIC, &ts_start);
  ts_last_report = ts_start;
  if (trace_mmio) {
    fprintf(stderr, "[V80-TRACE] MMIO tracing enabled via +v80-trace-mmio\n");
  }

  if (!domain_id) {
    fprintf(stderr, "Domain ID not specified. Assuming Domain ID 0\n");
    domain_id = 0;
  }
  if (!bus_id) {
    fprintf(stderr, "Bus ID not specified. Assuming Bus ID 0\n");
    bus_id = 0;
  }
  if (!device_id) {
    fprintf(stderr, "Device ID not specified. Assuming Device ID 0\n");
    device_id = 0;
  }
  if (!pf_id) {
    fprintf(stderr, "Function ID not specified. Assuming Function ID 0\n");
    pf_id = 0;
  }
  if (!bar_id) {
    fprintf(stderr, "BAR ID not specified. Assuming BAR ID 1\n");
    bar_id = 1;
  }
  if (!pci_vendor_id) {
    fprintf(stderr,
            "PCI Vendor ID not specified. Assuming PCI Vendor ID 0x10ee\n");
    pci_vendor_id = 0x10ee;
  }
  if (!pci_device_id) {
    fprintf(stderr,
            "PCI Device ID not specified. Assuming PCI Device ID 0x903f\n");
    pci_device_id = 0x903f;
  }

  printf("Using: " PCI_DEV_FMT
         ", BAR ID: %u, PCI Vendor ID: 0x%04x, PCI Device ID: 0x%04x\n",
         *domain_id,
         *bus_id,
         *device_id,
         *pf_id,
         *bar_id,
         *pci_vendor_id,
         *pci_device_id);

  fpga_setup(*domain_id,
             *bus_id,
             *device_id,
             *pf_id,
             *bar_id,
             *pci_vendor_id,
             *pci_device_id);
}

void *
simif_xilinx_alveo_v80_t::bar_get_mem_at_offset(uint64_t offset) {
  assert(!(((uint64_t)(offset + 4)) > bar1_size));
  return (uint8_t *)bar1_base + offset;
}

int simif_xilinx_alveo_v80_t::fpga_pci_poke(uint64_t offset, uint32_t value) {
  uint32_t *reg_ptr = (uint32_t *)bar_get_mem_at_offset(offset);
  *reg_ptr = value;
  return 0;
}

int simif_xilinx_alveo_v80_t::fpga_pci_peek(uint64_t offset, uint32_t *value) {
  uint32_t *reg_ptr = (uint32_t *)bar_get_mem_at_offset(offset);
  *value = *reg_ptr;
  return 0;
}

void simif_xilinx_alveo_v80_t::check_rc(int rc, char *infostr) {
  if (rc) {
    if (infostr) {
      fprintf(stderr, "%s\n", infostr);
    }
    fprintf(stderr, "INVALID RETCODE: %d\n", rc);
    fpga_shutdown();
    exit(1);
  }
}

void simif_xilinx_alveo_v80_t::fpga_shutdown() {
  if (bar1_base) {
    int ret = munmap(bar1_base, bar1_size);
    assert(ret == 0);
    bar1_base = nullptr;
  }
  if (qdma_fd >= 0) {
    close(qdma_fd);
    qdma_fd = -1;
  }
}

void simif_xilinx_alveo_v80_t::fpga_setup(uint16_t domain_id,
                                           uint8_t bus_id,
                                           uint8_t device_id,
                                           uint8_t pf_id,
                                           uint8_t bar_id,
                                           uint16_t pci_vendor_id,
                                           uint16_t pci_device_id) {

  int fd = -1;
  char sysfs_name[256];
  int ret;

  // Verify PCI vendor ID
  ret = snprintf(sysfs_name,
                 sizeof(sysfs_name),
                 "/sys/bus/pci/devices/" PCI_DEV_FMT "/vendor",
                 domain_id,
                 bus_id,
                 device_id,
                 pf_id);
  assert(ret >= 0);
  fpga_pci_check_file_id(sysfs_name, pci_vendor_id);

  // Verify PCI device ID
  ret = snprintf(sysfs_name,
                 sizeof(sysfs_name),
                 "/sys/bus/pci/devices/" PCI_DEV_FMT "/device",
                 domain_id,
                 bus_id,
                 device_id,
                 pf_id);
  assert(ret >= 0);
  fpga_pci_check_file_id(sysfs_name, pci_device_id);

  // mmap BAR1 for io_master (AXI Bridge Master MMIO)
  char bar_resource[256];
  ret = snprintf(bar_resource,
                 sizeof(bar_resource),
                 "/sys/bus/pci/devices/" PCI_DEV_FMT "/resource%d",
                 domain_id,
                 bus_id,
                 device_id,
                 pf_id,
                 bar_id);
  assert(ret >= 0);
  printf("Mapping BAR%d from %s\n", bar_id, bar_resource);

  fd = open(bar_resource, O_RDWR | O_SYNC);
  assert(fd != -1);

  bar1_base = mmap(0, bar1_size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
  assert(bar1_base != MAP_FAILED);
  close(fd);
  fd = -1;

  // QDMA DMA path is not connected in the V80 block design (the M_AXI NoC
  // route to io_pcis does not exist yet). Skip opening the QDMA MM channel
  // to avoid PCIe fatal errors from unroutable AXI transactions.
  // DMA read/write stubs below silently succeed so the stream engine
  // operates without crashing; trace data will be zeros.
  fprintf(stderr,
          "V80: QDMA DMA disabled (no NoC route for AXI512 PCIS path). "
          "MMIO-only mode.\n");
}

simif_xilinx_alveo_v80_t::~simif_xilinx_alveo_v80_t() {
  fprintf(stderr,
          "[V80-TRACE] SHUTDOWN after %.3fs | %lu txns (%lu rd, %lu wr)\n",
          elapsed_sec(), mmio_seq, mmio_rd_count, mmio_wr_count);
  fpga_shutdown();
}

void simif_xilinx_alveo_v80_t::write(size_t addr, uint32_t data) {
  uint64_t seq = mmio_seq++;
  mmio_wr_count++;
  if (trace_mmio) {
    fprintf(stderr,
            "[V80-TRACE] #%lu %.3fs WR addr=0x%08zx data=0x%08x\n",
            seq, elapsed_sec(), addr, data);
  }
  int rc = fpga_pci_poke(addr, data);
  if (trace_mmio) {
    fprintf(stderr,
            "[V80-TRACE] #%lu %.3fs WR addr=0x%08zx DONE rc=%d\n",
            seq, elapsed_sec(), addr, rc);
  }
  maybe_report();
  check_rc(rc, NULL);
}

uint32_t simif_xilinx_alveo_v80_t::read(size_t addr) {
  uint64_t seq = mmio_seq++;
  mmio_rd_count++;
  if (trace_mmio) {
    fprintf(stderr,
            "[V80-TRACE] #%lu %.3fs RD addr=0x%08zx ...\n",
            seq, elapsed_sec(), addr);
  }
  uint32_t value;
  fpga_pci_peek(addr, &value);
  value &= 0xFFFFFFFF;
  if (trace_mmio) {
    fprintf(stderr,
            "[V80-TRACE] #%lu %.3fs RD addr=0x%08zx => 0x%08x\n",
            seq, elapsed_sec(), addr, value);
  }
  maybe_report();
  return value;
}

size_t simif_xilinx_alveo_v80_t::cpu_managed_axi4_read(size_t addr,
                                                       char *data,
                                                       size_t size) {
  if (trace_mmio) {
    fprintf(stderr,
            "[V80-TRACE] DMA-RD addr=0x%016zx size=%zu (STUB: zero-fill)\n",
            addr, size);
  }
  memset(data, 0, size);
  return size;
}

size_t simif_xilinx_alveo_v80_t::cpu_managed_axi4_write(size_t addr,
                                                        const char *data,
                                                        size_t size) {
  if (trace_mmio) {
    fprintf(stderr,
            "[V80-TRACE] DMA-WR addr=0x%016zx size=%zu (STUB: discard)\n",
            addr, size);
  }
  return size;
}

uint32_t simif_xilinx_alveo_v80_t::is_write_ready() {
  uint64_t addr = 0x4;
  uint32_t value;
  int rc = fpga_pci_peek(addr, &value);
  check_rc(rc, NULL);
  value &= 0xFFFFFFFF;
  if (trace_mmio) {
    fprintf(stderr,
            "[V80-TRACE] is_write_ready() addr=0x%04lx => 0x%08x (%s)\n",
            addr, value, value ? "READY" : "NOT-READY");
  }
  return value;
}

std::unique_ptr<simif_t>
create_simif(const TargetConfig &config, int argc, char **argv) {
  std::vector<std::string> args(argv + 1, argv + argc);
  return std::make_unique<simif_xilinx_alveo_v80_t>(config, args);
}
