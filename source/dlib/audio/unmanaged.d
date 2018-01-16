/*
Copyright (c) 2016-2017 Timur Gafarov

Boost Software License - Version 1.0 - August 17th, 2003

Permission is hereby granted, free of charge, to any person or organization
obtaining a copy of the software and accompanying documentation covered by
this license (the "Software") to use, reproduce, display, distribute,
execute, and transmit the Software, and to prepare derivative works of the
Software, and to permit third-parties to whom the Software is furnished to
do so, all subject to the following:

The copyright notices in the Software and this entire statement, including
the above license grant, this restriction and the following disclaimer,
must be included in all copies of the Software, in whole or in part, and
all derivative works of the Software, unless such copies or derivative
works are solely in the form of machine-executable object code generated by
a source language processor.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE, TITLE AND NON-INFRINGEMENT. IN NO EVENT
SHALL THE COPYRIGHT HOLDERS OR ANYONE DISTRIBUTING THE SOFTWARE BE LIABLE
FOR ANY DAMAGES OR OTHER LIABILITY, WHETHER IN CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.
*/

module dlib.audio.unmanaged;

import dlib.core.memory;
import dlib.audio.sample;
import dlib.audio.sound;

class UnmanagedGenericSound: GenericSound
{
    this(Sound ras)
    {
        super(ras);
    }

    this(double dur,
         uint freq,
         uint numChannels,
         SampleFormat f)
    {
        super(dur, freq, numChannels, f);
    }

    this(size_t dataSize,
         ulong numSamples,
         double dur,
         uint numChannels,
         uint freq,
         uint bitdepth,
         SampleFormat f)
    {
        super(dataSize, numSamples, dur, numChannels, freq, bitdepth, f);
    }

    protected override void allocateData(size_t size)
    {
        _data = New!(ubyte[])(size);
    }

    override @property Sound dup()
    {
        return New!UnmanagedGenericSound(this);
    }

    override Sound createSameFormat(uint ch, double dur)
    {
        return New!UnmanagedGenericSound(dur, _sampleRate, ch, _format);
    }

    ~this()
    {
        if (_data)
            Delete(_data);
    }
}

class UnmanagedGenericSoundFactory: GenericSoundFactory
{
    UnmanagedGenericSound createSound(
        size_t dataSize,
        ulong numSamples,
        double dur,
        uint numChannels,
        uint freq,
        uint bitdepth,
        SampleFormat f)
    {
        return New!UnmanagedGenericSound(
            dataSize,
            numSamples,
            dur,
            numChannels,
            freq,
            bitdepth,
            f
        );
    }
}
