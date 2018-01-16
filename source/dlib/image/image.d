/*
Copyright (c) 2011-2017 Timur Gafarov

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

module dlib.image.image;

private
{
    import std.math;
    import std.conv;
    import dlib.core.memory;
    import dlib.functional.range;
    import dlib.math.vector;
    import dlib.math.interpolation;
    import dlib.image.color;
}

enum PixelFormat
{
    L8,
    LA8,
    RGB8,
    RGBA8,
    L16,
    LA16,
    RGB16,
    RGBA16,
    RGBA_FLOAT
}

interface SuperImage: Freeable
{
    @property uint width();
    @property uint height();
    @property uint bitDepth();
    @property uint channels();
    @property uint pixelSize();
    @property PixelFormat pixelFormat();
    @property ubyte[] data();

    @property SuperImage dup();

    Color4f opIndex(int x, int y);
    Color4f opIndexAssign(Color4f c, int x, int y);

    SuperImage createSameFormat(uint w, uint h);

    final @property auto row()
    {
        return range!uint(0, width);
    }

    final @property auto col()
    {
        return range!uint(0, height);
    }

    //float pixelCost = 0.0f;
    //shared float progress = 0.0f;
/*
    final void updateProgress()
    {
        progress = progress + pixelCost;
    }

    final void resetProgress()
    {
        progress = 0.0f;
    }
*/
    final int opApply(scope int delegate(ref Color4f p, uint x, uint y) dg)
    {
        int result = 0;

        foreach(uint y; col)
        {
            foreach(uint x; row)
            {
                Color4f col = opIndex(x, y);
                result = dg(col, x, y);
                opIndexAssign(col, x, y);

                if (result)
                    break;
            }

            if (result)
                break;
        }

        return result;
    }
}

class Image(PixelFormat fmt): SuperImage
{
    public:

    override @property uint width()
    {
        return _width;
    }

    override @property uint height()
    {
        return _height;
    }

    override @property uint bitDepth()
    {
        return _bitDepth;
    }

    override @property uint channels()
    {
        return _channels;
    }

    override @property uint pixelSize()
    {
        return _pixelSize;
    }

    override @property PixelFormat pixelFormat()
    {
        return fmt;
    }

    override @property ubyte[] data()
    {
        return _data;
    }

    override @property SuperImage dup()
    {
        auto res = new Image!(fmt)(_width, _height);
        res.data[] = data[];
        return res;
    }

    override SuperImage createSameFormat(uint w, uint h)
    {
        return new Image!(fmt)(w, h);
    }

    this(uint w, uint h)
    {
        _width = w;
        _height = h;

        _bitDepth = [
            PixelFormat.L8:     8, PixelFormat.LA8:     8,
            PixelFormat.RGB8:   8, PixelFormat.RGBA8:   8,
            PixelFormat.L16:   16, PixelFormat.LA16:   16,
            PixelFormat.RGB16: 16, PixelFormat.RGBA16: 16
        ][fmt];

        _channels = [
            PixelFormat.L8:    1, PixelFormat.LA8:    2,
            PixelFormat.RGB8:  3, PixelFormat.RGBA8:  4,
            PixelFormat.L16:   1, PixelFormat.LA16:   2,
            PixelFormat.RGB16: 3, PixelFormat.RGBA16: 4
        ][fmt];

        _pixelSize = (_bitDepth / 8) * _channels;
        allocateData();

        //pixelCost = 1.0f / (_width * _height);
        //progress = 0.0f;
    }

    protected void allocateData()
    {
        _data = new ubyte[_width * _height * _pixelSize];
    }

    public Color4 getPixel(int x, int y)
    {
        ubyte[] pixData = data();

        if (x >= width) x = width-1;
        else if (x < 0) x = 0;

        if (y >= height) y = height-1;
        else if (y < 0) y = 0;

        auto index = (y * _width + x) * _pixelSize;

        auto maxv = (2 ^^ bitDepth) - 1;

        static if (fmt == PixelFormat.L8)
        {
            auto v = pixData[index];
            return Color4(v, v, v);
        }
        else if (fmt == PixelFormat.LA8)
        {
            auto v = pixData[index];
            return Color4(v, v, v, pixData[index+1]);
        }
        else if (fmt == PixelFormat.RGB8)
        {
            return Color4(pixData[index], pixData[index+1], pixData[index+2], cast(ubyte)maxv);
        }
        else if (fmt == PixelFormat.RGBA8)
        {
            return Color4(pixData[index], pixData[index+1], pixData[index+2], pixData[index+3]);
        }
        else if (fmt == PixelFormat.L16)
        {
            ushort v = pixData[index] << 8 | pixData[index+1];
            return Color4(v, v, v);
        }
        else if (fmt == PixelFormat.LA16)
        {
            ushort v = pixData[index]   << 8 | pixData[index+1];
            ushort a = pixData[index+2] << 8 | pixData[index+3];
            return Color4(v, v, v, a);
        }
        else if (fmt == PixelFormat.RGB16)
        {
            ushort r = pixData[index]   << 8 | pixData[index+1];
            ushort g = pixData[index+2] << 8 | pixData[index+3];
            ushort b = pixData[index+4] << 8 | pixData[index+5];
            ushort a = cast(ushort)maxv;
            return Color4(r, g, b, a);
        }
        else if (fmt == PixelFormat.RGBA16)
        {
            ushort r = pixData[index]   << 8 | pixData[index+1];
            ushort g = pixData[index+2] << 8 | pixData[index+3];
            ushort b = pixData[index+4] << 8 | pixData[index+5];
            ushort a = pixData[index+6] << 8 | pixData[index+7];
            return Color4(r, g, b, a);
        }
        else
        {
            assert (0, "Image.opIndex is not implemented for PixelFormat." ~ to!string(fmt));
        }
    }

