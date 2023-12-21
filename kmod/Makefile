dtbo-y += \
	dts/BB-BONE-eMMC1-DISABLE-01-00A0.dtbo \
	dts/BB-HDMI-TDA998x-DISABLE-00A0.dtbo \
	dts/BW-ICE40Cape-00A0.dtbo

obj-m += led-driver.o

%.dtbo: %.dts
	cpp -nostdinc -I /lib/modules/$(shell uname -r)/build/include -undef -x assembler-with-cpp $? $?.tmp
	dtc -I dts -O dtb $?.tmp -o $@

all: modules dtbs

dtbs: $(dtbo-y)

modules:
	make -C /lib/modules/$(shell uname -r)/build/ M=$(PWD) modules

clean:
	make -C /lib/modules/$(shell uname -r)/build/ M=$(PWD) clean

# Running this as sudo causes $PWD to not be set properly!
modules_install:
	make -C /lib/modules/$(shell uname -r)/build/ M=$(PWD) modules_install
