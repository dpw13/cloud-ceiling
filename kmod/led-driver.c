#include <linux/of.h>
#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/init.h>
#include <linux/mm.h>
#include <linux/dmaengine.h>
#include <linux/dma-mapping.h>
#include <linux/slab.h>

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Dane Wagner");
MODULE_DESCRIPTION("Multi-string LED driver");

static unsigned int n_strings = 2;
module_param(n_strings, uint, S_IRUGO | S_IWUSR);
MODULE_PARM_DESC(n_strings,
		"Number of strings implemented (default: 1)");

static unsigned int n_leds_per_string = 150;
module_param(n_leds_per_string, uint, S_IRUGO | S_IWUSR);
MODULE_PARM_DESC(n_leds_per_string,
		"Number of LEDs per string (default: 1)");

static struct ledfb_struct {
        struct device *dev;
        int major;
        struct dma_chan *chan;
        dma_addr_t src_handle;
        void *fb;
        size_t fb_size;
        struct dma_async_tx_descriptor *tx;
} ledfb_dev;

#define BUFFER_SIZE 0x2000
#define FPGA_FIFO_ADDR 0x1001000UL

static const struct vm_operations_struct mmap_ledfb_ops = {};

static long ioctl_ledfb(struct file *filp, unsigned int ioctl_num, unsigned long ioctl_param)
{
        dev_info(ledfb_dev.dev, "Got ioctl: %u %lu\n", ioctl_num, ioctl_param);

        ledfb_dev.tx->tx_submit(ledfb_dev.tx);

        return 0;
}

static void dma_callback(void *arg)
{
        dev_info(ledfb_dev.dev, "DMA callback\n");
}

static int mmap_ledfb(struct file *filp, struct vm_area_struct *vma)
{
        size_t size = vma->vm_end - vma->vm_start;
        phys_addr_t offset = (phys_addr_t)vma->vm_pgoff << PAGE_SHIFT;

        /* Only an offset of zero is supported */
        if (offset != 0)
                return -EINVAL;

        /* Maximum size is two pages */
        if (size > 0x2000)
                return -EINVAL;

        vma->vm_ops = &mmap_ledfb_ops;

        if (remap_pfn_range(vma,
                             virt_to_phys((void*)((unsigned long)ledfb_dev.fb)),
                             0,
                             size,
                             vma->vm_page_prot)) {
                return -ENXIO;
        }
        return 0;
}

static int open_ledfb(struct inode *inode, struct file *filp)
{
	return capable(CAP_SYS_RAWIO) ? 0 : -EPERM;
}

static const struct file_operations __maybe_unused mem_fops = {
        .mmap           = mmap_ledfb,
        .open           = open_ledfb,
        .unlocked_ioctl = ioctl_ledfb,
};

static int memory_open(struct inode *inode, struct file *filp)
{
        int minor;

        minor = iminor(inode);
        if (minor != 1)
                return -ENXIO;

        filp->f_op = &mem_fops;
        filp->f_mode |= FMODE_UNSIGNED_OFFSET;

        return open_ledfb(inode, filp);
}

static const struct file_operations memory_fops = {
        .open = memory_open,
        .llseek = noop_llseek,
};

static struct class *ledfb_class;

#if 0
#define DMA_CHANNEL_NAME "dma0chan20"
#define DMA_DEVICE_NAME "49000000.edma"

static bool dma_filter(struct dma_chan *chan, void *param)
{
        pr_info("Checking %s %s\n", dma_chan_name(chan), dev_name(chan->device->dev));
	if (strcmp(dma_chan_name(chan), DMA_CHANNEL_NAME) != 0 ||
	    strcmp(dev_name(chan->device->dev), DMA_DEVICE_NAME) != 0)
		return false;
	else
		return true;
}
#endif