    public Color4 setPixel(Color4 c, int x, int y)
    {
        ubyte[] pixData = data();

        if(x >= width || y >= height || x < 0 || y < 0)
            return c;

        size_t index = (y * _width + x) * _pixelSize;

        static if (fmt == PixelFormat.L8)
        {
            pixData[index] = cast(ubyte)c.r;
        }
        else if (fmt == PixelFormat.LA8)
        {
            pixData[index] = cast(ubyte)c.r;
            pixData[index+1] = cast(ubyte)c.a;
        }
        else if (fmt == PixelFormat.RGB8)
        {
            pixData[index] = cast(ubyte)c.r;
            pixData[index+1] = cast(ubyte)c.g;
            pixData[index+2] = cast(ubyte)c.b;
        }
        else if (fmt == PixelFormat.RGBA8)
        {
            pixData[index] = cast(ubyte)c.r;
            pixData[index+1] = cast(ubyte)c.g;
            pixData[index+2] = cast(ubyte)c.b;
            pixData[index+3] = cast(ubyte)c.a;
        }
        else if (fmt == PixelFormat.L16)
        {
            pixData[index] = cast(ubyte)(c.r >> 8);
            pixData[index+1] = cast(ubyte)(c.r & 0xFF);
        }
        else if (fmt == PixelFormat.LA16)
        {
            pixData[index] = cast(ubyte)(c.r >> 8);
            pixData[index+1] = cast(ubyte)(c.r & 0xFF);
            pixData[index+2] = cast(ubyte)(c.a >> 8);
            pixData[index+3] = cast(ubyte)(c.a & 0xFF);
        }
        else if (fmt == PixelFormat.RGB16)
        {
            pixData[index] = cast(ubyte)(c.r >> 8);
            pixData[index+1] = cast(ubyte)(c.r & 0xFF);
            pixData[index+2] = cast(ubyte)(c.g >> 8);
            pixData[index+3] = cast(ubyte)(c.g & 0xFF);
            pixData[index+4] = cast(ubyte)(c.b >> 8);
            pixData[index+5] = cast(ubyte)(c.b & 0xFF);
        }
        else if (fmt == PixelFormat.RGBA16)
        {
            pixData[index] = cast(ubyte)(c.r >> 8);
            pixData[index+1] = cast(ubyte)(c.r & 0xFF);
            pixData[index+2] = cast(ubyte)(c.g >> 8);
            pixData[index+3] = cast(ubyte)(c.g & 0xFF);
            pixData[index+4] = cast(ubyte)(c.b >> 8);
            pixData[index+5] = cast(ubyte)(c.b & 0xFF);
            pixData[index+6] = cast(ubyte)(c.a >> 8);
            pixData[index+7] = cast(ubyte)(c.a & 0xFF);
        }
        else
        {
            assert (0, "Image.opIndexAssign is not implemented for PixelFormat." ~ to!string(fmt));
        }

        return c;
    }

    override Color4f opIndex(int x, int y)
    {
        return Color4f(getPixel(x, y), _bitDepth);
    }

    override Color4f opIndexAssign(Color4f c, int x, int y)
    {
        setPixel(c.convert(_bitDepth), x, y);
        return c;
    }

    void free()
    {
        // Do nothing, let GC delete the object
    }

    protected:

    uint _width;
    uint _height;
    uint _bitDepth;
    uint _channels;
    uint _pixelSize;
    ubyte[] _data;
}

alias Image!(PixelFormat.L8) ImageL8;
alias Image!(PixelFormat.LA8) ImageLA8;
alias Image!(PixelFormat.RGB8) ImageRGB8;
alias Image!(PixelFormat.RGBA8) ImageRGBA8;

alias Image!(PixelFormat.L16) ImageL16;
alias Image!(PixelFormat.LA16) ImageLA16;
alias Image!(PixelFormat.RGB16) ImageRGB16;
alias Image!(PixelFormat.RGBA16) ImageRGBA16;

/*
 * All-in-one image factory
 */
interface SuperImageFactory
{
    SuperImage createImage(uint w, uint h, uint channels, uint bitDepth, uint numFrames = 1);
}

class ImageFactory: SuperImageFactory
{
    SuperImage createImage(uint w, uint h, uint channels, uint bitDepth, uint numFrames = 1)
    {
        return image(w, h, channels, bitDepth);
    }
}

