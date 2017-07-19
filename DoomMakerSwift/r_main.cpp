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
//      Rendering main loop and setup functions,
//       utility functions (BSP, geometry, trigonometry).
//      See tables.c, too.
//
//-----------------------------------------------------------------------------

#include "r_drawq.h"
#include "r_main.h"

cb_view_t view;

// haleyjd 09/04/06: column drawing engines
columndrawer_t *r_column_engine;

static columndrawer_t *r_column_engines[] =
{
    &r_quad_drawer,   // quad cache engine
};


//
// R_SetColumnEngine
//
// Sets r_column_engine to the appropriate set of column drawers.
//
void R_SetColumnEngine()
{
    r_column_engine = r_column_engines[0];
}

//
// R_SetupFrame
//
static void R_SetupFrame()
{
    R_SetColumnEngine();
    // TODO
}

//
// R_RenderPlayerView
//
// Primary renderer entry point.
//
void R_RenderPlayerView()
{
    R_SetupFrame();
    // TODO
}
