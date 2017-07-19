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
//      Main rendering module
//
//-----------------------------------------------------------------------------

#ifndef r_main_h
#define r_main_h

struct cb_view_t
{
    float x, y, z;
    float angle, pitch;
    float sin, cos;

    float width, height;
    float xcenter, ycenter;

    float xfoc, yfoc, focratio;
    float fov;
    float tan;

    float pspritexscale, pspriteyscale;
    float pspriteystep;

    // Deleted lerp and view sector
};


extern cb_view_t  view;

void R_RenderPlayerView(/*player_t *player, camera_t *viewcamera*/);

#endif /* r_main_h */
