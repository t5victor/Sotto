#ifndef SOTTO_AUDIO_RING_C_H
#define SOTTO_AUDIO_RING_C_H

#include <stdbool.h>
#include <stdint.h>

typedef struct SottoAudioRingState SottoAudioRingState;

SottoAudioRingState *sotto_audio_ring_create(uint32_t capacity);
void sotto_audio_ring_destroy(SottoAudioRingState *state);

int32_t sotto_audio_ring_acquire_write(SottoAudioRingState *state);
void sotto_audio_ring_commit_write(SottoAudioRingState *state);
int32_t sotto_audio_ring_acquire_read(SottoAudioRingState *state);
void sotto_audio_ring_commit_read(SottoAudioRingState *state);

void sotto_audio_ring_close(SottoAudioRingState *state);
void sotto_audio_ring_mark_overflow(SottoAudioRingState *state);
bool sotto_audio_ring_is_accepting(const SottoAudioRingState *state);
bool sotto_audio_ring_did_overflow(const SottoAudioRingState *state);

#endif
