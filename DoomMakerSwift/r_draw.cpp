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
//      The actual column drawing functions.
//      Here find the main potential for optimization,
//       e.g. inline assembly, different algorithms.
//
//-----------------------------------------------------------------------------

#include "r_draw.h"

rrect_t viewwindow;   // haleyjd 05/02/13
int   linesize = SCREENWIDTH;  // killough 11/98
byte *renderscreen;            // haleyjd
byte *tranmap;          // translucency filter maps 256x256   // phares
