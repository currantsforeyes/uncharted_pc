/* Stubs for the entry points the HLE runtime calls into the GPU library, so the
 * C tests can link the runtime on its own. The real implementations are in
 * gpu/shim/bbgpu.cpp (see gpu/bbbgpu.h for the signatures); probe.c links them.
 *
 * Tests that link runtime_pad.c need these; the ones that do not simply ignore
 * them. test_pad.c drives the capture flag below rather than redefining the
 * function, so the same stub file works for every test.
 *
 * Not part of the shipped binary. */
#include "../src/runtime.h"
#include <stdio.h>
#include <stdlib.h>

int bbgpu_test_capture_input = 0;

uintptr_t bbgpu_resolve(const char *name) { (void)name; return 0; }
void bbgpu_report(void) {}

int bbgpu_overlay_captures_input(void) { return bbgpu_test_capture_input; }

void bbgpu_mouse_configure(int look) { (void)look; }
int bbgpu_camera_yaw(float *yaw_degrees, double *age_seconds) {
    (void)yaw_degrees;
    (void)age_seconds;
    return 0; /* no running game, so no camera */
}
int bbgpu_mouse_sample(float *dx, float *dy, uint32_t *buttons, int *wheel) {
    if (dx) *dx = 0.0f;
    if (dy) *dy = 0.0f;
    if (buttons) *buttons = 0;
    if (wheel) *wheel = 0;
    return 0;
}

/* No dialog is available, so text entry reports a cancellation, which is what
 * runtime_services.c expects when the overlay cannot show one. */
int bbgpu_text_input_begin(const char *initial_utf8, const char *prompt_utf8) {
    (void)initial_utf8;
    (void)prompt_utf8;
    return -1;
}
int bbgpu_text_input_poll(char *out_utf8, uint64_t size) {
    (void)out_utf8;
    (void)size;
    return -1;
}
/* The game hooks and the pad capture report which controller the player uses (runtime_pad.c);
 * no GPU library is linked here. */
void bbgpu_prompts_controller(int device) { (void)device; }

/* runtime_quit lives in probe.c, which the tests do not link. Weak, so the real one wins where
 * the loader is linked (and a test that reaches it stops loudly instead of running on). */
__attribute__((weak, noreturn)) void runtime_quit(int code) {
    fprintf(stderr, "STOP: runtime_quit(%d) in a test\n", code);
    abort();
}

/* Trophy notices go to the overlay in the real build. */
void bbgpu_trophy_notify(int grade, const char *game, const char *name, const void *png, uint64_t size) {
    (void)grade; (void)game; (void)name; (void)png; (void)size;
}