private SuperImageFactory _defaultImageFactory;

SuperImageFactory defaultImageFactory()
{
    if (!_defaultImageFactory)
        _defaultImageFactory = new ImageFactory();
    return _defaultImageFactory;
}

SuperImage image(uint w, uint h, uint channels = 3, uint bitDepth = 8)
in
{
    assert(channels > 0 && channels <= 4);
    assert(bitDepth == 8 || bitDepth == 16);
}
body
{
    switch(channels)
    {
        case 1:
        {
            if (bitDepth == 8)
                return new ImageL8(w, h);
            else
                return new ImageL16(w, h);
        }
        case 2:
        {
            if (bitDepth == 8)
                return new ImageLA8(w, h);
            else
                return new ImageLA16(w, h);
        }
        case 3:
        {
            if (bitDepth == 8)
                return new ImageRGB8(w, h);
            else
                return new ImageRGB16(w, h);
        }
        case 4:
        {
            if (bitDepth == 8)
                return new ImageRGBA8(w, h);
            else
                return new ImageRGBA16(w, h);
        }
        default:
            assert(0);
    }
}

/*
 * Convert image to specified pixel format
 */
T convert(T)(SuperImage img)
{
    auto res = new T(img.width, img.height);
    foreach(x; 0..img.width)
    foreach(y; 0..img.height)
        res[x, y] = img[x, y];
    return res;
}

/*
 * Get interpolated pixel value from an image
 */
Color4f bilinearPixel(SuperImage img, float x, float y)
{
    real intX;
    real fracX = modf(x, intX);
    real intY;
    real fracY = modf(y, intY);

    Color4f c1 = img[cast(int)intX, cast(int)intY];
    Color4f c2 = img[cast(int)(intX + 1.0f), cast(int)intY];
    Color4f c3 = img[cast(int)(intX + 1.0f), cast(int)(intY + 1.0f)];
    Color4f c4 = img[cast(int)intX, cast(int)(intY + 1.0f)];

    Color4f ic1 = lerp(c1, c2, fracX);
    Color4f ic2 = lerp(c4, c3, fracX);
    Color4f ic3 = lerp(ic1, ic2, fracY);

    return ic3;
}

/*
 * Rectangular region of an image that can be iterated with foreach
 */
struct ImageRegion
{
    SuperImage img;
    uint xstart;
    uint ystart;
    uint width;
    uint height;

    final int opApply(scope int delegate(ref Color4f p, uint x, uint y) dg)
    {
        int result = 0;
        uint x1, y1;

        foreach(uint y; 0..height)
        {
            y1 = ystart + y;
            foreach(uint x; 0..width)
            {
                x1 = xstart + x;
                Color4f col = img[x1, y1];
                result = dg(col, x, y);
                img[x1, y1] = col;

                if (result)
                    break;
            }

            if (result)
                break;
        }

        return result;
    }
}

ImageRegion region(SuperImage img, uint x, uint y, uint width, uint height)
{
    return ImageRegion(img, x, y, width, height);
}

/*
 * An InputRange of windows (regions around pixels) of an image that can be iterated with foreach
 */
struct ImageWindowRange
{
    SuperImage img;
    uint width;
    uint height;

    private uint halfWidth;
    private uint halfHeight;
    private uint wx = 0;
    private uint wy = 0;

    this(SuperImage img, uint w, uint h)
    {
        this.img = img;
        this.width = w;
        this.height = h;

        this.halfWidth = this.width / 2;
        this.halfHeight = this.height / 2;
    }

    final int opApply(scope int delegate(ImageRegion w, uint x, uint y) dg)
    {
        int result = 0;

        foreach(uint y; img.col)
        {
            uint ystart = y - halfWidth;
            foreach(uint x; img.row)
            {
                uint xstart = x - halfHeight;

                auto window = region(img, xstart, ystart, width, height);
                result = dg(window, x, y);

                if (result)
                    break;
            }

            if (result)
                break;
        }

        return result;
    }

    bool empty = false;

    void popFront()
    {
        wx++;
        if (wx == img.width)
        {
            wx = 0;
            wy++;

            if (wy == img.height)
            {
                wy = 0;
                empty = true;
            }
        }
    }

    @property ImageRegion front()
    {
        return region(img, wx - halfWidth, wy - halfHeight, width, height);
    }
}

ImageWindowRange windows(SuperImage img, uint width, uint height)
{
    return ImageWindowRange(img, width, height);
}

/*
    ImageWindowRange usage example (convolution with emboss kernel):

    float[3][3] kernel = [
        [-1, -1,  0],
        [-1,  0,  1],
        [ 0,  1,  1],
    ];

    foreach(window, x, y; inputImage.windows(3, 3))
    {
        Color4f sum = Color4f(0, 0, 0);
        foreach(ref Color4f pixel, x, y; window)
            sum += pixel * kernel[y][x];
        outputImage[x, y] = sum / 4.0f + 0.5f;
    }
*/