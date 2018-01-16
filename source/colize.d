module colize;

import std.stdio;

import dlib.math.vector;
alias dlib.math.vector.Vector2f V2f;

import dsfml.graphics;
alias dsfml.graphics.Vector2f Vector2f;

import entity;
import firing;
import common;

struct AABB
{
    V2f min;
    V2f max;

    this(V2f topLeft, V2f bottomRight)
    {
        min = topLeft;
        max = bottomRight;
    }
}

AABB getAABB(ref RenderWindow window)
{
    AABB ret;
    ret.min = V2f(0, 0);
    ret.max = V2f(window.size.x, window.size.y);
    return ret;
}

interface Colisable
{
    AABB getAABB();
    bool outMap(AABB one);
    void resolveColize(Entity entity);
}

float getRange(AABB one, AABB two)
{    
    V2f diff = one.max - two.max;
    return diff.length;   
}

bool colized(AABB one, AABB two)
{
    if(one.max.x < two.min.x || one.min.x > two.max.x) 
        return false;
    if(one.max.y < two.min.y || one.min.y > two.max.y) 
        return false;
    return true;
}

float getRange(Entity one, Entity two)
{
    float ret = 0;

    V2f tmp = one.getCenter() - two.getCenter();
    ret = tmp.length();
    
    return ret;
}

void resolveColize(Entity one, Entity two)
{       
    bool isBullet(Entity entity)
    {
        if((cast(Bullet) entity) is null)
            return false;
        return true;
    }
    
        bool needKill = false;

        if(isBullet(one)) {
            needKill = true;            
        }
        if(isBullet(two)) {
            needKill = true;            
        }

        if(!needKill)
            return;
        
    if(colized(one.getAABB(), two.getAABB()))
    {           
        if(isBullet(one))
        {                            
            two.colize();
            entities.linearRemoveElement(one);
            return;
        }
        if(isBullet(two))
        {            
            one.colize();
            entities.linearRemoveElement(two);
            return;
        }
    }      
}

unittest {
    AABB one = AABB(V2f(100, 100), V2f(300, 300));
    AABB two = AABB(V2f(200, 200), V2f(400, 400));
    assert(colized(one, two) == true);

    one = AABB(V2f(0, 0), V2f(100, 100));
    two = AABB(V2f(200, 200), V2f(400, 400));
    assert(colized(one, two) == false);

    one = AABB(V2f(310.5, 230.5), V2f(329.5, 249.5));
    two = AABB(V2f(68.7413, 385.118), V2f(168.741, 485.118));
    assert(colized(one, two) == false);
}
