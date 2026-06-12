#include <stddef.h>
#include <stdlib.h>
#include <string.h>
#include "wasm_export.h"
#include "KitABI.h"
#include "Zip.h"

void* g_current_zip_archive = NULL;

void set_current_zip_archive(void* archive) {
    g_current_zip_archive = archive;
}

static int wamr_load_asset_from_zip(wasm_exec_env_t e, const char* name, int name_len, char* buf, int buf_size) {
    if (!g_current_zip_archive || !name || name_len <= 0 || !buf || buf_size <= 0) return 0;

    ZipFile* file = zip_fopen(g_current_zip_archive, name);
    if (!file) return 0;

    size_t read = 0;
    while (read < (size_t)buf_size && !zip_feof(file)) {
        size_t chunk = zip_fread(buf + read, (size_t)buf_size - read, file);
        if (chunk == 0) break;
        read += chunk;
    }
    zip_fclose(file);
    return (int)read;
}

static void wamr_gfx_clear(wasm_exec_env_t e, uint32_t a0) { gfx_clear(a0); }
static void wamr_gfx_save(wasm_exec_env_t e) { gfx_save(); }
static void wamr_gfx_restore(wasm_exec_env_t e) { gfx_restore(); }
static void wamr_gfx_translate(wasm_exec_env_t e, float a0, float a1) { gfx_translate(a0, a1); }
static void wamr_gfx_scale(wasm_exec_env_t e, float a0, float a1) { gfx_scale(a0, a1); }
static void wamr_gfx_snap_translation(wasm_exec_env_t e) { gfx_snap_translation(); }
static void wamr_gfx_rotate(wasm_exec_env_t e, float a0) { gfx_rotate(a0); }
static void wamr_gfx_set_alpha(wasm_exec_env_t e, float a0) { gfx_set_alpha(a0); }
static void wamr_gfx_set_blend(wasm_exec_env_t e, int a0) { gfx_set_blend(a0); }
static void wamr_gfx_set_line_style(wasm_exec_env_t e, int join, int cap, float miterLimit) { gfx_set_line_style(join, cap, miterLimit); }
static void wamr_gfx_fill_rect(wasm_exec_env_t e, float a0, float a1, float a2, float a3, uint32_t a4) { gfx_fill_rect(a0, a1, a2, a3, a4); }
static void wamr_gfx_stroke_rect(wasm_exec_env_t e, float a0, float a1, float a2, float a3, float a4, uint32_t a5) { gfx_stroke_rect(a0, a1, a2, a3, a4, a5); }
static void wamr_gfx_fill_circle(wasm_exec_env_t e, float a0, float a1, float a2, uint32_t a3) { gfx_fill_circle(a0, a1, a2, a3); }
static void wamr_gfx_stroke_circle(wasm_exec_env_t e, float a0, float a1, float a2, float a3, uint32_t a4) { gfx_stroke_circle(a0, a1, a2, a3, a4); }
static void wamr_gfx_fill_poly(wasm_exec_env_t e, const float* a0, int a1, uint32_t a2) { gfx_fill_poly(a0, a1, a2); }
static void wamr_gfx_stroke_poly(wasm_exec_env_t e, const float* a0, int a1, int a2, float a3, uint32_t a4) { gfx_stroke_poly(a0, a1, a2, a3, a4); }
static void wamr_gfx_draw_image(wasm_exec_env_t e, int img, float sx, float sy, float sw, float sh, float dx, float dy, float dw, float dh, uint32_t rgba) { gfx_draw_image(img, sx, sy, sw, sh, dx, dy, dw, dh, rgba); }
static int wamr_txt_width(wasm_exec_env_t e, int font, const char* utf8, int len, int sizePx, float spacing) { return txt_width(font, utf8, len, sizePx, spacing); }
static void wamr_gfx_draw_text(wasm_exec_env_t e, int font, const char* utf8, int len, float x, float y, int sizePx, uint32_t rgba, float spacing) { gfx_draw_text(font, utf8, len, x, y, sizePx, rgba, spacing); }
static void wamr_gfx_set_text_baseline(wasm_exec_env_t e, int mode) { gfx_set_text_baseline(mode); }
static int wamr_img_by_name(wasm_exec_env_t e, const char* name, int len) { return img_by_name(name, len); }
static int wamr_img_width(wasm_exec_env_t e, int img) { return img_width(img); }
static int wamr_img_height(wasm_exec_env_t e, int img) { return img_height(img); }
static int wamr_snd_by_name(wasm_exec_env_t e, const char* a0, int a1) { return snd_by_name(a0, a1); }
static int wamr_snd_create_pcm(wasm_exec_env_t e, const float* samples, int frameCount, int sampleRate) { return snd_create_pcm(samples, frameCount, sampleRate); }
static int wamr_font_by_name(wasm_exec_env_t e, const char* name, int len) { return font_by_name(name, len); }
static int wamr_snd_play(wasm_exec_env_t e, int a0, float a1, int a2) { return snd_play(a0, a1, a2); }
static void wamr_snd_stop(wasm_exec_env_t e, int a0) { snd_stop(a0); }
static void wamr_snd_set_volume(wasm_exec_env_t e, int a0, float a1) { snd_set_volume(a0, a1); }
static int wamr_snd_status(wasm_exec_env_t e, int voice) { return snd_status(voice); }
static void wamr_snd_pause_all(wasm_exec_env_t e) { snd_pause_all(); }
static void wamr_snd_resume_all(wasm_exec_env_t e) { snd_resume_all(); }
static int wamr_gp_connected(wasm_exec_env_t e, int a0) { return gp_connected(a0); }
static int wamr_gp_button(wasm_exec_env_t e, int pad, int button) { return gp_button(pad, button); }
static float wamr_gp_button_value(wasm_exec_env_t e, int pad, int button) { return gp_button_value(pad, button); }
static float wamr_gp_axis(wasm_exec_env_t e, int pad, int axis) { return gp_axis(pad, axis); }
static void wamr_gp_map_to_keys(wasm_exec_env_t e, int enable) { gp_map_to_keys(enable); }
static int wamr_tts_speak(wasm_exec_env_t e, const char* utf8, int len, float rate, float pitch, float volume) { return tts_speak(utf8, len, rate, pitch, volume); }
static void wamr_tts_cancel(wasm_exec_env_t e) { tts_cancel(); }
static void wamr_tts_set_preferred_voices(wasm_exec_env_t e, const char* csv, int len) { tts_set_preferred_voices(csv, len); }
static void wamr_tts_set_robotic_voices(wasm_exec_env_t e, const char* csv, int len) { tts_set_robotic_voices(csv, len); }
static void wamr_tts_set_female_voices(wasm_exec_env_t e, const char* csv, int len) { tts_set_female_voices(csv, len); }
static int wamr_gfx_offscreen_begin(wasm_exec_env_t e, int w, int h) { return gfx_offscreen_begin(w, h); }
static int wamr_gfx_offscreen_end_to_image(wasm_exec_env_t e, int handle) { return gfx_offscreen_end_to_image(handle); }
static void wamr_gfx_offscreen_end_discard(wasm_exec_env_t e, int handle) { gfx_offscreen_end_discard(handle); }
static void wamr_gfx_free_image(wasm_exec_env_t e, int img) { gfx_free_image(img); }
static void wamr_gfx_draw_shadow_image(wasm_exec_env_t e, int img, float x, float y, float w, float h, float blur, uint32_t rgba) { gfx_draw_shadow_image(img, x, y, w, h, blur, rgba); }
static void wamr_gfx_set_filter(wasm_exec_env_t e, const char* utf8, int len) { gfx_set_filter(utf8, len); }
static void wamr_gfx_clear_filter(wasm_exec_env_t e) { gfx_clear_filter(); }
static void wamr_gfx_set_shadow(wasm_exec_env_t e, float blurRadius, float dx, float dy, uint32_t rgba) { gfx_set_shadow(blurRadius, dx, dy, rgba); }
static void wamr_gfx_clear_shadow(wasm_exec_env_t e) { gfx_clear_shadow(); }
static void wamr_gfx_set_composite(wasm_exec_env_t e, int mode) { gfx_set_composite(mode); }
static int stub_vid_load(wasm_exec_env_t e, const char* name, int len) { return 0; }
static void stub_vid_play(wasm_exec_env_t e, int id) {}
static void stub_vid_pause(wasm_exec_env_t e, int id) {}
static void stub_vid_stop(wasm_exec_env_t e, int id) {}
static void stub_vid_set_rect(wasm_exec_env_t e, int id, float x, float y, float w, float h) {}
static void stub_vid_set_visible(wasm_exec_env_t e, int id, int visible) {}
static void wamr_snd_set_pan(wasm_exec_env_t e, int a0, float a1) { snd_set_pan(a0, a1); }
static void wamr_snd_set_rate(wasm_exec_env_t e, int voice, float rate) { snd_set_rate(voice, rate); }
static int wamr_eng_player_create(wasm_exec_env_t e) { return eng_player_create(); }
static void wamr_eng_player_release(wasm_exec_env_t e, int id) { eng_player_release(id); }
static int wamr_eng_mixer_create(wasm_exec_env_t e) { return eng_mixer_create(); }
static void wamr_eng_node_set_volume(wasm_exec_env_t e, int id, float v) { eng_node_set_volume(id, v); }
static void wamr_eng_node_set_pan(wasm_exec_env_t e, int id, float p) { eng_node_set_pan(id, p); }
static void wamr_eng_connect(wasm_exec_env_t e, int src, int dst) { eng_connect(src, dst); }
static int wamr_eng_player_schedule_buffer(wasm_exec_env_t e, int player, int sound, int loops) { return eng_player_schedule_buffer(player, sound, loops); }
static void wamr_eng_player_play(wasm_exec_env_t e, int id) { eng_player_play(id); }
static void wamr_eng_player_stop(wasm_exec_env_t e, int id) { eng_player_stop(id); }
static void wamr_eng_start(wasm_exec_env_t e) { eng_start(); }
static void wamr_eng_stop(wasm_exec_env_t e) { eng_stop(); }
static int stub_gfx_shader_compile(wasm_exec_env_t e, const char* src, int len) { return 0; }
static void stub_gfx_shader_release(wasm_exec_env_t e, int shader) {}
static void stub_gfx_shader_set_uniform_f(wasm_exec_env_t e, int shader, const char* name, int nlen, float v) {}
static void stub_gfx_shader_set_uniform_v2(wasm_exec_env_t e, int shader, const char* name, int nlen, float x, float y) {}
static void stub_gfx_shader_set_uniform_v3(wasm_exec_env_t e, int shader, const char* name, int nlen, float x, float y, float z) {}
static void stub_gfx_shader_set_uniform_v4(wasm_exec_env_t e, int shader, const char* name, int nlen, float x, float y, float z, float w) {}
static void stub_gfx_shader_set_uniform_t(wasm_exec_env_t e, int shader, const char* name, int nlen, int img) {}
static void stub_gfx_shader_draw(wasm_exec_env_t e, int shader, int srcImg, float dstX, float dstY, float dstW, float dstH, float time, uint32_t colorRgba) {}
static void stub_gfx_lighting_draw(wasm_exec_env_t e, int srcImg, int normalImg, const float* lights, int lightCount, float dstX, float dstY, float dstW, float dstH, uint32_t colorRgba) {}
static void wamr_gfx_warp_draw(wasm_exec_env_t e, int srcImg, int cols, int rows, const float* srcUV, const float* dstXY, float dstX, float dstY, float dstW, float dstH, uint32_t colorRgba) { gfx_warp_draw(srcImg, cols, rows, srcUV, dstXY, dstX, dstY, dstW, dstH, colorRgba); }
static void wamr_gfx_3d_draw_billboard(wasm_exec_env_t e, int srcImg, float camX, float camY, float camZ, float dstX, float dstY, float dstW, float dstH, uint32_t colorRgba) { gfx_3d_draw_billboard(srcImg, camX, camY, camZ, dstX, dstY, dstW, dstH, colorRgba); }
static int wamr_gfx_upload_pixels(wasm_exec_env_t e, int img, int w, int h, const uint8_t* rgba, int len) { return gfx_upload_pixels(img, w, h, rgba, len); }
static int wamr_store_get(wasm_exec_env_t e, const char* a0, int a1, char* a2, int a3) { return store_get(a0, a1, a2, a3); }
static void wamr_store_set(wasm_exec_env_t e, const char* a0, int a1, const char* a2, int a3) { store_set(a0, a1, a2, a3); }
static int wamr_asset_exists(wasm_exec_env_t e, const char* name, int len) { return asset_exists(name, len); }
static int wamr_asset_text(wasm_exec_env_t e, const char* name, int len, char* buf, int cap) { return asset_text(name, len, buf, cap); }
static int stub_img_polygon_from_alpha(wasm_exec_env_t e, int img, float alphaThreshold, float* out_xy, int cap) { return 0; }
static int wamr_key_pressed(wasm_exec_env_t e, int sfKey) { return key_pressed(sfKey); }
static int wamr_mouse_x(wasm_exec_env_t e) { return mouse_x(); }
static int wamr_mouse_y(wasm_exec_env_t e) { return mouse_y(); }
static int wamr_mouse_button(wasm_exec_env_t e, int b) { return mouse_button(b); }
static int wamr_evt_poll(wasm_exec_env_t e, int* a0, int* a1, int* a2, int* a3, int* a4) { return evt_poll(a0, a1, a2, a3, a4); }
static int wamr_win_width(wasm_exec_env_t e) { return win_width(); }
static int wamr_win_height(wasm_exec_env_t e) { return win_height(); }
static void wamr_win_set_title(wasm_exec_env_t e, const char* s, int len) { win_set_title(s, len); }
static void wamr_win_request_fullscreen(wasm_exec_env_t e) { win_request_fullscreen(); }
static void wamr_win_exit_fullscreen(wasm_exec_env_t e) { win_exit_fullscreen(); }
static void wamr_win_download(wasm_exec_env_t e, const char* name, int nlen, const char* data, int dlen) { win_download(name, nlen, data, dlen); }

