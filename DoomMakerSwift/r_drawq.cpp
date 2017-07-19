// Emacs style mode select   -*- C++ -*-
//-----------------------------------------------------------------------------
//
// Copyright(C) 2013 James Haley, Stephen McGranahan, et al.
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
//
// Optimized quad column buffer code.
// By SoM.
//
//-----------------------------------------------------------------------------

#include <stdint.h>
#include "r_drawq.h"
#include "r_main.h"

// SoM: OPTIMIZE for ANYRES
typedef enum
{
    COL_NONE,
    COL_OPAQUE,
    COL_TRANS,
    COL_FLEXTRANS,
    COL_FUZZ,
    COL_FLEXADD
} columntype_e;

static int    temp_x = 0;
static int    tempyl[4], tempyh[4];
static int    startx = 0;
static int    temptype = COL_NONE;
static int    commontop, commonbot;
static byte   *tempbuf;
static byte   *temptranmap = NULL;

//
// Do-nothing functions that will just return if R_FlushColumns tries to flush
// columns without a column type.
//

static void R_FlushWholeNil(void)
{
}

static void R_FlushHTNil(void)
{
}

static void R_QuadFlushNil(void)
{
}

//
// R_FlushWholeOpaque
//
// Flushes the entire columns in the buffer, one at a time.
// This is used when a quad flush isn't possible.
// Opaque version -- no remapping whatsoever.
//
static void R_FlushWholeOpaque()
{
    byte *source;
    byte *dest;
    int  count, yl;

    while(--temp_x >= 0)
    {
        yl     = tempyl[temp_x];
        source = tempbuf + temp_x + (yl << 2);
        dest   = R_ADDRESS(startx + temp_x, yl);
        count  = tempyh[temp_x] - yl + 1;

        while(--count >= 0)
        {
            *dest = *source;
            source += 4;
            dest += linesize;
        }
    }
}


static void (*R_FlushWholeColumns)() = R_FlushWholeNil;
static void (*R_FlushHTColumns)()    = R_FlushHTNil;
static void (*R_FlushQuadColumn)(void) = R_QuadFlushNil;

static void R_FlushColumns(void)
{
    if(temp_x != 4 || commontop >= commonbot || temptype == COL_FUZZ)
        R_FlushWholeColumns();
    else
    {
        R_FlushHTColumns();
        R_FlushQuadColumn();
    }
    temp_x = 0;
}

//
// R_FlushHTOpaque
//
// Flushes the head and tail of columns in the buffer in
// preparation for a quad flush.
// Opaque version -- no remapping whatsoever.
//
static void R_FlushHTOpaque(void)
{
    byte *source;
    byte *dest;
    int count, colnum = 0;
    int yl, yh;

    while(colnum < 4)
    {
        yl = tempyl[colnum];
        yh = tempyh[colnum];

        // flush column head
        if(yl < commontop)
        {
            source = tempbuf + colnum + (yl << 2);
            dest   = R_ADDRESS(startx + colnum, yl);
            count  = commontop - yl;

            while(--count >= 0)
            {
                *dest = *source;
                source += 4;
                dest += linesize;
            }
        }

        // flush column tail
        if(yh > commonbot)
        {
            source = tempbuf + colnum + ((commonbot + 1) << 2);
            dest   = R_ADDRESS(startx + colnum, commonbot + 1);
            count  = yh - commonbot;

            while(--count >= 0)
            {
                *dest = *source;
                source += 4;
                dest += linesize;
            }
        }         
        ++colnum;
    }
}

// Begin: Quad column flushing functions.
static void R_FlushQuadOpaque()
{
    int *source = (int *)(tempbuf + (commontop << 2));
    int *dest   = (int *)(R_ADDRESS(startx, commontop));
    int count;
    int deststep = linesize / 4;

    count = commonbot - commontop + 1;

    while(--count >= 0)
    {
        *dest = *source++;
        dest += deststep;
    }
}


// haleyjd 09/12/04: split up R_GetBuffer into various different
// functions to minimize the number of branches and take advantage
// of as much precalculated information as possible.

