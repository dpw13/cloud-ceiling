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

static struct ledfb_struct {
        struct device *dev;
        int major;
        struct dma_chan *chan;
        dma_addr_t src_handle;
        void *fb;
        size_t fb_size;
        int frame;
} ledfb_dev;

// The maximum buffer size in bytes
#define BUFFER_SIZE 0x4000
#define FPGA_FIFO_ADDR 0x1001000UL

static const struct vm_operations_struct mmap_ledfb_ops = {};

static void dma_callback(void *arg)
{
        dev_dbg(ledfb_dev.dev, "DMA callback\n");
        ledfb_dev.frame++;
}

static long ioctl_ledfb(struct file *filp, unsigned int ioctl_num, unsigned long ioctl_param)
{
        struct dma_async_tx_descriptor *tx;
        dma_addr_t buf_start, buf_end;
        dma_cookie_t cookie;

        dev_dbg(ledfb_dev.dev, "Got ioctl: %u %lu. Frame %d\n", ioctl_num, ioctl_param, ledfb_dev.frame);
        if (ioctl_param > 0) {
                ledfb_dev.fb_size = (size_t) ioctl_param;
        }
        if (ledfb_dev.fb_size == 0 || ledfb_dev.fb_size > BUFFER_SIZE) {
                dev_warn(ledfb_dev.dev, "Invalid buffer size specified in ioctl: %lu", ioctl_param);
                ledfb_dev.fb_size = 0;
                return -EINVAL;
        }

        buf_start = ledfb_dev.src_handle;
        buf_end = ledfb_dev.src_handle + ledfb_dev.fb_size;

        while (buf_start < buf_end) {
                /* DMA is only issuing a page at a time? */
                size_t buf_size = buf_end - buf_start;
                if (buf_size > 4096)
                        buf_size = 4096;

                /* Create tx descriptor */
                tx = ledfb_dev.chan->device->device_prep_dma_memcpy(
                        ledfb_dev.chan,
                        FPGA_FIFO_ADDR, // destination bus address
                        buf_start, // src bus address
                        buf_size, // size
                        0); // dma_ctrl_flags

                if (!tx) {
                        dev_err(ledfb_dev.dev, "Failed to create TX descriptor\n");
                        return -ENXIO;
                }

                tx->callback = dma_callback;

                /* I can't tell whether tx is consumed here or not */
                cookie = tx->tx_submit(tx);

                if (dma_submit_error(cookie)) {
                        dev_err(ledfb_dev.dev, "Failed to submit TX descriptor");
                        return -EINVAL;
                }

                buf_start += buf_size;
        }
        dma_async_issue_pending(ledfb_dev.chan);

        return 0;
}

#ifndef __HAVE_PHYS_MEM_ACCESS_PROT
static pgprot_t phys_mem_access_prot(struct file *file, unsigned long pfn,
				     unsigned long size, pgprot_t vma_prot)
{
#ifdef pgprot_noncached
	phys_addr_t offset = pfn << PAGE_SHIFT;

	if (uncached_access(file, offset))
		return pgprot_noncached(vma_prot);
#endif
	return vma_prot;
}
#endif

static int mmap_ledfb(struct file *filp, struct vm_area_struct *vma)
{
        size_t size = vma->vm_end - vma->vm_start;
        phys_addr_t offset = (phys_addr_t)vma->vm_pgoff << PAGE_SHIFT;
        phys_addr_t fb_bus = virt_to_pfn(ledfb_dev.fb);

        /* Only an offset of zero is supported */
        if (offset != 0) {
                dev_err(ledfb_dev.dev, "Invalid offset: %pa", &offset);
                return -EINVAL;
        }

        /* Maximum size is two pages */
        if (size > BUFFER_SIZE) {
                dev_err(ledfb_dev.dev, "Invalid size: %zx", size);
                return -EINVAL;
        }

        /*
         * The size here is coerced to a multiple of the page size, so we
         * can't set an accurate FB size from the mmap()
         */
        ledfb_dev.fb_size = 0;
        ledfb_dev.frame = 0;

	vma->vm_page_prot = phys_mem_access_prot(filp, vma->vm_pgoff,
                                                size,
                                                vma->vm_page_prot);

        vma->vm_ops = &mmap_ledfb_ops;

        if (remap_pfn_range(vma,
                            vma->vm_start,
                            fb_bus,
                            size,
                            vma->vm_page_prot)) {
                dev_err(ledfb_dev.dev, "Failed to remap offset %p (phys %pa)", ledfb_dev.fb, &fb_bus);
                return -ENXIO;
        }

        dev_info(ledfb_dev.dev, "Mapped buffer kvirt = %p phys %pa start %lx end %lx", ledfb_dev.fb, &fb_bus, vma->vm_start, vma->vm_end);

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

static const struct file_operations memory_fops = {
        .mmap           = mmap_ledfb,
        .open           = open_ledfb,
        .unlocked_ioctl = ioctl_ledfb,
        .llseek = noop_llseek,
};

static struct class *ledfb_class;

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

        goto success;

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