NativeSymbol kit_natives[] = {
    { "gfx_clear", (void *)wamr_gfx_clear, "(i)", NULL },
    { "gfx_save", (void *)wamr_gfx_save, "()", NULL },
    { "gfx_restore", (void *)wamr_gfx_restore, "()", NULL },
    { "gfx_translate", (void *)wamr_gfx_translate, "(ff)", NULL },
    { "gfx_scale", (void *)wamr_gfx_scale, "(ff)", NULL },
    { "gfx_snap_translation", (void *)wamr_gfx_snap_translation, "()", NULL },
    { "gfx_rotate", (void *)wamr_gfx_rotate, "(f)", NULL },
    { "gfx_set_alpha", (void *)wamr_gfx_set_alpha, "(f)", NULL },
    { "gfx_set_blend", (void *)wamr_gfx_set_blend, "(i)", NULL },
    { "gfx_set_line_style", (void *)wamr_gfx_set_line_style, "(iif)", NULL },
    { "gfx_fill_rect", (void *)wamr_gfx_fill_rect, "(ffffi)", NULL },
    { "gfx_stroke_rect", (void *)wamr_gfx_stroke_rect, "(fffffi)", NULL },
    { "gfx_fill_circle", (void *)wamr_gfx_fill_circle, "(fffi)", NULL },
    { "gfx_stroke_circle", (void *)wamr_gfx_stroke_circle, "(ffffi)", NULL },
    { "gfx_fill_poly", (void *)wamr_gfx_fill_poly, "(*~i)", NULL },
    { "gfx_stroke_poly", (void *)wamr_gfx_stroke_poly, "(*~ifi)", NULL },
    { "gfx_draw_image", (void *)wamr_gfx_draw_image, "(iffffffffi)", NULL },
    { "txt_width", (void *)wamr_txt_width, "(i*~if)i", NULL },
    { "gfx_draw_text", (void *)wamr_gfx_draw_text, "(i*~ffiif)", NULL },
    { "gfx_set_text_baseline", (void *)wamr_gfx_set_text_baseline, "(i)", NULL },
    { "img_by_name", (void *)wamr_img_by_name, "(*~)i", NULL },
    { "img_width", (void *)wamr_img_width, "(i)i", NULL },
    { "img_height", (void *)wamr_img_height, "(i)i", NULL },
    { "snd_by_name", (void *)wamr_snd_by_name, "(*~)i", NULL },
    { "snd_create_pcm", (void *)wamr_snd_create_pcm, "(*~i)i", NULL },
    { "font_by_name", (void *)wamr_font_by_name, "(*~)i", NULL },
    { "snd_play", (void *)wamr_snd_play, "(ifi)i", NULL },
    { "snd_stop", (void *)wamr_snd_stop, "(i)", NULL },
    { "snd_set_volume", (void *)wamr_snd_set_volume, "(if)", NULL },
    { "snd_status", (void *)wamr_snd_status, "(i)i", NULL },
    { "snd_pause_all", (void *)wamr_snd_pause_all, "()", NULL },
    { "snd_resume_all", (void *)wamr_snd_resume_all, "()", NULL },
    { "gp_connected", (void *)wamr_gp_connected, "(i)i", NULL },
    { "gp_button", (void *)wamr_gp_button, "(ii)i", NULL },
    { "gp_button_value", (void *)wamr_gp_button_value, "(ii)f", NULL },
    { "gp_axis", (void *)wamr_gp_axis, "(ii)f", NULL },
    { "gp_map_to_keys", (void *)wamr_gp_map_to_keys, "(i)", NULL },
    { "tts_speak", (void *)wamr_tts_speak, "(*~fff)i", NULL },
    { "tts_cancel", (void *)wamr_tts_cancel, "()", NULL },
    { "tts_set_preferred_voices", (void *)wamr_tts_set_preferred_voices, "(*~)", NULL },
    { "tts_set_robotic_voices", (void *)wamr_tts_set_robotic_voices, "(*~)", NULL },
    { "tts_set_female_voices", (void *)wamr_tts_set_female_voices, "(*~)", NULL },
    { "gfx_offscreen_begin", (void *)wamr_gfx_offscreen_begin, "(ii)i", NULL },
    { "gfx_offscreen_end_to_image", (void *)wamr_gfx_offscreen_end_to_image, "(i)i", NULL },
    { "gfx_offscreen_end_discard", (void *)wamr_gfx_offscreen_end_discard, "(i)", NULL },
    { "gfx_free_image", (void *)wamr_gfx_free_image, "(i)", NULL },
    { "gfx_draw_shadow_image", (void *)wamr_gfx_draw_shadow_image, "(ifffffi)", NULL },
    { "gfx_set_filter", (void *)wamr_gfx_set_filter, "(*~)", NULL },
    { "gfx_clear_filter", (void *)wamr_gfx_clear_filter, "()", NULL },
    { "gfx_set_shadow", (void *)wamr_gfx_set_shadow, "(fffi)", NULL },
    { "gfx_clear_shadow", (void *)wamr_gfx_clear_shadow, "()", NULL },
    { "gfx_set_composite", (void *)wamr_gfx_set_composite, "(i)", NULL },
    { "vid_load", (void *)stub_vid_load, "(*~)i", NULL },
    { "vid_play", (void *)stub_vid_play, "(i)", NULL },
    { "vid_pause", (void *)stub_vid_pause, "(i)", NULL },
    { "vid_stop", (void *)stub_vid_stop, "(i)", NULL },
    { "vid_set_rect", (void *)stub_vid_set_rect, "(iffff)", NULL },
    { "vid_set_visible", (void *)stub_vid_set_visible, "(ii)", NULL },
    { "snd_set_pan", (void *)wamr_snd_set_pan, "(if)", NULL },
    { "snd_set_rate", (void *)wamr_snd_set_rate, "(if)", NULL },
    { "eng_player_create", (void *)wamr_eng_player_create, "()i", NULL },
    { "eng_player_release", (void *)wamr_eng_player_release, "(i)", NULL },
    { "eng_mixer_create", (void *)wamr_eng_mixer_create, "()i", NULL },
    { "eng_node_set_volume", (void *)wamr_eng_node_set_volume, "(if)", NULL },
    { "eng_node_set_pan", (void *)wamr_eng_node_set_pan, "(if)", NULL },
    { "eng_connect", (void *)wamr_eng_connect, "(ii)", NULL },
    { "eng_player_schedule_buffer", (void *)wamr_eng_player_schedule_buffer, "(iii)i", NULL },
    { "eng_player_play", (void *)wamr_eng_player_play, "(i)", NULL },
    { "eng_player_stop", (void *)wamr_eng_player_stop, "(i)", NULL },
    { "eng_start", (void *)wamr_eng_start, "()", NULL },
    { "eng_stop", (void *)wamr_eng_stop, "()", NULL },
    { "gfx_shader_compile", (void *)stub_gfx_shader_compile, "(*~)i", NULL },
    { "gfx_shader_release", (void *)stub_gfx_shader_release, "(i)", NULL },
    { "gfx_shader_set_uniform_f", (void *)stub_gfx_shader_set_uniform_f, "(i*~f)", NULL },
    { "gfx_shader_set_uniform_v2", (void *)stub_gfx_shader_set_uniform_v2, "(i*~ff)", NULL },
    { "gfx_shader_set_uniform_v3", (void *)stub_gfx_shader_set_uniform_v3, "(i*~fff)", NULL },
    { "gfx_shader_set_uniform_v4", (void *)stub_gfx_shader_set_uniform_v4, "(i*~ffff)", NULL },
    { "gfx_shader_set_uniform_t", (void *)stub_gfx_shader_set_uniform_t, "(i*~i)", NULL },
    { "gfx_shader_draw", (void *)stub_gfx_shader_draw, "(iifffffi)", NULL },
    { "gfx_lighting_draw", (void *)stub_gfx_lighting_draw, "(ii*~ffffi)", NULL },
    { "gfx_warp_draw", (void *)wamr_gfx_warp_draw, "(iii**ffffi)", NULL },
    { "gfx_3d_draw_billboard", (void *)wamr_gfx_3d_draw_billboard, "(ifffffffi)", NULL },
    { "gfx_upload_pixels", (void *)wamr_gfx_upload_pixels, "(iii*~)i", NULL },
    { "store_get", (void *)wamr_store_get, "(*~*~)i", NULL },
    { "store_set", (void *)wamr_store_set, "(*~*~)", NULL },
    { "asset_exists", (void *)wamr_asset_exists, "(*~)i", NULL },
    { "asset_text", (void *)wamr_asset_text, "(*~*~)i", NULL },
    { "img_polygon_from_alpha", (void *)stub_img_polygon_from_alpha, "(if*~)i", NULL },
    { "key_pressed", (void *)wamr_key_pressed, "(i)i", NULL },
    { "mouse_x", (void *)wamr_mouse_x, "()i", NULL },
    { "mouse_y", (void *)wamr_mouse_y, "()i", NULL },
    { "mouse_button", (void *)wamr_mouse_button, "(i)i", NULL },
    { "evt_poll", (void *)wamr_evt_poll, "(*****)i", NULL },
    { "win_width", (void *)wamr_win_width, "()i", NULL },
    { "win_height", (void *)wamr_win_height, "()i", NULL },
    { "win_set_title", (void *)wamr_win_set_title, "(*~)", NULL },
    { "win_request_fullscreen", (void *)wamr_win_request_fullscreen, "()", NULL },
    { "win_exit_fullscreen", (void *)wamr_win_exit_fullscreen, "()", NULL },
    { "win_download", (void *)wamr_win_download, "(*~*~)", NULL },
    { "load_asset_from_zip", (void *)wamr_load_asset_from_zip, "(*~*~)i", NULL },
};
int kit_natives_count = 100;

bool kit_register_natives(void) {
    return wasm_runtime_register_natives("env", kit_natives, (uint32_t)kit_natives_count);
}