static byte *R_GetBufferOpaque(void)
{
    // haleyjd: reordered predicates
    if(temp_x == 4 ||
       (temp_x && (temptype != COL_OPAQUE || temp_x + startx != column.x)))
        R_FlushColumns();

    if(!temp_x)
    {
        ++temp_x;
        startx = column.x;
        *tempyl = commontop = column.y1;
        *tempyh = commonbot = column.y2;
        temptype = COL_OPAQUE;
        R_FlushWholeColumns = R_FlushWholeOpaque;
        R_FlushHTColumns    = R_FlushHTOpaque;
        R_FlushQuadColumn   = R_FlushQuadOpaque;
        return tempbuf + (column.y1 << 2);
    }

    tempyl[temp_x] = column.y1;
    tempyh[temp_x] = column.y2;

    if(column.y1 > commontop)
        commontop = column.y1;
    if(column.y2 < commonbot)
        commonbot = column.y2;

    return tempbuf + (column.y1 << 2) + temp_x++;
}


static void R_QDrawColumn()
{
    int      count;
    byte    *dest;            // killough
    fixed_t  frac;            // killough
    fixed_t  fracstep;

    count = column.y2 - column.y1 + 1;

    if(count <= 0)    // Zero length, column does not exceed a pixel.
        return;

    // Framebuffer destination address.
    // SoM: MAGIC
    dest = R_GetBufferOpaque();

    // Determine scaling, which is the only mapping to be done.

    fracstep = column.step;
    frac = column.texmid + (int)((column.y1 - view.ycenter + 1) * fracstep);

    // Inner loop that does the actual texture mapping,
    //  e.g. a DDA-lile scaling.
    // This is as fast as it gets.       (Yeah, right!!! -- killough)
    //
    // killough 2/1/98: more performance tuning

    {
        const byte *source = (const byte *)(column.source);
        const lighttable_t *colormap = column.colormap;
        int heightmask = column.texheight-1;

        if(column.texheight & heightmask)   // not a power of 2 -- killough
        {
            heightmask++;
            heightmask <<= FRACBITS;

            if (frac < 0)
                while ((frac += heightmask) <  0);
            else
                while (frac >= (int)heightmask)
                    frac -= heightmask;

            do
            {
                // Re-map color indices from wall texture column
                //  using a lighting/special effects LUT.

                // heightmask is the Tutti-Frutti fix -- killough

                *dest = colormap[source[frac>>FRACBITS]];
                dest += 4; //SoM: Oh, Oh it's MAGIC! You know...
                if((frac += fracstep) >= (int)heightmask)
                    frac -= heightmask;
            }
            while(--count);
        }
        else
        {
            while((count -= 2) >= 0)   // texture height is a power of 2 -- killough
            {
                *dest = colormap[source[(frac>>FRACBITS) & heightmask]];
                dest += 4; //SoM: MAGIC
                frac += fracstep;
                *dest = colormap[source[(frac>>FRACBITS) & heightmask]];
                dest += 4;
                frac += fracstep;
            }
            if(count & 1)
                *dest = colormap[source[(frac>>FRACBITS) & heightmask]];
        }
    }
}

static void R_FlushWholeTL()
{
    byte *source;
    byte *dest;
    int  count, yl;

    while(--temp_x >= 0)
    {
        yl     = tempyl[temp_x];
        source = tempbuf + temp_x + (yl << 2);
        dest   = R_ADDRESS(startx + temp_x, yl);
        count  = tempyh[temp_x] - yl + 1;

        while(--count >= 0)
        {
            // haleyjd 09/11/04: use temptranmap here
            *dest = temptranmap[(*dest<<8) + *source];
            source += 4;
            dest += linesize;
        }
    }
}

static void R_FlushHTTL()
{
    byte *source;
    byte *dest;
    int count;
    int colnum = 0, yl, yh;

    while(colnum < 4)
    {
        yl = tempyl[colnum];
        yh = tempyh[colnum];

        // flush column head
        if(yl < commontop)
        {
            source = tempbuf + colnum + (yl << 2);
            dest   = R_ADDRESS(startx + colnum, yl);
            count  = commontop - yl;

            while(--count >= 0)
            {
                // haleyjd 09/11/04: use temptranmap here
                *dest = temptranmap[(*dest<<8) + *source];
                source += 4;
                dest += linesize;
            }
        }

        // flush column tail
        if(yh > commonbot)
        {
            source = tempbuf + colnum + ((commonbot + 1) << 2);
            dest   = R_ADDRESS(startx + colnum, commonbot + 1);
            count  = yh - commonbot;

            while(--count >= 0)
            {
                // haleyjd 09/11/04: use temptranmap here
                *dest = temptranmap[(*dest<<8) + *source];
                source += 4;
                dest += linesize;
            }
        }
        
        ++colnum;
    }
}

