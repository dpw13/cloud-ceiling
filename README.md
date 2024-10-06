This repo contains all the code and build scripts for a one-off LED-based art installation. Detailed setup information (at least what currently exists) can be found on [hackaday.io](https://hackaday.io/project/190917-led-cloud-ceiling)

The project includes a number of different pieces organized into different folders:

* `hdl` contains the RTL for the iCE40 FPGA on the [BeagleWire](https://www.beagleboard.org/projects/beaglewire) cape for the [BeagleBone Black](https://www.beagleboard.org/boards/beaglebone-black).
* `kmod` contains the Linux kernel driver to expose the register map and framebuffer implemented in the FPGA.
* `rust` contains the REST server and test applications that run in userspace on the BeagleBone Black.
* `scripts` contains python scripts for rapid prototyping that directly access the kernel device or access the REST server.
* `gui` contains a web frontend for simple control of the ceiling.
