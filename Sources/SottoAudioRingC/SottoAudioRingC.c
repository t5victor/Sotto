#include "SottoAudioRingC.h"

#include <stdatomic.h>
#include <stdlib.h>

struct SottoAudioRingState {
    uint32_t capacity;
    _Atomic uint64_t write_sequence;
    _Atomic uint64_t read_sequence;
    _Atomic bool accepting;
    _Atomic bool overflowed;
};

SottoAudioRingState *sotto_audio_ring_create(uint32_t capacity) {
    if (capacity < 2) {
        return NULL;
    }
    SottoAudioRingState *state = calloc(1, sizeof(SottoAudioRingState));
    if (state == NULL) {
        return NULL;
    }
    state->capacity = capacity;
    atomic_init(&state->write_sequence, 0);
    atomic_init(&state->read_sequence, 0);
    atomic_init(&state->accepting, true);
    atomic_init(&state->overflowed, false);
    return state;
}

void sotto_audio_ring_destroy(SottoAudioRingState *state) {
    free(state);
}

int32_t sotto_audio_ring_acquire_write(SottoAudioRingState *state) {
    if (state == NULL ||
        !atomic_load_explicit(&state->accepting, memory_order_acquire)) {
        return -1;
    }

    uint64_t write = atomic_load_explicit(
        &state->write_sequence,
        memory_order_relaxed
    );
    uint64_t read = atomic_load_explicit(
        &state->read_sequence,
        memory_order_acquire
    );
    if (write - read >= state->capacity) {
        sotto_audio_ring_mark_overflow(state);
        return -1;
    }
    return (int32_t)(write % state->capacity);
}

void sotto_audio_ring_commit_write(SottoAudioRingState *state) {
    if (state != NULL) {
        atomic_fetch_add_explicit(
            &state->write_sequence,
            1,
            memory_order_release
        );
    }
}

int32_t sotto_audio_ring_acquire_read(SottoAudioRingState *state) {
    if (state == NULL) {
        return -1;
    }
    uint64_t read = atomic_load_explicit(
        &state->read_sequence,
        memory_order_relaxed
    );
    uint64_t write = atomic_load_explicit(
        &state->write_sequence,
        memory_order_acquire
    );
    if (read >= write) {
        return -1;
    }
    return (int32_t)(read % state->capacity);
}

void sotto_audio_ring_commit_read(SottoAudioRingState *state) {
    if (state != NULL) {
        atomic_fetch_add_explicit(
            &state->read_sequence,
            1,
            memory_order_release
        );
    }
}

void sotto_audio_ring_close(SottoAudioRingState *state) {
    if (state != NULL) {
        atomic_store_explicit(
            &state->accepting,
            false,
            memory_order_release
        );
    }
}

void sotto_audio_ring_mark_overflow(SottoAudioRingState *state) {
    if (state != NULL) {
        atomic_store_explicit(
            &state->overflowed,
            true,
            memory_order_release
        );
        sotto_audio_ring_close(state);
    }
}

bool sotto_audio_ring_is_accepting(const SottoAudioRingState *state) {
    return state != NULL &&
        atomic_load_explicit(&state->accepting, memory_order_acquire);
}

bool sotto_audio_ring_did_overflow(const SottoAudioRingState *state) {
    return state != NULL &&
        atomic_load_explicit(&state->overflowed, memory_order_acquire);
}
