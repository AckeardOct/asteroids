module entity;

import std.stdio;
import std.conv;
import std.math;
import std.container.slist;

import dsfml.graphics;
alias dsfml.graphics.Vector2f Vector2f;

import dlib.math.vector;
alias dlib.math.vector.Vector2f V2f;

import colize;

Vector2f toVector2f(ref V2f value)
{
    Vector2f ret;
    ret.x = value.x;
    ret.y = value.y;
    return ret;
}

V2f toV2f(ref Vector2f value)
{
    V2f ret;
    ret.x = value.x;
    ret.y = value.y;
    return ret;
}

Vector2f getCenter(IntRect rect)
{
    Vector2f ret;
    ret.x  = rect.left + rect.width / 2.0;
    ret.y = rect.top + rect.height / 2.0;
    return ret;
}

void setCenter(ref FloatRect rect, Vector2f center)
{
    float width  = rect.width;
    float height = rect.height;
    rect.left = center.x - width / 2.;
    rect.top  = center.y - height / 2.;
    rect.width  = width;
    rect.height = height;
}
    
    V2f rotate(V2f vector, float angle)
    {
        float rad = angle * (PI / 180.0);
        V2f newDirection;
        newDirection.x = vector.x * cos(rad) - vector.y * sin(rad);
        newDirection.y = vector.x * sin(rad) + vector.y * cos(rad);        
        return newDirection;
    }

unittest
{
    IntRect rect = IntRect(100, 100, 100, 100);
    assert(rect.getCenter() == Vector2f(150, 150));
    rect = IntRect(0, 0, 100, 200);
    assert(rect.getCenter() == Vector2f(50, 100));

    /*rect = IntRect(1, 1, 6, 4);
    rect.setCenter(V2f(5, 3));
    assert(rect == IntRect(2, 1, 6, 4));    */
}

class Entity : Drawable, Colisable
{
protected:
    Sprite sprite;
    V2f center;
    V2f size;
    V2f direction = V2f(0, -1);    
    V2f speed = V2f(0, 0);
    Clock clock;
public:    
    this(string imagePath)
    {  
        clock = new Clock();      
        auto texture = new Texture();
        texture.loadFromFile(imagePath);
        
        sprite = new Sprite();
        sprite.setTexture(texture);
        sprite.origin = sprite.textureRect.getCenter();
        size = V2f(sprite.textureRect.width, sprite.textureRect.height);
    }

    override public
    void draw(RenderTarget renderTarget, RenderStates renderStates)
    {                
        if(sprite)
            renderTarget.draw(sprite);
    }

    public 
    void moveTo(Vector2f pos)
    {   
        center = toV2f(pos);        
        setSpriteCenter(center);
    }

    public 
    void moveTo(V2f pos)
    {   
        center = pos;        
        setSpriteCenter(center);
    }

    public 
    void moveBy(float range)
    {        
        center += direction * range;
        setSpriteCenter(center);
    }

    public
    void moveBy(V2f vector)
    {
        center += vector;
        setSpriteCenter(center);
    }
    
    public
    void rotate(float angle)
    {
        float rad = angle * (PI / 180.0);
        V2f newDirection;
        newDirection.x = direction.x * cos(rad) - direction.y * sin(rad);
        newDirection.y = direction.x * sin(rad) + direction.y * cos(rad);
        direction = newDirection;
        sprite.rotation = sprite.rotation + angle;
    }    

    public 
    V2f getDirection() 
    { return direction; }

    public
    void accelerate(float value)
    {
        assert(value > 0);
        V2f tmp = direction;
        tmp *= value;

        speed += tmp;                        
    }

    public
    void setSpriteCenter(V2f value)
    {
        Vector2f spriteCenter = sprite.textureRect().getCenter();
        if(abs(spriteCenter.x - value.x) > 1 ||
           abs(spriteCenter.y - value.y) > 1)
        {               
            sprite.position = toVector2f(value);
        }
    }
    
    public
    void calc()
    {                        
        Duration time = clock.getElapsedTime();
        clock.restart();
        float secs = time.total!("usecs") / 1000000.0;

        V2f tmpSpeed = speed;
        /*if(tmpSpeed.length < 0.01)
            return;*/

        float resist = 10;
        V2f newSpeed = speed;
        /*if(newSpeed.length < resist)
            newSpeed = V2f(0, 0);
        else {
            newSpeed.x -= resist;
            newSpeed.y -= resist;
        }*/
        
        center.x += newSpeed.x * secs;
        center.y += newSpeed.y * secs;                                        

        setSpriteCenter(center);        
    }         

    public
    string debugString()
    {
        string ret;
        ret ~= "Speed: " ~ to!(string)(to!(int)(speed.y));
        //ret ~= " Direction: " ~ direction.toString();
        return ret;
    }

    public
    V2f getCenter()
    {
        return center;
    }
    
    public
    V2f getSize()
    {
        return size;
    }

    public
    void setSize(V2f newSize)
    {
        sprite.scale(Vector2f(newSize.x / size.x, newSize.y / size.y));
        size = newSize;
    }

    public
    AABB getAABB()
    {
        AABB ret;
        ret.min.x = center.x - size.x / 2.;
        ret.min.y = center.y - size.y / 2.;
        ret.max.x = center.x + size.x / 2.;
        ret.max.y = center.y + size.y /2.;
        return ret;
    }

    override public
    bool outMap(AABB one)
    {        
        bool ret = false;
        AABB current = getAABB();

        if(center.x < 0) {
            center.x = one.max.x;
            ret = true;
        }                    
        if(center.y < 0) {
            center.y = one.max.y;
            ret = true;
        }
        if(center.x > one.max.x) {
            center.x = 0;
            ret = true;
        }
        if(center.y > one.max.y) {
            center.y = 0;        
            ret = true;
        }
        return ret;
    }

    public
    V2f getSpeed()
    {
        return speed;
    }

    public
    void setSpeed(V2f val)
    {
        speed = val;
    }

    public
    void stop()
    {
        speed = V2f(0, 0);
    }

    public
    float getDiagonal()
    {
        return 2 * sqrt(pow(size.x / 2.0, 2) + pow(size.y / 2.0, 2));
    }
        
    override public
    void resolveColize(Entity entity)
    {
        /*AABB current = getAABB();
        AABB cmp = entity.getAABB();
        bool hasColize = colized(current, cmp);
        if(!hasColize)
            return;

        writeln("COLIZE!!! ", current, " : ", cmp);
            
        float range = getRange(current, cmp);        

        rotate(180);
        entity.rotate(180);
        
        moveBy(range);
        entity.moveBy(range);*/
    }    

    void colize()
    {
        
    }
}
