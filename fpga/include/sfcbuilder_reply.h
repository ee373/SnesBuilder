#ifndef SFCBUILDER_REPLY_H
#define SFCBUILDER_REPLY_H

#include <stdbool.h>
#include <stdint.h>

/* Call from the RISC-V communication task that owns REPLY writes.
 * False leaves the reply for the caller to retry after the SFC ACK.
 */
static inline bool sfcbuilder_try_reply(uint8_t value)
{
    const volatile uint32_t *const irq_status =
        (const volatile uint32_t *)(uintptr_t)0x60001024u;
    volatile uint32_t *const reply =
        (volatile uint32_t *)(uintptr_t)0x6000100Cu;

    if (*irq_status & (1u << 1))
        return false;

    __asm__ volatile ("fence iorw, iorw" ::: "memory");
    *reply = value;
    __asm__ volatile ("fence iorw, iorw" ::: "memory");
    return true;
}

#endif
