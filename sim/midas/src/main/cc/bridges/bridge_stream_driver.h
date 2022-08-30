// See LICENSE for license details.

#ifndef __BRIDGES_BRIDGE_STREAM_DRIVER_H
#define __BRIDGES_BRIDGE_STREAM_DRIVER_H

class FPGAToCPUStreamDriver {
public:
  virtual size_t pull(void *dest, size_t num_bytes, size_t required_bytes) = 0;
  virtual void flush() = 0;
};

class CPUToFPGAStreamDriver {
public:
  virtual size_t push(void *src, size_t num_bytes, size_t required_bytes) = 0;
  virtual void flush() = 0;
};

#endif // __CORE_BRIDGE_STREAM_DRIVER_H