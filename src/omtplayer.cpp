#include <iostream>
#include <stdlib.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <vector>

#include <SDL2/SDL.h>
#include "libomt.h"

#ifdef _WIN32
    #define strcasecmp _stricmp
#endif

static void convertP216toYUY2(const OMTMediaFrame* f, std::vector<uint8_t>& out)
{
    const int w = f->Width;
    const int h = f->Height;

    out.resize((size_t)w * h * 2);

    const uint16_t* yPlane  = (const uint16_t*)f->Data;
    const uint16_t* uvPlane = (const uint16_t*)((const uint8_t*)f->Data + ((size_t)w * h * 2));

    for (int y = 0; y < h; ++y)
    {
        const uint16_t* yRow  = yPlane  + (size_t)y * w;
        const uint16_t* uvRow = uvPlane + (size_t)y * w;

        uint8_t* dst = out.data() + (size_t)y * w * 2;

        for (int x = 0; x < w; x += 2)
        {
            uint8_t y0 = (uint8_t)(yRow[x + 0] >> 8);
            uint8_t y1 = (uint8_t)(yRow[x + 1] >> 8);

            uint8_t u  = (uint8_t)(uvRow[x + 0] >> 8);
            uint8_t v  = (uint8_t)(uvRow[x + 1] >> 8);

            *dst++ = y0;
            *dst++ = u;
            *dst++ = y1;
            *dst++ = v;
        }
    }
}

int main(int argc, const char * argv[])
{
    if (argc < 2)
    {
        printf("Usage: omtplayer \"HOST (OMTSOURCE)\"\n");
        return 0;
    }

    std::string filename = "omtplayer.log";
    omt_setloggingfilename(filename.c_str());

    if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO | SDL_INIT_EVENTS) != 0)
    {
        fprintf(stderr, "SDL_Init failed: %s\n", SDL_GetError());
        return 1;
    }

    SDL_Window* window = SDL_CreateWindow(
        "OMT HDMI Player",
        SDL_WINDOWPOS_CENTERED,
        SDL_WINDOWPOS_CENTERED,
        1280,
        720,
        SDL_WINDOW_SHOWN | SDL_WINDOW_FULLSCREEN_DESKTOP
    );

    if (!window)
    {
        fprintf(stderr, "SDL_CreateWindow failed: %s\n", SDL_GetError());
        SDL_Quit();
        return 1;
    }

    SDL_Renderer* renderer = SDL_CreateRenderer(
        window, -1, SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC
    );

    if (!renderer)
    {
        fprintf(stderr, "SDL_CreateRenderer failed: %s\n", SDL_GetError());
        SDL_DestroyWindow(window);
        SDL_Quit();
        return 1;
    }

    SDL_AudioSpec want = {}, got = {};
    want.freq = 48000;
    want.format = AUDIO_F32SYS;
    want.channels = 2;
    want.samples = 1024;
    want.callback = NULL;

    SDL_AudioDeviceID audioDev = SDL_OpenAudioDevice(NULL, 0, &want, &got, 0);
    if (!audioDev)
    {
        fprintf(stderr, "SDL_OpenAudioDevice failed: %s\n", SDL_GetError());
        SDL_DestroyRenderer(renderer);
        SDL_DestroyWindow(window);
        SDL_Quit();
        return 1;
    }

    fprintf(stderr, "Audio opened: freq=%d format=0x%x channels=%d samples=%d\n",
        got.freq, got.format, got.channels, got.samples);

    SDL_PauseAudioDevice(audioDev, 0);

    omt_receive_t* recv = omt_receive_create(
        argv[1],
        (OMTFrameType)(OMTFrameType_Video | OMTFrameType_Audio | OMTFrameType_Metadata),
        (OMTPreferredVideoFormat)OMTPreferredVideoFormat_P216,
        (OMTReceiveFlags)OMTReceiveFlags_None
    );

    if (!recv)
    {
        fprintf(stderr, "omt_receive_create failed\n");
        SDL_CloseAudioDevice(audioDev);
        SDL_DestroyRenderer(renderer);
        SDL_DestroyWindow(window);
        SDL_Quit();
        return 1;
    }

    SDL_Texture* texture = NULL;
    int texW = 0;
    int texH = 0;
    std::vector<uint8_t> yuy2buf;

    bool running = true;

    while (running)
    {
        SDL_Event e;
        while (SDL_PollEvent(&e))
        {
            if (e.type == SDL_QUIT)
                running = false;

            if (e.type == SDL_KEYDOWN && e.key.keysym.sym == SDLK_ESCAPE)
                running = false;
        }

        OMTMediaFrame* f = omt_receive(
            recv,
            (OMTFrameType)(OMTFrameType_Video | OMTFrameType_Audio | OMTFrameType_Metadata),
            40
        );

        if (!f)
            continue;

        if (f->Type == OMTFrameType_Video)
        {
            if (f->Codec != OMTCodec_P216)
                continue;

            if (!texture || texW != f->Width || texH != f->Height)
            {
                if (texture)
                    SDL_DestroyTexture(texture);

                texW = f->Width;
                texH = f->Height;

                texture = SDL_CreateTexture(
                    renderer,
                    SDL_PIXELFORMAT_YUY2,
                    SDL_TEXTUREACCESS_STREAMING,
                    texW,
                    texH
                );

                if (!texture)
                {
                    fprintf(stderr, "SDL_CreateTexture failed: %s\n", SDL_GetError());
                    break;
                }
            }

            convertP216toYUY2(f, yuy2buf);

            if (SDL_UpdateTexture(texture, NULL, yuy2buf.data(), texW * 2) == 0)
            {
                SDL_RenderClear(renderer);
                SDL_RenderCopy(renderer, texture, NULL, NULL);
                SDL_RenderPresent(renderer);
            }
        }
        else if (f->Type == OMTFrameType_Audio)
        {
            if (f->Codec == OMTCodec_FPA1 && f->Data && f->DataLength > 0)
            {
            if (f->Channels == 2)
            {
            const float* src = (const float*)f->Data;
            int samples = f->SamplesPerChannel;

            // FPA1: assumir planar float32 -> converter para interleaved
            static std::vector<float> interleaved;
            interleaved.resize((size_t)samples * 2);

            const float* left  = src;
            const float* right = src + samples;

            for (int i = 0; i < samples; ++i)
            {
                interleaved[(size_t)i * 2 + 0] = left[i];
                interleaved[(size_t)i * 2 + 1] = right[i];
            }

            if (SDL_GetQueuedAudioSize(audioDev) > 48000 * 2 * sizeof(float))
                SDL_ClearQueuedAudio(audioDev);

            SDL_QueueAudio(audioDev, interleaved.data(),
                           (Uint32)(interleaved.size() * sizeof(float)));
        }
    }
}
    }

    if (texture)
        SDL_DestroyTexture(texture);

    omt_receive_destroy(recv);
    SDL_CloseAudioDevice(audioDev);
    SDL_DestroyRenderer(renderer);
    SDL_DestroyWindow(window);
    SDL_Quit();
    return 0;
}
