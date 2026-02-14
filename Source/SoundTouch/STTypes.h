////////////////////////////////////////////////////////////////////////////////
///
/// Common type definitions for SoundTouch audio processing library.
///
/// Author        : Copyright (c) Olli Parviainen
/// Author e-mail : oparviai 'at' iki.fi
/// SoundTouch WWW: http://www.surina.net/soundtouch
///
////////////////////////////////////////////////////////////////////////////////
//
// License :
//
//  SoundTouch audio processing library
//  Copyright (c) Olli Parviainen
//
//  This library is free software; you can redistribute it and/or
//  modify it under the terms of the GNU Lesser General Public
//  License as published by the Free Software Foundation; either
//  version 2.1 of the License, or (at your option) any later version.
//
//  This library is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
//  Lesser General Public License for more details.
//
//  You should have received a copy of the GNU Lesser General Public
//  License along with this library; if not, write to the Free Software
//  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
//
////////////////////////////////////////////////////////////////////////////////

#ifndef STTypes_H
#define STTypes_H

typedef unsigned int uint;
typedef unsigned long ulong;

// Defines for 32-bit floating point sample type
#ifndef SOUNDTOUCH_INTEGER_SAMPLES
#define SOUNDTOUCH_FLOAT_SAMPLES 1
typedef float SAMPLETYPE;
#else
#error "Integer samples not supported in iOS build"
#endif

namespace soundtouch
{
    // In iOS, we use 44.1kHz for most processing
    typedef SAMPLETYPE sample;
}

#endif
