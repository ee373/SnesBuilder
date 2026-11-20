#ifndef SFCBUILDER_AUDIO_H
#define SFCBUILDER_AUDIO_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#define SFCBUILDER_AUDIO_RATE 64000u
#define SFCBUILDER_AUDIO_FIFO_DEPTH 64u
#define SFCBUILDER_AUDIO_UNDERRUN (1u << 8)

#define SFCBUILDER_AUDIO_PCM (*(volatile uint32_t *)(uintptr_t)0x60002000u)
#define SFCBUILDER_AUDIO_STATUS (*(volatile const uint32_t *)(uintptr_t)0x60002004u)
#define SFCBUILDER_AUDIO_CONTROL (*(volatile uint32_t *)(uintptr_t)0x60002008u)

static inline void sfcbuilder_audio_enable(bool enable)
{
    SFCBUILDER_AUDIO_CONTROL = enable;
}

typedef void (*sfcbuilder_audio_render)(int16_t *samples, int sample_count);

// Call from one producer. The render callback has the cm_process signature.
// buffer must hold two interleaved samples for each frame of capacity.
static inline size_t sfcbuilder_audio_refill(sfcbuilder_audio_render render,
                                            int16_t *buffer, size_t capacity)
{
    const uint32_t used = SFCBUILDER_AUDIO_STATUS & 0x7fu;
    if (used >= SFCBUILDER_AUDIO_FIFO_DEPTH)
        return 0;

    size_t frames = SFCBUILDER_AUDIO_FIFO_DEPTH - used;
    if (frames > capacity)
        frames = capacity;
    if (frames != 0) {
        render(buffer, (int)(2 * frames));
        for (size_t i = 0; i < frames; ++i) {
            const uint32_t left = (uint16_t)buffer[2 * i];
            const uint32_t right = (uint16_t)buffer[2 * i + 1];
            SFCBUILDER_AUDIO_PCM = left | (right << 16);
        }
    }
    return frames;
}

#endif
