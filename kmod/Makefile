obj-m+=led-driver.o

all:
	make -C /lib/modules/$(shell uname -r)/build/ M=$(PWD) modules

clean:
	make -C /lib/modules/$(shell uname -r)/build/ M=$(PWD) clean

# Running this as sudo causes $PWD to not be set properly!
modules_install:
	make -C /lib/modules/$(shell uname -r)/build/ M=$(PWD) modules_install
