Driver notes

- allocate buffers using kmalloc to get a contiguous buffer with a straightformward physical mapping
- map buffer into userspace using remap_page_range()
- get handle to DMA using dma_request_channel() using filter_fn to select the required device and channel number
- get tx descriptor using dev->device_prep_dma_memcpy()

		cookie = tx->tx_submit(tx); // OR dmaengine_submit()?

		if (dma_submit_error(cookie)) {
			result("submit error", total_tests, src_off,
			       dst_off, len, ret);
			msleep(100);
			goto error_unmap_continue;
		}
		dma_async_issue_pending(chan);

- check completion using callback or dma_async_is_tx_complete()

echo 'file dmaengine.c +p'>/sys/kernel/debug/dynamic_debug/control
echo 'file edma.c +p'>/sys/kernel/debug/dynamic_debug/control
echo 'file virt-dma.c +p'>/sys/kernel/debug/dynamic_debug/control