static int __init led_driver_init(void)
{
        //dma_cap_mask_t mask;
        int ret = 0;
	pr_info("Starting LED framebuffer\n");

        ledfb_dev.major = register_chrdev(0, "ledfb", &memory_fops);
        if (ledfb_dev.major < 0) {
                pr_info("unable to get major for ledfb devices\n");
                ret = ledfb_dev.major;
                goto failed_dev_register;
        } else {
                pr_info("allocated major %d\n", ledfb_dev.major);
        }

        ledfb_class = class_create(THIS_MODULE, "ledfb");
        if (IS_ERR(ledfb_class)) {
                ret = PTR_ERR(ledfb_class);
                goto failed_class_create;
        }

        ledfb_dev.dev = device_create(ledfb_class, NULL, MKDEV(ledfb_dev.major, 1),
	   	      NULL, "ledfb");
        if (IS_ERR(ledfb_dev.dev)) {
                ret = PTR_ERR(ledfb_class);
                goto failed_dev_create;
        }

        /* Find DMA device */
        dmaengine_get();

        /*
	dma_cap_zero(mask);
	dma_cap_set(DMA_MEMCPY, mask);

        ledfb_dev.chan = dma_request_channel(mask, dma_filter, NULL);
         */

        /* Channels allocated for memcpy are public and cannot be exclusively requested */
        ledfb_dev.chan = dma_find_channel(DMA_MEMCPY);
        if (!ledfb_dev.chan) {
                dev_err(ledfb_dev.dev, "Failed to request DMA channel\n");
                ret = -ENODEV;
                goto failed_dma_req;
        } else {
                dev_info(ledfb_dev.dev, "using channel %s for DMA", dma_chan_name(ledfb_dev.chan));
        }

        /* Allocate contiguous buffer from kernel memory */
        ledfb_dev.fb = kmalloc(BUFFER_SIZE, GFP_KERNEL);
        if (!ledfb_dev.fb) {
                pr_err("Failed to allocate framebuffer\n");
                ret = -ENOMEM;
                goto failed_alloc;
        }

        /* Map buffer for DMA */
	ledfb_dev.src_handle = dma_map_single(ledfb_dev.dev, ledfb_dev.fb, BUFFER_SIZE, DMA_TO_DEVICE);
	if (dma_mapping_error(ledfb_dev.dev, ledfb_dev.src_handle)) {
                dev_err(ledfb_dev.dev, "Failed to map buffer for DMA\n");
                ret = -ENXIO;
                goto failed_map;
	}

        /* Create tx descriptor */
        ledfb_dev.fb_size = n_strings * n_leds_per_string * 3; // 3 color bytes per pixel
        ledfb_dev.tx = ledfb_dev.chan->device->device_prep_dma_memcpy(
                ledfb_dev.chan,
                FPGA_FIFO_ADDR, // destination bus address
                ledfb_dev.src_handle, // src bus address
                ledfb_dev.fb_size, // size
                0); // dma_ctrl_flags

        if (!ledfb_dev.tx) {
                dev_err(ledfb_dev.dev, "Failed to create TX descriptor\n");
                ret = -ENXIO;
                goto failed_tx_desc;
        }

        ledfb_dev.tx->callback = dma_callback;
        goto success;

failed_tx_desc:
	dma_unmap_single(ledfb_dev.dev, ledfb_dev.src_handle, BUFFER_SIZE, DMA_TO_DEVICE);
failed_map:
        kfree(ledfb_dev.fb);
failed_alloc:
        //dma_release_channel(ledfb_dev.chan); // exclusive access only
failed_dma_req:
        dmaengine_put();
        device_destroy(ledfb_class, MKDEV(ledfb_dev.major, 1));
failed_dev_create:
        class_destroy(ledfb_class);
failed_class_create:
        unregister_chrdev(ledfb_dev.major, "ledfb");
failed_dev_register:
success:
	return ret;
}

static void __exit led_driver_cleanup(void)
{
	dev_info(ledfb_dev.dev, "Stopping LED framebuffer\n");

	dma_unmap_single(ledfb_dev.dev, ledfb_dev.src_handle, BUFFER_SIZE, DMA_TO_DEVICE);
        kfree(ledfb_dev.fb);
        //dma_release_channel(ledfb_dev.chan); // exclusive access only
        dmaengine_put();

        device_destroy(ledfb_class, MKDEV(ledfb_dev.major, 1));
        class_destroy(ledfb_class);
        unregister_chrdev(ledfb_dev.major, "ledfb");
}

module_init(led_driver_init);
module_exit(led_driver_cleanup);