static void R_FlushQuadTL()
{
    byte *source = tempbuf + (commontop << 2);
    byte *dest   = R_ADDRESS(startx, commontop);
    int count;

    count = commonbot - commontop + 1;

    while(--count >= 0)
    {
        *dest   = temptranmap[(*dest<<8) + *source];
        dest[1] = temptranmap[(dest[1]<<8) + source[1]];
        dest[2] = temptranmap[(dest[2]<<8) + source[2]];
        dest[3] = temptranmap[(dest[3]<<8) + source[3]];
        source += 4;
        dest += linesize;
    }
}


static byte *R_GetBufferTrans(void)
{
    // haleyjd: reordered predicates
    if(temp_x == 4 || tranmap != temptranmap ||
       (temp_x && (temptype != COL_TRANS || temp_x + startx != column.x)))
        R_FlushColumns();

    if(!temp_x)
    {
        ++temp_x;
        startx = column.x;
        *tempyl = commontop = column.y1;
        *tempyh = commonbot = column.y2;
        temptype = COL_TRANS;
        temptranmap = tranmap;
        R_FlushWholeColumns = R_FlushWholeTL;
        R_FlushHTColumns    = R_FlushHTTL;
        R_FlushQuadColumn   = R_FlushQuadTL;
        return tempbuf + (column.y1 << 2);
    }

    tempyl[temp_x] = column.y1;
    tempyh[temp_x] = column.y2;

    if(column.y1 > commontop)
        commontop = column.y1;
    if(column.y2 < commonbot)
        commonbot = column.y2;

    return tempbuf + (column.y1 << 2) + temp_x++;
}

static void R_QDrawTLColumn()
{
    int      count;
    byte    *dest;           // killough
    fixed_t  frac;           // killough
    fixed_t  fracstep;

    count = column.y2 - column.y1 + 1;

    // Zero length, column does not exceed a pixel.
    if(count <= 0)
        return;

#ifdef RANGECHECK
    if(column.x  < 0 || column.x  >= video.width ||
       column.y1 < 0 || column.y2 >= video.height)
        I_Error("R_QDrawTLColumn: %i to %i at %i\n", column.y1, column.y2, column.x);
#endif

    // SoM: MAGIC
    dest = R_GetBufferTrans();

    fracstep = column.step;
    frac = column.texmid + (int)((column.y1 - view.ycenter + 1) * fracstep);

    {
        const byte *source = (const byte *)(column.source);
        const lighttable_t *colormap = column.colormap;
        int heightmask = column.texheight-1;

        if(column.texheight & heightmask)   // not a power of 2 -- killough
        {
            heightmask++;
            heightmask <<= FRACBITS;

            if(frac < 0)
            {
                while((frac += heightmask) <  0);
            }
            else
            {
                while (frac >= (int)heightmask)
                    frac -= heightmask;
            }

            do
            {
                *dest = colormap[source[frac>>FRACBITS]];
                dest += 4; //SoM: Oh, Oh it's MAGIC! You know...
                if((frac += fracstep) >= (int)heightmask)
                    frac -= heightmask;
            }
            while(--count);
        }
        else
        {
            while((count -= 2) >= 0) // texture height is a power of 2 -- killough
            {
                *dest = colormap[source[(frac>>FRACBITS) & heightmask]];
                dest += 4; //SoM: MAGIC
                frac += fracstep;
                *dest = colormap[source[(frac>>FRACBITS) & heightmask]];
                dest += 4;
                frac += fracstep;
            }
            if(count & 1)
                *dest = colormap[source[(frac>>FRACBITS) & heightmask]];
        }
    }
} 


//
// haleyjd 09/04/06: Quad Column Drawer Object
//
columndrawer_t r_quad_drawer =
{
    R_QDrawColumn,
    R_QDrawTLColumn,
    R_QDrawTRColumn,
    R_QDrawTLTRColumn,
    R_QDrawFuzzColumn,
    R_QDrawFlexColumn,
    R_QDrawFlexTRColumn,
    R_QDrawAddColumn,
    R_QDrawAddTRColumn,

    R_QResetColumnBuffer,

    {
        // Normal            Translated
        { R_QDrawColumn,     R_QDrawTRColumn     }, // NORMAL
        { R_QDrawFuzzColumn, R_QDrawFuzzColumn   }, // SHADOW
        { R_QDrawFlexColumn, R_QDrawFlexTRColumn }, // ALPHA
        { R_QDrawAddColumn,  R_QDrawAddTRColumn  }, // ADD
        { R_QDrawTLColumn,   R_QDrawTLTRColumn   }, // SUB
        { R_QDrawTLColumn,   R_QDrawTLTRColumn   }, // TRANMAP
    },
};

// EOF

