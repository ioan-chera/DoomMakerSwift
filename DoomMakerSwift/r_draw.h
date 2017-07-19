// Emacs style mode select   -*- C++ -*-
//-----------------------------------------------------------------------------
//
// Copyright (C) 2013 James Haley et al.
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see http://www.gnu.org/licenses/
//
//--------------------------------------------------------------------------
//
// DESCRIPTION:
//      System specific interface stuff.
//
//-----------------------------------------------------------------------------

#ifndef r_draw_h
#define r_draw_h

#include "r_basedfs.h"
#include "r_lighting.h"

#define R_ADDRESS(px, py) \
(renderscreen + (viewwindow.y + (py)) * linesize + (viewwindow.x + (px)))

// haleyjd 05/02/13
struct rrect_t
{
    int x;
    int y;
    int width;
    int height;

    void scaledFromScreenBlocks(int blocks);
    void viewFromScaled(int blocks, int vwidth, int vheight,
                        const rrect_t &scaled);
};

extern rrect_t viewwindow;
extern int   linesize;     // killough 11/98
extern byte *renderscreen; // haleyjd 07/02/14

extern byte  *tranmap;       // translucency filter maps 256x256  // phares

// haleyjd 01/22/11: vissprite drawstyles
enum
{
    VS_DRAWSTYLE_NORMAL,  // Normal
    VS_DRAWSTYLE_SHADOW,  // Spectre draw
    VS_DRAWSTYLE_ALPHA,   // Flex translucent
    VS_DRAWSTYLE_ADD,     // Additive flex translucent
    VS_DRAWSTYLE_SUB,     // Static SUBMAP translucent
    VS_DRAWSTYLE_TRANMAP, // Static TRANMAP translucent
    VS_NUMSTYLES
};

//
// columndrawer_t
//
// haleyjd 09/04/06: This structure is used to allow the game engine to use
// multiple sets of column drawing functions (ie., normal, low detail, and
// quad buffer optimized).
//
struct columndrawer_t
{
    void (*DrawColumn)();       // normal
    void (*DrawTLColumn)();     // translucent
    void (*DrawTRColumn)();     // translated
    void (*DrawTLTRColumn)();   // translucent/translated
    void (*DrawFuzzColumn)();   // spectre fuzz
    void (*DrawFlexColumn)();   // flex translucent
    void (*DrawFlexTRColumn)(); // flex translucent/translated
    void (*DrawAddColumn)();    // additive flextran
    void (*DrawAddTRColumn)();  // additive flextran/translated

    void (*ResetBuffer)();      // reset function (may be null)

    void (*ByVisSpriteStyle[VS_NUMSTYLES][2])();
};

// Cardboard
typedef struct cb_column_s
{
    int x, y1, y2;

    fixed_t step;
    int texheight;

    int texmid;

    // 8-bit lighting
    lighttable_t *colormap;
    byte *translation;
    fixed_t translevel; // haleyjd: zdoom style trans level

    void *source;
} cb_column_t;

extern cb_column_t column;

#endif /* r_draw_h */
